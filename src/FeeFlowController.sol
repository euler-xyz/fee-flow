// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {MinimalEVCClient} from "./MinimalEVCClient.sol";



/// @title FeeFlowController
/// @author Euler Labs (https://eulerlabs.com)
/// @notice Continous back to back dutch auctions selling any asset received by this contract
contract FeeFlowController is MinimalEVCClient {
    using SafeTransferLib for ERC20;

    uint256 constant public MIN_EPOCH_PERIOD = 1 hours;
    uint256 constant public MAX_EPOCH_PERIOD = 365 days;
    uint256 constant public MIN_PRICE_MULTIPLIER = 1.1e18; // Should at least be 110% of settlement price
    uint256 constant public MAX_PRICE_MULTIPLIER = 3e18; // Should not exceed 300% of settlement price
    uint256 constant public ABS_MIN_INIT_PRICE = 1e6; // Minimum sane value for init price
    uint256 constant public ABS_MAX_INIT_PRICE = type(uint192).max; // chosen so that initPrice * priceMultiplier does not exceed uint256
    uint256 constant public PRICE_MULTIPLIER_SCALE = 1e18;

    ERC20 immutable public paymentToken;
    address immutable public paymentReceiver;
    uint256 immutable public epochPeriod;
    uint256 immutable public priceMultiplier;
    uint256 immutable public minInitPrice;

    struct Slot0 {
        uint8 locked; // 1 if locked, 2 if unlocked
        uint16 epochId; // intentionally overflowable
        uint192 initPrice;
        uint40 startTime;
    }
    Slot0 internal slot0;

    event Buy(address indexed buyer, address indexed assetsReceiver, uint256 paymentAmount);

    error Reentrancy();
    error InitPriceBelowMin();
    error InitPriceExceedsMax();
    error EpochPeriodBelowMin();
    error EpochPeriodExceedsMax();
    error PriceMultiplierBelowMin();
    error PriceMultiplierExceedsMax();
    error MinInitPriceBelowMin();
    error MinInitPriceExceedsAbsMaxInitPrice();
    error DeadlinePassed();
    error EmptyAssets();
    error EpochIdMismatch();
    error MaxPaymentTokenAmountExceeded();
    error PaymentReceiverIsThis();

    modifier nonReentrant() {
        if(slot0.locked == 2) revert Reentrancy();
        slot0.locked = 2;
        _;
        slot0.locked = 1;
    }

    modifier nonReentrantView() {
        if(slot0.locked == 2) revert Reentrancy();
        _;
    }
    
    /// @dev Initializes the FeeFlowController contract with the specified parameters.
    /// @param evc The address of the Ethereum Vault Connector (EVC) contract.
    /// @param initPrice The initial price for the first epoch.
    /// @param paymentToken_ The address of the payment token.
    /// @param paymentReceiver_ The address of the payment receiver.
    /// @param epochPeriod_ The duration of each epoch period.
    /// @param priceMultiplier_ The multiplier for adjusting the price from one epoch to the next.
    /// @param minInitPrice_ The minimum allowed initial price for an epoch.
    /// @notice This constructor performs parameter validation and sets the initial values for the contract.
    constructor(address evc, uint256 initPrice, address paymentToken_, address paymentReceiver_, uint256 epochPeriod_, uint256 priceMultiplier_, uint256 minInitPrice_) MinimalEVCClient(evc) {
        if(initPrice < minInitPrice_) revert InitPriceBelowMin();
        if(initPrice > ABS_MAX_INIT_PRICE) revert InitPriceExceedsMax();
        if(epochPeriod_ < MIN_EPOCH_PERIOD) revert EpochPeriodBelowMin();
        if(epochPeriod_ > MAX_EPOCH_PERIOD) revert EpochPeriodExceedsMax();
        if(priceMultiplier_ < MIN_PRICE_MULTIPLIER) revert PriceMultiplierBelowMin();
        if(priceMultiplier_ > MAX_PRICE_MULTIPLIER) revert PriceMultiplierExceedsMax();
        if(minInitPrice_ < ABS_MIN_INIT_PRICE) revert MinInitPriceBelowMin();
        if(minInitPrice_ > ABS_MAX_INIT_PRICE) revert MinInitPriceExceedsAbsMaxInitPrice();
        if(paymentReceiver_ == address(this)) revert PaymentReceiverIsThis();

        slot0.initPrice = uint192(initPrice);
        slot0.startTime = uint40(block.timestamp);

        paymentToken = ERC20(paymentToken_);
        paymentReceiver = paymentReceiver_;
        epochPeriod = epochPeriod_;
        priceMultiplier = priceMultiplier_;
        minInitPrice = minInitPrice_;
    }


    /// @dev Allows a user to buy assets by transferring payment tokens and receiving the assets.
    /// @param assets The addresses of the assets to be bought.
    /// @param assetsReceiver The address that will receive the bought assets.
    /// @param epochId Id of the epoch to buy from, will revert if not the current epoch
    /// @param deadline The deadline timestamp for the purchase.
    /// @param maxPaymentTokenAmount The maximum amount of payment tokens the user is willing to spend.
    /// @return paymentAmount The amount of payment tokens transferred for the purchase.
    /// @notice This function performs various checks and transfers the payment tokens to the payment receiver.
    /// It also transfers the assets to the assets receiver and sets up a new auction with an updated initial price.
    function buy(address[] calldata assets, address assetsReceiver, uint256 epochId, uint256 deadline, uint256 maxPaymentTokenAmount) external nonReentrant returns(uint256 paymentAmount) {
        if(block.timestamp > deadline) revert DeadlinePassed();
        if(assets.length == 0) revert EmptyAssets();

        Slot0 memory slot0Cache = slot0;

        if(uint16(epochId) != slot0Cache.epochId) revert EpochIdMismatch();

        address sender = _msgSender();
        
        paymentAmount = getPriceFromCache(slot0Cache);

        if(paymentAmount > maxPaymentTokenAmount) revert MaxPaymentTokenAmountExceeded();
        
        if(paymentAmount > 0) {
            paymentToken.safeTransferFrom(sender, paymentReceiver, paymentAmount);
        }

        for(uint256 i = 0; i < assets.length; ++i) {
            // Transfer full balance to buyer
            uint256 balance = ERC20(assets[i]).balanceOf(address(this));
            ERC20(assets[i]).safeTransfer(assetsReceiver, balance);
        }

        // Setup new auction
        uint256 newInitPrice = paymentAmount * priceMultiplier / PRICE_MULTIPLIER_SCALE;

        if(newInitPrice > ABS_MAX_INIT_PRICE) {
            newInitPrice = ABS_MAX_INIT_PRICE;
        } else if(newInitPrice < minInitPrice) {
            newInitPrice = minInitPrice;
        }

        // epochID is allowed to overflow, effectively reusing them 
        unchecked { slot0Cache.epochId ++;}
        slot0Cache.initPrice = uint192(newInitPrice);
        slot0Cache.startTime = uint40(block.timestamp);

        // Write cache in single write
        slot0 = slot0Cache;

        emit Buy(sender, assetsReceiver, paymentAmount);

        return paymentAmount;
    }

    
    /// @dev Retrieves the current price from the cache based on the elapsed time since the start of the epoch.
    /// @param slot0Cache The Slot0 struct containing the initial price and start time of the epoch.
    /// @return price The current price calculated based on the elapsed time and the initial price.
    /// @notice This function calculates the current price by subtracting a fraction of the initial price based on the elapsed time.
    // If the elapsed time exceeds the epoch period, the price will be 0.
    function getPriceFromCache(Slot0 memory slot0Cache) internal view returns(uint256){
        uint256 timePassed = block.timestamp - slot0Cache.startTime;

        if(timePassed > epochPeriod) {
            return 0;
        }

        return slot0Cache.initPrice - slot0Cache.initPrice * timePassed / epochPeriod;
    }


    /// @dev Calculates the current price
    /// @return price The current price calculated based on the elapsed time and the initial price.
    /// @notice Uses the internal function `getPriceFromCache` to calculate the current price.
    function getPrice() external view nonReentrantView() returns(uint256){
        return getPriceFromCache(slot0);
    }


    /// @dev Retrieves Slot0 as a memory struct
    /// @return Slot0 The Slot0 value as a Slot0 struct
    function getSlot0() external view nonReentrantView() returns (Slot0 memory) {
        return slot0;
    }
}
