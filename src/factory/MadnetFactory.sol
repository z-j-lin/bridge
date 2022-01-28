// SPDX-License-Identifier: MIT-open-group
pragma solidity  ^0.8.11;
import "../../lib/utils/DeterministicAddress.sol";
import "../proxy/Proxy.sol";


/// @custom:salt foobar
contract MadnetFactory is DeterministicAddress, ProxyUpgrader {

    /**
    @dev owner role for priveledged access to functions  
    */
    address private owner_;

    /**
    @dev delegator role for priveledged access to delegateCallAny
    */
    address private delegator_;

    /**
    @dev array to store list of contract salts 
    */
    bytes32[] private contracts_;
    
    /**
    @dev slot for storing implementation address
    */
    address private implementation_;

    
    address private immutable proxyTemplate_;

    bytes8 private constant universalDeployCode_ = 0x38585839386009f3;
    
    /**
     *@dev events that notify of contract deployment
     */
    event Deployed(bytes32 salt , address contractAddr);
    event DeployedTemplate(address contractAddr);
    event DeployedStatic(address contractAddr);
    event DeployedRaw(address contractAddr);
    event DeployedProxy(address contractAddr);
    // modifier restricts caller to owner or self via multicall
    modifier onlyOwner() {
        requireAuth(msg.sender == address(this) || msg.sender == owner_);
        _;
    }

    // modifier restricts caller to owner or self via multicall
    modifier onlyOwnerOrDelegator() {
        requireAuth(msg.sender == address(this) || msg.sender == owner_ || msg.sender == delegator_);
        _;
    }

    /**
    * @dev The constructor encodes the proxy deploy byte code with the universal deploycode at
    * the head and the factory address at the tail, and deploys the proxy byte code using create 
    * The result of this deployment will be a contract with the proxy contract deployment bytecode 
    * with its constructor at the head, runtime code in the body and constructor args at the tail.
    * the constructor then sets proxyTemplate_ state var to the deployed proxy template address 
    * the deploy account will be set as the first owner of the factory. 
    * @param selfAddr_ is the factory contracts address (address of itself)
    */
    constructor(address selfAddr_) {
        bytes memory proxyDeployCode = abi.encodePacked(
            //8 byte code copy constructor code 
            universalDeployCode_,
            type(Proxy).creationCode,
            bytes32(uint256(uint160(selfAddr_)))
        );
        //variable to store the address created from create(the location of the proxy template contract)
        address addr;
        assembly {
            //deploys the proxy template contract 
            addr := create(0, add(proxyDeployCode, 0x20), mload(proxyDeployCode))
            if iszero(addr) {
                //if contract creation fails, we want to return any err messages
                returndatacopy(0x00, 0x00, returndatasize())
                //revert and return errors 
                revert(0x00, returndatasize())
            }
        }
        //State var that stores the proxyTemplate address 
        proxyTemplate_ = addr;
        //State var that stores the owner_ address
        owner_ = msg.sender;
    }

    /**
    * @dev setOwner allows the owner of this contract to change ownership to _new account 
    * @param _new: address of new owner 
    * (WARNING! setting owner_ to a contract address without proper functionality can deadlock everything)
    */
    function setOwner(address _new) public onlyOwner {
        owner_ = _new;
    }

    /**
    * @dev allows the owner to set a delegator_, 
    * an account with some prvilidged access 
    * @param _new: address of new delegator account 
    */
    function setDelegator(address _new) public onlyOwner {
        delegator_ = _new;
    }

    /**
    * @dev lookup allows anyone interacting with the contract to  
    * get the address of contract specified by its _name 
    * @param _name: Custom NatSpec tag @custom:salt at the top of the contract
    * solidity file 
    */
    function lookup(string memory _name) public view returns(address addr) {
        bytes32 salt;
        assembly {
            salt := mload(add(_name, 32))
        }
        addr = getMetamorphicContractAddress(salt, address(this));
    }
    function getContractAddr(bytes32 _salt) public view returns(address addr) {
        addr = getMetamorphicContractAddress(_salt, address(this));
    }

    function implementation() public view returns (address _v) {
        _v = implementation_;
    }

    /**  
    * @dev owner is public getter function for the owner_ account address
    * @return _v address of the owner account    
    */
    function owner() public view returns(address _v) {
        _v = owner_;
    }

    /**  
    * @dev delegator is public getter function for the delegator_ account address
    * @return _v address of the delegator account    
    */
    function delegator() public view returns(address _v) {
        _v = delegator_;
    }

    /**  
    * @dev delegator is public getter function for the delegator_ account address
    * @return _contracts the array of salts associated with all the contracts 
    * deployed with this factory     
    */
    function contracts() public view returns(bytes32[] memory _contracts) {
        //implement pagination with offset and limit  
        //num returns is min of length + offset or min of contracts.length + offset
        _contracts = contracts_;
    }

    /**  
    * @dev getNumContracts getter function for retrieving the total number of contracts 
    * deployed with this factory
    * @return the length of the contract array   
    */
    function getNumContracts() external view returns (uint256) {
        return contracts_.length;
    }

    /**  
    * @dev deployCreate allows the owner to deploy raw contracts through the factory
    * @param _deployCode bytecode to deploy using create
    */
    function deployCreate(bytes calldata _deployCode) public onlyOwner returns (address contractAddr) {
        assembly{
            //get the next free pointer
            let basePtr := mload(0x40)
            let ptr := basePtr
            
            //copies the initialization code of the implementation contract
            calldatacopy(ptr, _deployCode.offset, _deployCode.length)

            //Move the ptr to the end of the code in memory
            ptr := add(ptr, _deployCode.length)
            
            contractAddr := create(0, basePtr, sub(ptr, basePtr))
        }
        codeSizeZeroRevert((extCodeSize(contractAddr) != 0));
        emit DeployedRaw(contractAddr);
        return contractAddr;        
    }

    /**  
    * @dev deployCreate2 allows the owner to deploy contracts with deterministic address 
    * through the factory 
    * @param _value endowment value for created contract
    * @param _salt salt for create2 deployment, used to distinguish contracts deployed from this factory 
    * @param _deployCode bytecode to deploy using create2
    */
    function deployCreate2(uint256 _value, bytes32 _salt, bytes calldata _deployCode) public payable onlyOwner returns (address contractAddr) {
        assembly{
            //get the next free pointer
            let basePtr := mload(0x40)
            let ptr := basePtr
            
            //copies the initialization code of the implementation contract
            calldatacopy(ptr, _deployCode.offset, _deployCode.length)

            //Move the ptr to the end of the code in memory
            ptr := add(ptr, _deployCode.length)
            
            contractAddr := create2(_value, basePtr, sub(ptr, basePtr), _salt)
        }
        codeSizeZeroRevert(uint160(contractAddr) != 0);
        //record the contract salt to the contracts_ array for lookup
        contracts_.push(_salt);
        emit DeployedRaw(contractAddr);
        return contractAddr;        
    }

     /*
    * @dev destroy calls the template contract with arbitrary call data which will cause it to self destruct 
    * param _contractAddr the address of the contract to self destruct 
    */
/*    function destroy(address _contractAddr) public onlyOwner {
        assembly{
            if iszero(_contractAddr) {
                _contractAddr := sload(implementation_.slot)
            }
            let ret := call(gas(), _contractAddr, 0, 0x40, 0x20, 0x00, 0x00) 
            if iszero(ret) {
                revert(0x00, 0x00)
            }
        }
        codeSizeZeroRevert((extCodeSize(_contractAddr) == 0));
    }
*/

    function initializeContract(address _contract, bytes calldata _initCallData) public onlyOwnerOrDelegator {
        assembly {
            if iszero(iszero(_initCallData.length)) {
                let ptr := mload(0x40)
                mstore(0x40, add(_initCallData.length, ptr))
                calldatacopy(ptr, _initCallData.offset, _initCallData.length)
                if iszero(call(gas(), _contract, 0, ptr, _initCallData.length, 0x00, 0x00)) {
                    ptr := mload(0x40)
                    mstore(0x40, add(returndatasize(), ptr))
                    returndatacopy(ptr, 0x00, returndatasize())
                    revert(ptr, returndatasize())
                }
            }
        }
    }

    /**  
     * @dev deployTemplate deploys a template contract with the universal code copy constructor that deploys 
     * the deploycode as the contracts runtime code.    
     * @param _deployCode dfs
     * @return contractAddr the address of the deployed template contract
     */
    function deployTemplate(bytes calldata _deployCode) public onlyOwner returns (address contractAddr) {
        assembly {
            //get the next free pointer
            let basePtr := mload(0x40)
            mstore(0x40, add(basePtr, add(_deployCode.length, 0x28)))
            let ptr := basePtr
            // modify runtime to contain the tail jump operation
            //codesize, pc,  pc, codecopy, codesize, push1 09, return push2 <codesize> 56 5b
            mstore(ptr, hex"38585839386009f3")
            //0x38585839386009f3
            ptr := add(ptr, 0x08)
            //copy the initialization code of the implementation contract
            calldatacopy(ptr,  _deployCode.offset, _deployCode.length)
            // Move the ptr to the end of the code in memory
            ptr := add(ptr, _deployCode.length)
            // put address on constructor
            mstore(ptr, address())
            ptr := add(ptr, 0x20)
            
            contractAddr := create(0, basePtr, sub(ptr, basePtr))
            if iszero(contractAddr) {
                mstore(0, "yeet")
                revert(0, 0x20)
            }
        }
        codeSizeZeroRevert((extCodeSize(contractAddr) != 0));
        emit DeployedTemplate(contractAddr);
        //TODO: ONLY FOR TESTING?
        //template_ = contractAddr;
        implementation_ = contractAddr;
        return contractAddr;
    }

    /**  
     * @dev deployStatic deploys a template contract with the universal code copy constructor that deploys 
     * the deploycode as the contracts runtime code.    
     * @param _salt sda
     * @return contractAddr the address of the deployed template contract
     */
    function deployStatic(bytes32 _salt, bytes calldata _initCallData) public onlyOwner returns (address contractAddr) {
        assembly {
            // store proxy template address as implementation,
            //sstore(implementation_.slot, _impl)
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x20))
            // put metamorphic code as initcode
            mstore(ptr, shl(72, 0x6020363636335afa1536363636515af43d36363e3d36f3))
            contractAddr := create2(0, ptr, 0x17, _salt)
            //if the returndatasize is not 0 revert with the error message
            if iszero(iszero(returndatasize())){
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0, returndatasize())
            }
            //if contractAddr or code size at contractAddr is 0 revert with deploy fail message
            if or(iszero(contractAddr), iszero(extcodesize(contractAddr))) {
                mstore(0, "Static deploy failed")
                revert(0, 0x20)
            }
        }
        if (_initCallData.length > 0) {
            initializeContract(contractAddr, _initCallData);
        }
        codeSizeZeroRevert((extCodeSize(contractAddr) != 0));
        contracts_.push(_salt);
        emit DeployedStatic(contractAddr);
        return contractAddr;
    }
    
    function deployProxy(bytes32 _salt) public onlyOwner returns (address contractAddr) {
        address proxyTemplate = proxyTemplate_;
        assembly {
            // store proxy template address as implementation,
            sstore(implementation_.slot, proxyTemplate)
            let ptr := mload(0x40)
            mstore(0x40, add(ptr, 0x20))
            // put metamorphic code as initcode
            //push1 20
            mstore(ptr, shl(72, 0x6020363636335afa1536363636515af43d36363e3d36f3))
            contractAddr := create2(0, ptr, 0x17, _salt)
        }
        codeSizeZeroRevert((extCodeSize(contractAddr) != 0));
        //record the contract salt to the contracts array
        contracts_.push(_salt);
        emit DeployedProxy(contractAddr);
        return contractAddr;
    }

    function upgradeProxy(bytes32 _salt, address _newImpl) public onlyOwner {
        address proxy = DeterministicAddress.getMetamorphicContractAddress(_salt, address(this));
        __upgrade(proxy, _newImpl);
    }
   
    /**  
    * @dev delegateCallAny is a access restricted wrapper function for delegateCallAnyInternal
    * @param _target: the address of the contract to call
    * @param _cdata: the call data for the delegate call
    */
    function delegateCallAny(address _target, bytes calldata _cdata) public onlyOwnerOrDelegator {
        bytes memory cdata = _cdata;
        delegateCallAnyInternal(_target, cdata);
        returnAvailableData();
    }
    /**  
    * @dev callAny is a access restricted wrapper function for callAnyInternal 
    * @param _target: the address of the contract to call
    * @param _value: value to send with the call
    * @param _cdata: the call data for the delegate call
    */
    function callAny(address _target, uint256 _value, bytes calldata _cdata) public onlyOwner {
        bytes memory cdata = _cdata;
        callAnyInternal(_target, _value, cdata);
        returnAvailableData();
    }

    /**  
    * @dev multiCall allows EOA to make multiple function calls within a single transaction **in this contract**, and only returns the result of the last call 
    * @param _cdata: array of function calls 
    * returns the result of the last call 
    */
    function multiCall(bytes[] calldata _cdata) external onlyOwner {
        for (uint256 i = 0; i < _cdata.length; i++) {
            bytes memory cdata = _cdata[i];
            callAnyInternal(address(this), 0, cdata);
        }
        returnAvailableData();
    }
    
    /**  
    * @dev fallback function returns the address of the most recent deployment of a template 
    */
    fallback() external {
        assembly {
            mstore(returndatasize(), sload(implementation_.slot))
            return(returndatasize(), 0x20)
        }
    }

    function returnAvailableData() internal pure{
        assembly {
            returndatacopy(0x00, 0x00, returndatasize())
            return(0x00, returndatasize())
        }
    }

    /**  
    * @dev delegateCallAnyInternal allows the logic of this contract to be updated
    * in the event that our update/deploy mechanism is invalidated
    * this function poses a risk, but does not grant any additional
    * capability beyond that which is present due to other features 
    * present at this time
    * @param _target: the address of the contract to call
    * @param _cdata: the call data for the delegate call
    */
    function delegateCallAnyInternal(address _target, bytes memory _cdata) internal {
        assembly{
            let size := mload(_cdata)
            let ptr := add(0x20, _cdata)
            if iszero(delegatecall(gas(), _target, ptr, size, 0x00, 0x00)) {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }
    }

    /**  
    * @dev callAnyInternal internal functions that allows the factory contract to make arbitray calls to other contracts 
    * @param _target: the address of the contract to call
    * @param _value: value to send with the call 
    * @param _cdata: the call data for the delegate call
    */
    function callAnyInternal(address _target, uint256 _value, bytes memory _cdata) internal {
        assembly{
            let size := mload(_cdata)
            let ptr := add(0x20, _cdata)
            if iszero(call(gas(), _target, _value, ptr, size, 0x00, 0x00)) {
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, returndatasize())
            }
        }
    }

    /**  
    * @dev requireAuth reverts if false and returns csize0 error message 
    * @param _ok boolean false to cause revert
    */
    function requireAuth(bool _ok) internal pure {
        require(_ok, "unauthorized");
    }

    /**  
    * @dev codeSizeZeroRevert reverts if false and returns csize0 error message
    * @param _ok boolean false to cause revert 
    */
    function codeSizeZeroRevert(bool _ok) internal pure {
        require(_ok, "csize0");
    }
    

    function extCodeSize(address target) internal view returns (uint256 size){ 
        assembly {
            size := extcodesize(target)
        }
        return size;
    }
}


contract utils {

    function getCodeSize(address target) public view returns (uint256) {
        uint256 csize;
        assembly{
            csize := extcodesize(target)
        }
        return csize;
    }

    function getCode(address _addr) public view returns (bytes memory o_code) {
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(_addr)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length in memory
            mstore(o_code, size)
            // actually retrieve the code, this needs assembly
            extcodecopy(_addr, add(o_code, 0x20), 0, size)
        }
    }
    
}