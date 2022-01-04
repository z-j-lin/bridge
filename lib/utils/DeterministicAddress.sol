// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.0;

abstract contract DeterministicAddress {
    // byte code for the switcheroo contract
    // 6020363636335afa1536363636515af43d36363e3d36f3
    bytes32 constant metamorphicContractBytecodeHash_ = 0x1c0bf703a3415cada9785e89e9d70314c3111ae7d8e04f33bb42eb1d264088be;
    function getMetamorphicContractAddress(bytes32 _salt, address _factory) public pure returns (address){
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(hex"ff", _factory, _salt, metamorphicContractBytecodeHash_)
                    )
                )
            )
        );
    }
}