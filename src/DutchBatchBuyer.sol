// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract DutchBatchBuyer {

    uint256 constant public MIN_START_PRICE = 1e16; // 0.01
    uint256 constant public AUCTION_DURATION = 14 days; // Should settle at the half-way point roughly most of the times (7 days)
    address immutable public paymentToken;
    address immutable public receiver;

    struct Slot0 {
        uint128 startPrice;
        uint64 startTime;
    }

    Slot0 internal slot0;


    error DeadlinePassed();
    error MaxPaymentTokenAmountExceeded();

    constructor(uint128 startPrice, address paymentToken_, address receiver_) {
        require(startPrice >= MIN_START_PRICE, "DutchBatchBuyer: start price too low");
        slot0.startPrice = startPrice;
        slot0.startTime = uint64(block.timestamp);

        paymentToken = paymentToken_;
        receiver = receiver_;
    }


    // TODO reentry modifier
    function buy(address[] calldata assets, uint256 deadline, uint256 maxPaymentTokenAmount) external {
        if(block.timestamp > deadling) revert DeadlinePassed();

        Slot0 memory slot0Cache = slot0;

        

    }

    function getPriceFromCache(Slot0 memory slot0Cache) internal returns(uint256){
        uint256 timePassed = block.timestamp - slot0Cache.startTime;

        if(timePassed > AUCTION_DURATION) {
            return 0;
        }

        return slot0Cache.startPrice - slot0Cache.startPrice * timePassed / AUCTION_DURATION;
    }

    function getSlot0() public view returns (Slot0 memory) {
        return slot0;
    }

}
