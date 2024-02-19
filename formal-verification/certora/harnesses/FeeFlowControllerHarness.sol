// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../../patched/FeeFlowController.sol";

contract FeeFlowControllerHarness is FeeFlowController {
    constructor(
        address evc,
        uint256 initPrice,
        address paymentToken_,
        address paymentReceiver_,
        uint256 epochPeriod_,
        uint256 priceMultiplier_,
        uint256 minInitPrice_
    )
        FeeFlowController(evc, initPrice, paymentToken_, paymentReceiver_, epochPeriod_, priceMultiplier_, minInitPrice_)
    {}

    function getAddressThis() external view returns (address) {
        return address(this);
    }

    function reentrancyMock() external nonReentrant {
        // this makes sure we are setting the reentrancy guard correctly
    }

    function getEVC() external view returns (address) {
        return address(evc);
    }

    function getTokenBalanceOf(address _token, address _account) external view returns (uint256) {
        ERC20 token = ERC20(_token);
        return token.balanceOf(_account);
    }

    function getPaymentTokenAllowance(address owner) external view returns (uint256) {
        return paymentToken.allowance(owner, address(this));
    }

    function getPaymentTokenBalanceOf(address account) external view returns (uint256) {
        return paymentToken.balanceOf(account);
    }

    function getInitPrice() external view returns (uint256) {
        return slot0.initPrice;
    }

    function getStartTime() external view returns (uint256) {
        return slot0.startTime;
    }

    function getEpochId() external view returns (uint256) {
        return slot0.epochId;
    }

    // address immutable public paymentReceiver;
    function getPaymentReceiver() external view returns (address) {
        return paymentReceiver;
    }
    
    function getPaymentToken() external view returns (address) {
        return address(paymentToken);
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

    function getMAX_EPOCH_PERIOD() external pure returns (uint256) {
        return MAX_EPOCH_PERIOD;
    }

    function getMIN_PRICE_MULTIPLIER() external pure returns (uint256) {
        return MIN_PRICE_MULTIPLIER;
    }
    // uint256 constant public MIN_MIN_INIT_PRICE = 1e6; // Minimum sane value for init price

    function getABS_MIN_INIT_PRICE() external pure returns (uint256) {
        return ABS_MIN_INIT_PRICE;
    }

    function getABS_MAX_INIT_PRICE() external pure returns (uint256) {
        return ABS_MAX_INIT_PRICE;
    }
    // uint256 constant public PRICE_MULTIPLIER_SCALE = 1e18;

    function getPRICE_MULTIPLIER_SCALE() external pure returns (uint256) {
        return PRICE_MULTIPLIER_SCALE;
    }

    function getMAX_PRICE_MULTIPLIER() external pure returns (uint256) {
        return MAX_PRICE_MULTIPLIER;
    }
}
