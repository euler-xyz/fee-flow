// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

contract DutchBatchBuyer is ReentrancyGuard {
    using SafeTransferLib for ERC20;

    uint256 constant public MIN_START_PRICE = 1e16; // 0.01     better to make it immutable, defined per input param?
    uint256 constant public AUCTION_DURATION = 14 days; // Should settle at the half-way point roughly most of the times (7 days)    better to make it immutable, defined per input param?
    ERC20 immutable public paymentToken;
    address immutable public paymentReceiver;

    struct Slot0 {
        uint128 startPrice;
        uint64 startTime;
    }
    Slot0 internal slot0;

    event Buy(address indexed buyer, address indexed assetsReceiver, uint256 paymentAmount);

    error DeadlinePassed();
    error MaxPaymentTokenAmountExceeded();


    constructor(uint256 startPrice, address paymentToken_, address paymentReceiver_) {
        require(startPrice >= MIN_START_PRICE, "DutchBatchBuyer: start price too low");
        require(paymentReceiver_ != address(this), "DutchBatchBuyer: payment receiver cannot be this contract");
        slot0.startPrice = uint128(startPrice);
        slot0.startTime = uint64(block.timestamp);

        paymentToken = ERC20(paymentToken_);
        paymentReceiver = paymentReceiver_;

        // if MIN_START_PRICE and AUCTION_DURATION are defined by input params, one should be aware of this calculation from getPriceFromCache:
        // slot0Cache.startPrice - slot0Cache.startPrice * timePassed / AUCTION_DURATION;
        // if startPrice is too low vs AUCTION_DURATION, the price will stay at startPrice and they will drop to 0 at the end of the auction
    }


    function buy(address[] calldata assets, address assetsReceiver, uint256 deadline, uint256 maxPaymentTokenAmount) external nonReentrant {
        if(block.timestamp > deadline) revert DeadlinePassed();

        Slot0 memory slot0Cache = slot0;

        uint256 paymentAmount = getPriceFromCache(slot0Cache);
        if(paymentAmount > maxPaymentTokenAmount) revert MaxPaymentTokenAmountExceeded();
        if(paymentAmount > 0) paymentToken.safeTransferFrom(msg.sender, paymentReceiver, paymentAmount);

        // idea:
        // would it make sense to integrate with the EVC to allow msg.sender == EVC and get the real caller from the EVC context?
        // note that there's no incentive for anyone to transfer the assets to this contract while the auction is live. 
        // why? because it costs gas and may increase competition for the assets while there's no guarantee that the person paying for gas
        // will be able to buy those assets. I assume that the buy() function call will always be batched in one transaction with the 
        // transfers of the assets. considering that, I assume that buyers will be using EVC.batch() to get the assets transferred to this contract
        // and then the last batch item could be the buy() function call. if integrated with the EVC, no smart contract would be needed to 
        // participate in the auction

        for(uint256 i = 0; i < assets.length; i++) {
            // Transfer full balance to buyer
            uint256 balance = ERC20(assets[i]).balanceOf(address(this));
            ERC20(assets[i]).safeTransfer(assetsReceiver, balance);
        }

        // Setup new auction
        uint256 newStartPrice = paymentAmount * 2;
        if(newStartPrice < MIN_START_PRICE) {
            newStartPrice = MIN_START_PRICE;
        }

        slot0Cache.startPrice = uint128(newStartPrice);
        slot0Cache.startTime = uint64(block.timestamp);

        // Write cache in single write
        slot0 = slot0Cache;

        emit Buy(msg.sender, assetsReceiver, paymentAmount);
    }


    function getPriceFromCache(Slot0 memory slot0Cache) internal view returns(uint256){
        uint256 timePassed = block.timestamp - slot0Cache.startTime;

        if(timePassed > AUCTION_DURATION) {
            return 0;
        }

        return slot0Cache.startPrice - slot0Cache.startPrice * timePassed / AUCTION_DURATION;
    }


    function getPrice() public view returns(uint256){
        return getPriceFromCache(slot0);
    }


    function getSlot0() public view returns (Slot0 memory) {
        return slot0;
    }
}
