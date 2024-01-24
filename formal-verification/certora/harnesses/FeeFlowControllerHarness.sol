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

    function getInitPrice() external view returns (uint256) {
        return slot0.initPrice;
    }

    function getStartTime() external view returns (uint256) {
        return slot0.startTime;
    }
    
    // address immutable public paymentReceiver;
    function getPaymentReceiver() external view returns (address) {
        return paymentReceiver;
    }
    // uint256 immutable public epochPeriod;
    function getEpochPeriod() external view returns (uint256) {
        return epochPeriod;
    }
    // uint256 immutable public priceMultiplier;
    function getPriceMultiplier() external view returns (uint256) {
        return priceMultiplier;
    }
    // uint256 immutable public minInitPrice;
    function getMinInitPrice() external view returns (uint256) {
        return minInitPrice;
    }

    // uint256 constant public MIN_EPOCH_PERIOD = 1 hours;
    function getMIN_EPOCH_PERIOD() external pure returns (uint256) {
        return MIN_EPOCH_PERIOD;
    }
    // uint256 constant public MIN_PRICE_MULTIPLIER = 1.1e18; // Should at least be 110% of settlement price
    function getMIN_PRICE_MULTIPLIER() external pure returns (uint256) {
        return MIN_PRICE_MULTIPLIER;
    }
    // uint256 constant public MIN_MIN_INIT_PRICE = 1e6; // Minimum sane value for init price
    function getMIN_MIN_INIT_PRICE() external pure returns (uint256) {
        return MIN_MIN_INIT_PRICE;
    }
    // uint256 constant public PRICE_MULTIPLIER_SCALE = 1e18;
    function getPRICE_MULTIPLIER_SCALE() external pure returns (uint256) {
        return PRICE_MULTIPLIER_SCALE;
    }
}
