// SPDX-License-Identifier: MIT-open-group
pragma solidity  ^0.8.10;
import "../lib/utils/DeterministicAddress.sol";

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
    address private owner_; 
    modifier onlyOwner() {
        require(msg.sender == owner_, "Functionality restricted to authorized operators.");
        _;
    }
    //slot for storing implementation address
    address implementation_;
    //array to store list of contracts 
    bytes32[] contracts_;
    //collection of authorized operators 
    mapping(address => bool) private authorizedOperators_;
    //map contract names to addresses 
    mapping(bytes32 => address) registry_;
    constructor() {
        owner_ = msg.sender;
    }
    
    function deploy( 
    bytes32 _salt,
    bytes calldata _initiator
    ) 
    external payable onlyOwner returns (address) { 
        //determine the address of the switcheroo contract with the address 
        address contractAddr;
        address switcheroo = getSwitcherooContractAddress(_salt, address(this));
        assembly{
            //keccak256(abi.encodePacked(0xFF ++ factoryAddress ++ salt ++ keccak256(abi.encodepacked(switcherooContractBytecode)))[12:]
            let ptr := add(msize(), 0x20)
            mstore(ptr, 0x3d193d526020343d3d593d335afa153e34513d813b033d34833c5934f3fefefe)
            contractAddr := create2(0, ptr, 0x20, _salt)
        }
        
        if (_initiator.length > 0){
            initializeContract(contractAddr, _initiator);
        }
        //add the salt to the list of contract names
        contracts_.push(_salt);
        //add the address to contract address mapping 
        registry_[_salt] = contractAddr; 
        emit Deployed(_salt, contractAddr);
        return switcheroo;
    }

    //retrieves the address of the contract specified by its name 
    function getContractAddress(bytes32 _salt) external view returns (address){
        return registry_[_salt];
    }
    //returns the length of the contracts array 
    function getNumContracts() external view returns (uint) {
    return contracts_.length;
    }
    //computes the address of the deployment contract in the uncloned state
    // @param    _salt is the contract name 
    
    //returns implementation contracts address 
    function deployTemplate(bytes calldata runtimeCode_)public onlyOwner returns (address) {
        address contractAddress;
        assembly{
            //get the next free pointer
            let basePtr := add(0x20, msize())
            let ptr := basePtr
            mstore(ptr, shl(192, 0x38585839386009f3))
            ptr := add(ptr, 0x08)
            mstore(ptr, shl(248, 0x73))
            ptr := add(ptr, 0x01)
            mstore(ptr, shl(96, address()))
            ptr := add(ptr, 0x14)
            mstore(ptr, shl(168, 0x331415601d5733ff5bfefe))
            ptr := add(ptr, 0x0b)
            calldatacopy(ptr, runtimeCode_.offset, runtimeCode_.length)
            ptr := add(ptr, runtimeCode_.length)
            contractAddress := create(0, basePtr, sub(ptr, basePtr))
            if iszero(extcodesize(contractAddress)){
                revert(0,0)
            }
        }
        emit DeployedTemplate(contractAddress);
        return contractAddress;        
    }
    function setImplementation(address contractAddress) public onlyOwner{
        implementation_ = contractAddress;
    }
    function destroy(address target) public onlyOwner {
        assembly{
            let ret := call(gas(), target, 0, 0, 0, 0, 0) 
            if iszero(ret){
                revert(0,0)
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
    function initializeContract(address contractAddress_, bytes calldata initcode) internal {
        assembly{
            let ptr := mload(0x40)
            //copy the arguement over from the call data in the context of the deploy function call
            calldatacopy(ptr, add(initcode.offset, 0x20), initcode.length)
            if iszero(call(gas(), contractAddress_, ptr, initcode.length, 0, 0, 0)){
                revert(msize(), msize())
            }
        }
    }
    fallback() external {
        address output = implementation_;
        assembly {
            mstore(0x00, output)
            return(0x00, 0x20)
        }
    }
}