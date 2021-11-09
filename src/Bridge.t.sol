pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./Bridge.sol";

contract BridgeTest is DSTest {
    Bridge bridge;

    function setUp() public {
        bridge = new Bridge();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
