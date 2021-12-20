// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.0;

import "../openzeppelin/proxy/utils/Initializable.sol";

abstract contract DeterministicAddress is Initializable {
    //byte code for the switcheroo contract 
    //bytes32 constant switcherooContractBytecode_ = 3d193d526020343d3d593d335afa153e34513d813b033d34833c5934f3fefefe;
    bytes32 constant switcherooContractBytecodeHash_ = 0x32a40109bf31082316f83fa1e28e334a97554cb6ef6312f90b86829983d5a549;
    function getSwitcherooContractAddress(bytes32 _salt, address _factory) public view returns (address){
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex"ff", _factory, _salt, switcherooContractBytecodeHash_)
                    )
                )
            )
        );
    }
}