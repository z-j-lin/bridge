// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.0;

import "../../../lib/openzeppelin/proxy/utils/Initializable.sol";

abstract contract Admin is Initializable{

    // _admin is a privileged role
    address _admin;
    //this replaces the constructor with a function that is called once
    //TODO: decide if we should make it accessable by factory 
    function __Admin_init(address admin_) internal initializer {
        _admin = admin_;
    }

    /// @dev onlyAdmin enforces msg.sender is _admin
    modifier onlyAdmin() {
        require(msg.sender == _admin, "Must be admin");
        _;
    }

    // assigns a new admin may only be called by _admin
    function _setAdmin(address admin_) internal {
        _admin = admin_;
    }

    /// @dev getAdmin returns the current _admin
    function getAdmin() public view returns(address) {
        return _admin;
    }

    /// @dev assigns a new admin may only be called by _admin
    function setAdmin(address admin_) public virtual onlyAdmin {
        _setAdmin(admin_);
    }
}