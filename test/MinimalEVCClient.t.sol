// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./lib/TestableMinimalEVCClient.sol";
import "./lib/MockEVC.sol";

contract MinimalEVCClientTest is Test {
    MockEVC public evc;
    TestableMinimalEVCClient public client;

    address caller = makeAddr("caller");
    address onBehalfOf = makeAddr("onBehalfOf");

    function setUp() public {
        evc = new MockEVC();
        client = new TestableMinimalEVCClient(address(evc));
    }

    function testCallingDirectly() public {
        vm.prank(caller);
        address sender = client.getSender();
        assertEq(sender, caller);
    }

    function testCallingThroughEVC() public {
        evc.setOnBehalfOfAccount(onBehalfOf);
        vm.prank(address(evc));
        address sender = client.getSender();
        assertEq(sender, onBehalfOf);
    }
    
}