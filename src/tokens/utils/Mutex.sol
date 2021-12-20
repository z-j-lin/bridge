// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.0;


abstract contract Mutex {

    uint256 constant LOCKED = 1;
    uint256 constant UNLOCKED = 0;
    uint256 _mutex;


    modifier withLock() {
        require(_mutex != LOCKED, "Mutex: Couldn't acquire the lock!");
        _mutex = LOCKED;
        _;
        _mutex = UNLOCKED;
    }
}