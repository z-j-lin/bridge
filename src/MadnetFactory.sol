// SPDX-License-Identifier: MIT-open-group
pragma solidity  ^0.8.10;
import "../lib/utils/DeterministicAddress.sol";


contract foo {
    address public owner;
    constructor(address bar, bytes memory) {
        owner = bar;
    }

    fallback() external {
        owner = msg.sender;
    }
}

interface MadnetFacInterface {
    function deploy(
    bytes32 _salt, 
    bytes calldata _runtimeCode, 
    bytes calldata _initiator
    ) external payable returns (address contractAddr);
}

contract MadnetFactory is DeterministicAddress {
    //emit an event when a contract is deployed
    event Deployed(bytes32, address);
    event DeployedTemplate(address);
    event DeployedRaw(address);
    event DeployedCopy(address);

    // owner role for priveledged access to functions
    address private owner_;
    
    // slot for storing the create2 address 
    address private deploy2Addr_;
    
    // slot for storing implementation address
    address implementation_;
    
    // address for copy code contract
    address copyAddr_;

    modifier onlyOwner() {
        require(msg.sender == owner_ || msg.sender == address(this), "Functionality restricted to authorized operators.");
        _;
    }
    
    //array to store list of contracts 
    bytes32[] contracts_;

    //collection of authorized operators 
    mapping(address => bool) private authorizedOperators_;
    
    //map contract names to addresses 
    mapping(bytes32 => address) registry_;
    
    constructor() {
        owner_ = msg.sender;
    }

    // function to strip out the first 32 bytes of call data as target for delegatecall
    //bare delegate call use rest of call data as input
    function CallStrip(bytes[] calldata cdata) private {

        assembly{
            let ptr := mload(0x40)
            calldatacopy(ptr, cdata.offset, cdata.length)
            if iszero(delegatecall(gas(), mload(ptr), add(ptr, 0x20), sub(cdata.length,0x20), 0x00, 0x00)){
                returndatacopy(0x00, 0x00, returndatasize())
                revert(0x00, 0x00)
            }
        }

    }

    //rewrite the uups reverse proxies with constructors 
    function multicall(bytes[] calldata cdata) external onlyOwner returns (bytes memory) {
            // declare free mem ptr out of loop
            uint256 ptr;
            assembly {
                ptr := mload(0x40)
            }
            // do all but last call
            uint256 i;
            for (; i < cdata.length - 1 ; i++) { 
                bytes calldata obj = cdata[i];
                assembly{
                    calldatacopy(ptr, obj.offset, obj.length)
                    let ret := call(gas(), address(), 0, ptr, obj.length, 0x00, 0x00)
                    if iszero(ret) {
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                }
            }
            {
            // do last call
            // this is loop unwinding and saves gas on use due to last call
            // being only call that return is called
            // this saves the check operation for last call in loop
            bytes calldata obj = cdata[i];
            assembly{
                    calldatacopy(ptr, obj.offset, obj.length)
                    let ret := call(gas(), address(), 0, ptr, obj.length, 0x00, 0x00)
                    if iszero(ret) {
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }
                    returndatacopy(0x00, 0x00, returndatasize())
                    return(0x00, returndatasize())
                    
            }
            }
    }

    function setImplementation(address _implementation) onlyOwner public {
        implementation_ = _implementation;
    }

    function deploy(
        bytes32 _salt,
        bytes calldata _initiator
    ) 
    public onlyOwner returns (address) {
        // declare contract address for assignment in assembly block
        address contractAddr;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, shl(24, 0x59595959335afa503d59593e3434343434515af4503d34343e3d34f3fe))
            contractAddr := create2(0, ptr, 0x29, _salt)
            if iszero(extcodesize(contractAddr)){
                revert(0x00, 0x00)
            }
            if iszero(iszero(_initiator.length)) {
                //copy the arguement over from the call data in the context of the deploy function call
                calldatacopy(ptr, add(_initiator.offset, 0x20), _initiator.length)
                if iszero(call(gas(), contractAddr, 0, ptr, _initiator.length, 0, 0)) {
                    revert(0x00, 0x00)
                }
            }
        }
        //add the salt to the list of contract names
        contracts_.push(_salt);
        //add the address to contract address mapping 
        registry_[_salt] = contractAddr; 
        emit Deployed(_salt, contractAddr);
        return contractAddr;
    }

    //retrieves the address of the contract specified by its name 
    function getContractAddress(bytes32 _salt) external view returns (address) {
        return getMetamorphicContractAddress(_salt, address(this));
    }

    //returns the length of the contracts array 
    function getNumContracts() external view returns (uint256) {
    return contracts_.length;
    }

    //returns implementation contracts address
    function deployTemplate(bytes calldata deployCode_) public onlyOwner returns (address) {
        address contractAddr;
        assembly{
            //get the next free pointer
            let basePtr := mload(0x40)
            let ptr := basePtr
            
            //codesize, PC,  pc, codecopy, codesize, push1 09, return
            mstore(ptr, shl(192, 0x38585839386009f3))
            ptr := add(ptr, 0x08)

            // modify runtime to contain the tail jump operation
            // 61 <codesize other> 56 5b 
            mstore8(ptr, 0x61)
            ptr := add(ptr, 0x01)
            // account for array offset
            mstore(ptr, shl(240, deployCode_.length))
            ptr := add(ptr, 0x02)
            mstore8(ptr, 0x56)
            ptr := add(ptr, 0x01)
            mstore8(ptr, 0x5b)
            ptr := add(ptr, 0x01)

            //copies the initialization code of the implementation contract
            //TODO: change the runtimeCode_ variable name to impInitCode_
            calldatacopy(ptr, add(0x05, deployCode_.offset), sub(deployCode_.length, 0x05))

            //Move the ptr to the end of the code in memory
            ptr := add(ptr, deployCode_.length)

            // account for the previously added values to offset the copy
            ptr := sub(ptr, 0x05)

            // account for the need to change the constructor dynamic byte array
            ptr := sub(ptr, 0x20)
            
            // store the length of the initcode modifier
            mstore(ptr, 0x28)
            ptr := add(ptr, 0x20)

            // finish the code with the terminate sequence  
            // 5b 60 80 60 40 52 60 05 33 73 <factory> 14 15 57 33 ff fe
            mstore(ptr, or(or(shl(192,0x5b60806040523373), shl(32, address())), 0x14156004))
            ptr := add(ptr, 0x20)
            mstore(ptr, shl(192, 0x57361560045733ff))
            ptr := add(ptr, 0x08)
            contractAddr := create(0, basePtr, sub(ptr, basePtr))
            if iszero(extcodesize(contractAddr)){
                revert(0x00, 0x00)
            }
        }
        emit DeployedTemplate(contractAddr);
        implementation_ = contractAddr;
        return contractAddr;      
    }


    //returns implementation contracts address
    function deployRaw(bytes calldata deployCode_) public onlyOwner returns (address) {
        address contractAddr;
        assembly{
            //get the next free pointer
            let basePtr := mload(0x40)
            let ptr := basePtr
            
            //copies the initialization code of the implementation contract
            calldatacopy(ptr, deployCode_.offset, deployCode_.length)

            //Move the ptr to the end of the code in memory
            ptr := add(ptr, deployCode_.length)
            
            contractAddr := create(0, basePtr, sub(ptr, basePtr))
            if iszero(extcodesize(contractAddr)){
                revert(0x00, 0x00)
            }
        }
        emit DeployedRaw(contractAddr);
        return contractAddr;        
    }

    //this is used to destroy the deploy template contract after code is copied to switcheroo
    function destroy(address contractAddr) public onlyOwner {
        assembly{
            let ret := call(gas(), contractAddr, 0, 0x40, 0x20, 0x00, 0x00) 
            if iszero(ret){
                revert(0x00, 0x00)
            }
            if iszero(iszero(extcodesize(contractAddr))) {
                revert(0x00, 0x00)
            }
        }
    }

    function checkcodeSize(address target) public view returns (uint256) {
        uint256 csize;
        assembly{
            csize := extcodesize(target)
        }
        return csize;
    }
    
    fallback() external {
        assembly {
            mstore(returndatasize(), sload(implementation_.slot))
            return(returndatasize(), 0x20)
        }
    }

}