// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.0;

import "../interfaces/IERC20TransferMinimal.sol";

abstract contract ERC20SafeTransfer {
    // _safeTransferFromERC20 performs a transferFrom call against an erc20 contract in a safe manner
    // by reverting on failure
    // this function will return without performing a call or reverting
    // if amount_ is zero
    function _safeTransferFromERC20(
        IERC20TransferMinimal contract_,
        address sender_,
        uint256 amount_
    ) internal {
        if (amount_ == 0) {
            return;
        }
        require(address(contract_) != address(0x0), "0x00");
        bool success = contract_.transferFrom(sender_, address(this), amount_);
        require(success, "XFRFAILED");
    }

    // _safeTransferERC20 performs a transfer call against an erc20 contract in a safe manner
    // by reverting on failure
    // this function will return without performing a call or reverting
    // if amount_ is zero
    function _safeTransferERC20(
        IERC20TransferMinimal contract_,
        address to_,
        uint256 amount_
    ) internal {
        if (amount_ == 0) {
            return;
        }
        require(address(contract_) != address(0x0), "0x00");
        bool success = contract_.transfer(to_, amount_);
        require(success, "XFRfailed");
    }
}
