// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.0;

abstract contract DeterministicAddress {
    // byte code for the switcheroo contract
    // 59595959335afa503d59593e3434343434515af4503d34343e3d34f3fe
    bytes32 constant metamorphicContractBytecodeHash_ = 0x198f7b5a60c96cccfd00aeb88e371aadec27ad304ebcec2b7d70ebbcd03e425e;
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