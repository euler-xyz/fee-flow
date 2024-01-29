// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {MinimalEVCClient} from "./MinimalEVCClient.sol";



/// @title FeeFlowController
/// @author Euler Labs (https://eulerlabs.com)
/// @notice Continous back to back dutch auctions selling any asset received by this contract
contract FeeFlowController is ReentrancyGuard, MinimalEVCClient {
    using SafeTransferLib for ERC20;

    uint256 constant public MIN_EPOCH_PERIOD = 1 hours;
    uint256 constant public MAX_EPOCH_PERIOD = 1 years;
    uint256 constant public MIN_PRICE_MULTIPLIER = 1.1e18; // Should at least be 110% of settlement price
    uint256 constant public ABS_MIN_INIT_PRICE = 1e6; // Minimum sane value for init price
    uint256 constant public PRICE_MULTIPLIER_SCALE = 1e18;

    ERC20 immutable public paymentToken;
    address immutable public paymentReceiver;
    uint256 immutable public epochPeriod;
    uint256 immutable public priceMultiplier;
    uint256 immutable public minInitPrice;

    struct Slot1 {
        uint128 initPrice;
        uint64 startTime;
    }
    Slot1 internal slot1;

    event Buy(address indexed buyer, address indexed assetsReceiver, uint256 paymentAmount);

    error InitPriceBelowMin();
    error EpochPeriodBelowMin();
    error EpochPeriodExceedsMax();
    error PriceMultiplierBelowMin();
    error MinInitPriceBelowMin();
    error MinInitPriceExceedsUint128();
    error DeadlinePassed();
    error EmptyAssets();
    error MaxPaymentTokenAmountExceeded();

    
    /// @dev Initializes the FeeFlowController contract with the specified parameters.
    /// @param initPrice The initial price for the first epoch.
    /// @param paymentToken_ The address of the payment token.
    /// @param paymentReceiver_ The address of the payment receiver.
    /// @param epochPeriod_ The duration of each epoch period.
    /// @param priceMultiplier_ The multiplier for adjusting the price from one epoch to the next.
    /// @param minInitPrice_ The minimum allowed initial price for an epoch.
    /// @notice This constructor performs parameter validation and sets the initial values for the contract.
    constructor(address evc, uint256 initPrice, address paymentToken_, address paymentReceiver_, uint256 epochPeriod_, uint256 priceMultiplier_, uint256 minInitPrice_) MinimalEVCClient(evc) {
        if(initPrice < minInitPrice_) revert InitPriceBelowMin();
        if(epochPeriod_ < MIN_EPOCH_PERIOD) revert EpochPeriodBelowMin();
        if(epochPeriod_ > MAX_EPOCH_PERIOD) revert EpochPeriodExceedsMax();
        if(priceMultiplier_ < MIN_PRICE_MULTIPLIER) revert PriceMultiplierBelowMin();
        if(minInitPrice_ < ABS_MIN_INIT_PRICE) revert MinInitPriceBelowMin();
        if(minInitPrice_ > type(uint128).max) revert MinInitPriceExceedsUint128();

        slot1.initPrice = uint128(initPrice);
        slot1.startTime = uint64(block.timestamp);

        paymentToken = ERC20(paymentToken_);
        paymentReceiver = paymentReceiver_;
        epochPeriod = epochPeriod_;
        priceMultiplier = priceMultiplier_;
        minInitPrice = minInitPrice_;
    }


    /// @dev Allows a user to buy assets by transferring payment tokens and receiving the assets.
    /// @param assets The addresses of the assets to be bought.
    /// @param assetsReceiver The address that will receive the bought assets.
    /// @param deadline The deadline timestamp for the purchase.
    /// @param maxPaymentTokenAmount The maximum amount of payment tokens the user is willing to spend.
    /// @return paymentAmount The amount of payment tokens transferred for the purchase.
    /// @notice This function performs various checks and transfers the payment tokens to the payment receiver.
    /// It also transfers the assets to the assets receiver and sets up a new auction with an updated initial price.
    function buy(address[] calldata assets, address assetsReceiver, uint256 deadline, uint256 maxPaymentTokenAmount) external nonReentrant returns(uint256 paymentAmount) {
        if(block.timestamp > deadline) revert DeadlinePassed();
        if(assets.length == 0) revert EmptyAssets();

        Slot1 memory slot1Cache = slot1;
        address sender = _msgSender();
        
        paymentAmount = getPriceFromCache(slot1Cache);

        if(paymentAmount > maxPaymentTokenAmount) revert MaxPaymentTokenAmountExceeded();
        paymentToken.safeTransferFrom(sender, paymentReceiver, paymentAmount);

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

        slot1Cache.initPrice = uint128(newInitPrice);
        slot1Cache.startTime = uint64(block.timestamp);

        // Write cache in single write
        slot1 = slot1Cache;

        emit Buy(sender, assetsReceiver, paymentAmount);

        return paymentAmount;
    }

    
    /// @dev Retrieves the current price from the cache based on the elapsed time since the start of the epoch.
    /// @param slot1Cache The Slot1 struct containing the initial price and start time of the epoch.
    /// @return price The current price calculated based on the elapsed time and the initial price.
    /// @notice This function calculates the current price by subtracting a fraction of the initial price based on the elapsed time.
    // If the elapsed time exceeds the epoch period, the price will be 0.
    function getPriceFromCache(Slot1 memory slot1Cache) internal view returns(uint256){
        uint256 timePassed = block.timestamp - slot1Cache.startTime;

        if(timePassed > epochPeriod) {
            return 0;
        }

        return slot1Cache.initPrice - slot1Cache.initPrice * timePassed / epochPeriod;
    }


    /// @dev Calculates the current price
    /// @return price The current price calculated based on the elapsed time and the initial price.
    /// @notice Uses the internal function `getPriceFromCache` to calculate the current price.
    function getPrice() public view returns(uint256){
        return getPriceFromCache(slot1);
    }


    /// @dev Retrieves slot1 as a memory struct
    /// @return slot1 The slot1 value as a Slot1 struct
    function getSlot1() public view returns (Slot1 memory) {
        return slot1;
    }
}
