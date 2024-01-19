// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../src/MinimalEVCClient.sol";

contract TestableMinimalEVCClient is MinimalEVCClient {
    constructor(address evc_) MinimalEVCClient(evc_) {}

    function getSender() external view returns (address) {
        return _msgSender();
    }
}