// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./lib/MockToken.sol";
import "./lib/ReenteringMockToken.sol";
import "../src/FeeFlowController.sol";

contract FeeFlowControllerTest is Test {
    uint256 constant public INIT_PRICE = 1e18;
    uint256 constant public MIN_INIT_PRICE = 1e6;
    uint256 constant public EPOCH_PERIOD = 14 days;
    uint256 constant public PRICE_MULTIPLIER = 2e18;
    
    address public paymentReceiver;
    address public buyer;
    address public assetsReceiver;

    MockToken paymentToken;
    MockToken token1;
    MockToken token2;
    MockToken token3;
    MockToken token4;
    MockToken[] public tokens;

    FeeFlowController public feeFlowController;

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

        // Deploy FeeFlowController
        feeFlowController = new FeeFlowController(INIT_PRICE, address(paymentToken), paymentReceiver, EPOCH_PERIOD, PRICE_MULTIPLIER, MIN_INIT_PRICE);

        // Mint payment tokens to buyer
        paymentToken.mint(buyer, 1000000e18);
        // Approve payment token from buyer to FeeFlowController
        vm.startPrank(buyer);
        paymentToken.approve(address(feeFlowController), type(uint256).max);
        vm.stopPrank();
    }

    function testConstructor() public {
        FeeFlowController.Slot0 memory slot0 = feeFlowController.getSlot0();
        assertEq(slot0.initPrice, uint128(INIT_PRICE));
        assertEq(slot0.startTime, block.timestamp);
        assertEq(address(feeFlowController.paymentToken()), address(paymentToken));
        assertEq(feeFlowController.paymentReceiver(), paymentReceiver);
        assertEq(feeFlowController.epochPeriod(), EPOCH_PERIOD);
    }

    function testBuyStartOfAuction() public {
        mintTokensToBatchBuyer();

        uint256 paymentReceiverBalanceBefore = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);

        uint256 expectedPrice = feeFlowController.getPrice();

        vm.startPrank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        uint256 paymentReceiverBalanceAfter = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceAfter = paymentToken.balanceOf(buyer);
        FeeFlowController.Slot0 memory slot0 = feeFlowController.getSlot0();

        // Assert token balances
        assert0Balances(address(feeFlowController));
        assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, INIT_PRICE);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(buyerBalanceAfter, buyerBalanceBefore - expectedPrice);

        // Assert new auction state
        assertEq(slot0.initPrice, uint128(INIT_PRICE * 2));
        assertEq(slot0.startTime, block.timestamp);
    }

    function testBuyEndOfAuction() public {
        mintTokensToBatchBuyer();

        uint256 paymentReceiverBalanceBefore = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);

        // Skip to end of auction and then some
        skip(EPOCH_PERIOD + 1 days);
        uint256 expectedPrice = feeFlowController.getPrice();

        vm.startPrank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        uint256 paymentReceiverBalanceAfter = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceAfter = paymentToken.balanceOf(buyer);
        FeeFlowController.Slot0 memory slot0 = feeFlowController.getSlot0();

        // Assert token balances
        assert0Balances(address(feeFlowController));
        assertMintBalances(assetsReceiver);
        // Should have paid 0
        assertEq(expectedPrice, 0);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore);
        assertEq(buyerBalanceAfter, buyerBalanceBefore);

        // Assert new auctionState
        assertEq(slot0.initPrice, MIN_INIT_PRICE);
        assertEq(slot0.startTime, block.timestamp);
    }

    function testBuyMiddleOfAuction() public {
        mintTokensToBatchBuyer();

        uint256 paymentReceiverBalanceBefore = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);

        // Skip to middle of auction
        skip(EPOCH_PERIOD / 2);
        uint256 expectedPrice = feeFlowController.getPrice();

        vm.startPrank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        uint256 paymentReceiverBalanceAfter = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceAfter = paymentToken.balanceOf(buyer);
        FeeFlowController.Slot0 memory slot0 = feeFlowController.getSlot0();

        // Assert token balances
        assert0Balances(address(feeFlowController));
        assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, INIT_PRICE / 2);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(buyerBalanceAfter, buyerBalanceBefore - expectedPrice);

        // Assert new auctionState
        assertEq(slot0.initPrice, uint128(INIT_PRICE));
        assertEq(slot0.startTime, block.timestamp);
    }

    function testBuyDeadlinePassedShouldFail() public {
        mintTokensToBatchBuyer();
        skip(365 days);

        vm.startPrank(buyer);
        vm.expectRevert(FeeFlowController.DeadlinePassed.selector);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, block.timestamp - 1 days, 1000000e18);
        vm.stopPrank();

        // Double check tokens haven't moved
        assertMintBalances(address(feeFlowController));
    }

    function testBuyPaymentAmountExceedsMax() public {
        mintTokensToBatchBuyer();

        vm.startPrank(buyer);
        vm.expectRevert(FeeFlowController.MaxPaymentTokenAmountExceeded.selector);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, block.timestamp + 1 days, INIT_PRICE / 2);
        vm.stopPrank();

        // Double check tokens haven't moved
        assertMintBalances(address(feeFlowController));
    }

    function testBuyReenter() public {
        uint256 mintAmount = 1e18;

        // Setup reentering token
        ReenteringMockToken reenterToken = new ReenteringMockToken("ReenteringToken", "RET");
        reenterToken.mint(address(feeFlowController), mintAmount);
        reenterToken.setReenterTargetAndData(address(feeFlowController), abi.encodeWithSelector(feeFlowController.buy.selector, assetsAddresses(), assetsReceiver, block.timestamp + 1 days, 1000000e18));

        address[] memory assets = new address[](1);
        assets[0] = address(reenterToken);

        vm.startPrank(buyer);
        // Token does not bubble up error so this is the expected error on reentry
        vm.expectRevert("TRANSFER_FAILED");
        feeFlowController.buy(assets, assetsReceiver, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();
    }

    // Helper functions -----------------------------------------------------
    function mintTokensToBatchBuyer() public {
        for(uint256 i = 0; i < tokens.length; i++) {
            tokens[i].mint(address(feeFlowController), 1000000e18 * (i + 1));
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

    function assetsBalances(address who) public view returns(uint256[] memory result) {
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
            assertEq(balance, 0);
        }
    }

}