// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../patched/FeeFlowController.sol";

contract FeeFlowControllerHarness is FeeFlowController {
    constructor(
        uint256 initPrice,
        address paymentToken_,
        address paymentReceiver_,
        uint256 epochPeriod_,
        uint256 priceMultiplier_,
        uint256 minInitPrice_
    ) FeeFlowController(initPrice, paymentToken_, paymentReceiver_, epochPeriod_, priceMultiplier_, minInitPrice_) {}
}
