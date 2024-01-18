// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

contract FeeFlowController is ReentrancyGuard {
    using SafeTransferLib for ERC20;

    uint256 constant public MIN_EPOCH_PERIOD = 1 hours;
    uint256 constant public MIN_PRICE_MULTIPLIER = 1.1e18; // Should at least be 110% of settlement price
    uint256 constant public MIN_MIN_INIT_PRICE = 1e6; // Minimum sane value for init price
    uint256 constant public PRICE_MULTIPLIER_SCALE = 1e18;

    ERC20 immutable public paymentToken;
    address immutable public paymentReceiver;
    uint256 immutable public epochPeriod;
    uint256 immutable public priceMultiplier;
    uint256 immutable public minInitPrice;

    struct Slot0 {
        uint128 initPrice;
        uint64 startTime;
    }
    Slot0 internal slot0;

    event Buy(address indexed buyer, address indexed assetsReceiver, uint256 paymentAmount);

    error InitPriceBelowMin();
    error EpochPeriodBelowMin();
    error PriceMultiplierBelowMin();
    error MinInitPriceBelowMin();
    error DeadlinePassed();
    error MaxPaymentTokenAmountExceeded();


    constructor(uint256 initPrice, address paymentToken_, address paymentReceiver_, uint256 epochPeriod_, uint256 priceMultiplier_, uint256 minInitPrice_) {
        if(initPrice < minInitPrice_) revert InitPriceBelowMin();
        if(epochPeriod_ < MIN_EPOCH_PERIOD) revert EpochPeriodBelowMin();
        if(priceMultiplier_ < MIN_PRICE_MULTIPLIER) revert PriceMultiplierBelowMin();
        if(minInitPrice_ < MIN_MIN_INIT_PRICE) revert MinInitPriceBelowMin();

        slot0.initPrice = uint128(initPrice);
        slot0.startTime = uint64(block.timestamp);

        paymentToken = ERC20(paymentToken_);
        paymentReceiver = paymentReceiver_;
        epochPeriod = epochPeriod_;
        priceMultiplier = priceMultiplier_;
        minInitPrice = minInitPrice_;
    }


    function buy(address[] calldata assets, address assetsReceiver, uint256 deadline, uint256 maxPaymentTokenAmount) external nonReentrant {
        if(block.timestamp > deadline) revert DeadlinePassed();

        Slot0 memory slot0Cache = slot0;

        uint256 paymentAmount = getPriceFromCache(slot0Cache);
        if(paymentAmount > maxPaymentTokenAmount) revert MaxPaymentTokenAmountExceeded();
        paymentToken.safeTransferFrom(msg.sender, paymentReceiver, paymentAmount);

        for(uint256 i = 0; i < assets.length; i++) {
            // Transfer full balance to buyer
            uint256 balance = ERC20(assets[i]).balanceOf(address(this));
            ERC20(assets[i]).safeTransfer(assetsReceiver, balance);
        }

        // Setup new auction
        uint256 newInitPrice = paymentAmount * priceMultiplier / PRICE_MULTIPLIER_SCALE;
        if(newInitPrice < minInitPrice) {
            newInitPrice = minInitPrice;
        }

        slot0Cache.initPrice = uint128(newInitPrice);
        slot0Cache.startTime = uint64(block.timestamp);

        // Write cache in single write
        slot0 = slot0Cache;

        emit Buy(msg.sender, assetsReceiver, paymentAmount);
    }


    function getPriceFromCache(Slot0 memory slot0Cache) internal view returns(uint256){
        uint256 timePassed = block.timestamp - slot0Cache.startTime;

        if(timePassed > epochPeriod) {
            return 0;
        }

        return slot0Cache.initPrice - slot0Cache.initPrice * timePassed / epochPeriod;
    }


    function getPrice() public view returns(uint256){
        return getPriceFromCache(slot0);
    }


    function getSlot0() public view returns (Slot0 memory) {
        return slot0;
    }
}
