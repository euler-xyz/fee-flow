// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./lib/MockToken.sol";
import "../src/DutchBatchBuyer.sol";

contract DutchBatchBuyerTest is Test {
    uint256 constant public START_PRICE = 1e18;
    
    address public paymentReceiver;
    address public buyer;
    address public assetsReceiver;

    MockToken paymentToken;
    MockToken token1;
    MockToken token2;
    MockToken token3;
    MockToken token4;
    MockToken[] public tokens;

    DutchBatchBuyer public dutchBatchBuyer;

    function setUp() public {
        // Setup addresses
        paymentReceiver = address(uint160(uint256(keccak256("paymentReceiver"))));
        vm.label(paymentReceiver, "paymentReceiver");
        buyer = address(uint160(uint256(keccak256("buyer"))));
        vm.label(buyer, "buyer");
        assetsReceiver = address(uint160(uint256(keccak256("asssetReceiver"))));
        vm.label(assetsReceiver, "assetsReceiver");

        // Deploy tokens
        paymentToken = new MockToken("Payment Token", "PAY");
        vm.label(address(paymentToken), "paymentToken");
        token1 = new MockToken("Token 1", "T1");
        vm.label(address(token1), "token1");
        tokens.push(token1);
        token2 = new MockToken("Token 2", "T2");
        vm.label(address(token2), "token2");
        tokens.push(token2);
        token3 = new MockToken("Token 3", "T3");
        vm.label(address(token3), "token3");
        tokens.push(token3);
        token4 = new MockToken("Token 4", "T4");
        vm.label(address(token4), "token4");
        tokens.push(token4);

        // Deploy DutchBatchBuyer
        dutchBatchBuyer = new DutchBatchBuyer(START_PRICE, address(paymentToken), paymentReceiver);

        // Mint payment tokens to buyer
        paymentToken.mint(buyer, 1000000e18);
        // Approve payment token from buyer to DutchBatchBuyer
        vm.startPrank(buyer);
        paymentToken.approve(address(dutchBatchBuyer), type(uint256).max);
        vm.stopPrank();
    }

    function testConstructor() public {
        DutchBatchBuyer.Slot0 memory slot0 = dutchBatchBuyer.getSlot0();
        assertEq(slot0.startPrice, uint128(START_PRICE));
        assertEq(slot0.startTime, block.timestamp);
        assertEq(address(dutchBatchBuyer.paymentToken()), address(paymentToken));
        assertEq(dutchBatchBuyer.paymentReceiver(), paymentReceiver);
    }

    function testBuyStartOfAuction() public {
        mintTokensToBatchBuyer();

        uint256 paymentReceiverBalanceBefore = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);

        uint256 expectedPrice = dutchBatchBuyer.getPrice();

        vm.startPrank(buyer);
        dutchBatchBuyer.buy(assetsAddresses(), assetsReceiver, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        uint256 paymentReceiverBalanceAfter = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceAfter = paymentToken.balanceOf(buyer);
        DutchBatchBuyer.Slot0 memory slot0 = dutchBatchBuyer.getSlot0();

        // Assert token balances
        assert0Balances(address(dutchBatchBuyer));
        assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, START_PRICE);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(buyerBalanceAfter, buyerBalanceBefore - expectedPrice);

        // Assert new auctionState
        assertEq(slot0.startPrice, uint128(START_PRICE * 2));
        assertEq(slot0.startTime, block.timestamp);
    }

    function testBuyEndOfAuction() public {
        mintTokensToBatchBuyer();

        uint256 paymentReceiverBalanceBefore = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);

        // Skip to end of auction and then some
        skip(dutchBatchBuyer.AUCTION_DURATION() + 1 days);
        uint256 expectedPrice = dutchBatchBuyer.getPrice();

        vm.startPrank(buyer);
        dutchBatchBuyer.buy(assetsAddresses(), assetsReceiver, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        uint256 paymentReceiverBalanceAfter = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceAfter = paymentToken.balanceOf(buyer);
        DutchBatchBuyer.Slot0 memory slot0 = dutchBatchBuyer.getSlot0();

        // Assert token balances
        assert0Balances(address(dutchBatchBuyer));
        assertMintBalances(assetsReceiver);
        // Should have paid 0
        assertEq(expectedPrice, 0);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore);
        assertEq(buyerBalanceAfter, buyerBalanceBefore);

        // Assert new auctionState
        assertEq(slot0.startPrice, dutchBatchBuyer.MIN_START_PRICE());
        assertEq(slot0.startTime, block.timestamp);
    }

    function testBuyMiddleOfAuction() public {
        mintTokensToBatchBuyer();

        uint256 paymentReceiverBalanceBefore = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);

        // Skip to middle of auction
        skip(dutchBatchBuyer.AUCTION_DURATION() / 2);
        uint256 expectedPrice = dutchBatchBuyer.getPrice();

        vm.startPrank(buyer);
        dutchBatchBuyer.buy(assetsAddresses(), assetsReceiver, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        uint256 paymentReceiverBalanceAfter = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceAfter = paymentToken.balanceOf(buyer);
        DutchBatchBuyer.Slot0 memory slot0 = dutchBatchBuyer.getSlot0();

        // Assert token balances
        assert0Balances(address(dutchBatchBuyer));
        assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, START_PRICE / 2);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(buyerBalanceAfter, buyerBalanceBefore - expectedPrice);

        // Assert new auctionState
        assertEq(slot0.startPrice, uint128(START_PRICE));
        assertEq(slot0.startTime, block.timestamp);
    }

    function mintTokensToBatchBuyer() public {
        for(uint256 i = 0; i < tokens.length; i++) {
            tokens[i].mint(address(dutchBatchBuyer), 1000000e18 * (i + 1));
        }
    }

    function mintAmounts() public view returns(uint256[] memory amounts) {
        amounts = new uint256[](tokens.length);
        for(uint256 i = 0; i < tokens.length; i++) {
            amounts[i] = 1000000e18 * (i + 1);
        }
        return amounts;
    }

    function assetsAddresses() public view returns(address[] memory addresses) {
        addresses = new address[](tokens.length);
        for(uint256 i = 0; i < tokens.length; i++) {
            addresses[i] = address(tokens[i]);
        }
        return addresses;
    }

    function assetsBalances(address who) public returns(uint256[] memory result) {
        result = new uint256[](tokens.length);

        for(uint256 i = 0; i < tokens.length; i ++) {
            result[i] = tokens[i].balanceOf(who);
        }

        return result;
    }

    function assertMintBalances(address who) public {
        uint256[] memory mintAmounts_ = mintAmounts();
        uint256[] memory balances = assetsBalances(who);

        for(uint256 i = 0; i < tokens.length; i ++) {
            assertEq(balances[i], mintAmounts_[i]);
        }
    }

    function assert0Balances(address who) public {
        for(uint256 i = 0; i < tokens.length; i ++) {
            uint256 balance = tokens[i].balanceOf(who);
            assertEq(tokens[i].balanceOf(who), 0);
        }
    }

}