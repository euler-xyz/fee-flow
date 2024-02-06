// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "evc/EthereumVaultConnector.sol";
import "./lib/MockToken.sol";
import "./lib/ReenteringMockToken.sol";
import "./lib/PredictAddress.sol";
import "../src/FeeFlowController.sol";

contract FeeFlowControllerTest is Test {
    uint256 constant public INIT_PRICE = 1e18;
    uint256 constant public MIN_INIT_PRICE = 1e6;
    uint256 constant public EPOCH_PERIOD = 14 days;
    uint256 constant public PRICE_MULTIPLIER = 2e18;
    
    address public paymentReceiver = makeAddr("paymentReceiver");
    address public buyer = makeAddr("buyer");
    address public assetsReceiver = makeAddr("assetsReceiver");

    MockToken paymentToken;
    MockToken token1;
    MockToken token2;
    MockToken token3;
    MockToken token4;
    MockToken[] public tokens;

    IEVC public evc;
    FeeFlowController public feeFlowController;

    function setUp() public {
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

        // Deploy EVC
        evc = new EthereumVaultConnector();

        // Deploy FeeFlowController
        feeFlowController = new FeeFlowController(address(evc), INIT_PRICE, address(paymentToken), paymentReceiver, EPOCH_PERIOD, PRICE_MULTIPLIER, MIN_INIT_PRICE);

        // Mint payment tokens to buyer
        paymentToken.mint(buyer, 1000000e18);
        // Approve payment token from buyer to FeeFlowController
        vm.startPrank(buyer);
        paymentToken.approve(address(feeFlowController), type(uint256).max);
        vm.stopPrank();
    }

    function testConstructor() public {
        FeeFlowController.Slot1 memory slot1 = feeFlowController.getSlot1();
        assertEq(address(feeFlowController.evc()), address(evc));
        assertEq(slot1.initPrice, uint128(INIT_PRICE));
        assertEq(slot1.startTime, block.timestamp);
        assertEq(address(feeFlowController.paymentToken()), address(paymentToken));
        assertEq(feeFlowController.paymentReceiver(), paymentReceiver);
        assertEq(feeFlowController.epochPeriod(), EPOCH_PERIOD);
        assertEq(feeFlowController.priceMultiplier(), PRICE_MULTIPLIER);
        assertEq(feeFlowController.minInitPrice(), MIN_INIT_PRICE);
    }

    function testConstructorInitPriceBelowMin() public {
        vm.expectRevert(FeeFlowController.InitPriceBelowMin.selector);
        new FeeFlowController(address(evc), MIN_INIT_PRICE - 1, address(paymentToken), paymentReceiver, EPOCH_PERIOD, PRICE_MULTIPLIER, MIN_INIT_PRICE);
    }

    function testConstructorEpochPeriodBelowMin() public {
        uint256 minEpochPeriod = feeFlowController.MIN_EPOCH_PERIOD();
        vm.expectRevert(FeeFlowController.EpochPeriodBelowMin.selector);
        new FeeFlowController(address(evc), INIT_PRICE, address(paymentToken), paymentReceiver, minEpochPeriod - 1, PRICE_MULTIPLIER, MIN_INIT_PRICE);
    }

    function testConstructorEpochPeriodExceedsMax() public {
        uint256 maxEpochPeriod = feeFlowController.MAX_EPOCH_PERIOD();
        vm.expectRevert(FeeFlowController.EpochPeriodExceedsMax.selector);
        new FeeFlowController(address(evc), INIT_PRICE, address(paymentToken), paymentReceiver, maxEpochPeriod + 1, PRICE_MULTIPLIER, MIN_INIT_PRICE);
    }

    function testConstructorPriceMultiplierBelowMin() public {
        uint256 minPriceMultiplier = feeFlowController.MIN_PRICE_MULTIPLIER();
        vm.expectRevert(FeeFlowController.PriceMultiplierBelowMin.selector);
        new FeeFlowController(address(evc), INIT_PRICE, address(paymentToken), paymentReceiver, EPOCH_PERIOD, minPriceMultiplier - 1, MIN_INIT_PRICE);
    }

    function testConstructorMinInitPriceBelowMin() public {
        uint256 absMinInitPrice = feeFlowController.ABS_MIN_INIT_PRICE();
        vm.expectRevert(FeeFlowController.MinInitPriceBelowMin.selector);
        new FeeFlowController(address(evc), INIT_PRICE, address(paymentToken), paymentReceiver, EPOCH_PERIOD, PRICE_MULTIPLIER, absMinInitPrice - 1);
    }

    function testConstructorMinInitPriceExceedsABSMaxInitPrice() public {
        // Fails at init price check
        vm.expectRevert(FeeFlowController.InitPriceExceedsMax.selector);
        new FeeFlowController(address(evc), uint256(type(uint216).max) + 2, address(paymentToken), paymentReceiver, EPOCH_PERIOD, PRICE_MULTIPLIER, uint256(type(uint216).max) + 1);
    }

    function testConstructorPaymentReceiverIsThis() public {
        address deployer = makeAddr("deployer");
        address expectedAddress = PredictAddress.calc(deployer, 0);

        vm.startPrank(deployer);
        vm.expectRevert(FeeFlowController.PaymentReceiverIsThis.selector);
        new FeeFlowController(address(evc), INIT_PRICE, address(paymentToken), expectedAddress, EPOCH_PERIOD, PRICE_MULTIPLIER, MIN_INIT_PRICE);
        vm.stopPrank();
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
        FeeFlowController.Slot1 memory slot1 = feeFlowController.getSlot1();

        // Assert token balances
        assert0Balances(address(feeFlowController));
        assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, INIT_PRICE);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(buyerBalanceAfter, buyerBalanceBefore - expectedPrice);

        // Assert new auction state
        assertEq(slot1.initPrice, uint128(INIT_PRICE * 2));
        assertEq(slot1.startTime, block.timestamp);
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
        FeeFlowController.Slot1 memory slot1 = feeFlowController.getSlot1();

        // Assert token balances
        assert0Balances(address(feeFlowController));
        assertMintBalances(assetsReceiver);
        // Should have paid 0
        assertEq(expectedPrice, 0);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore);
        assertEq(buyerBalanceAfter, buyerBalanceBefore);

        // Assert new auctionState
        assertEq(slot1.initPrice, MIN_INIT_PRICE);
        assertEq(slot1.startTime, block.timestamp);
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
        FeeFlowController.Slot1 memory slot1 = feeFlowController.getSlot1();

        // Assert token balances
        assert0Balances(address(feeFlowController));
        assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, INIT_PRICE / 2);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(buyerBalanceAfter, buyerBalanceBefore - expectedPrice);

        // Assert new auctionState
        assertEq(slot1.initPrice, uint128(INIT_PRICE));
        assertEq(slot1.startTime, block.timestamp);
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

    function testBuyEmptyAssetsShouldFail() public {
        mintTokensToBatchBuyer();

        vm.startPrank(buyer);
        vm.expectRevert(FeeFlowController.EmptyAssets.selector);
        feeFlowController.buy(new address[](0), assetsReceiver, block.timestamp + 1 days, 1000000e18);
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

    function testBuyInitPriceExceedingABS_MAX_INIT_PRICE() public {
        uint256 absMaxInitPrice = feeFlowController.ABS_MAX_INIT_PRICE();

        // Deploy with auction at max init price
        FeeFlowController tempFeeFlowController = new FeeFlowController(address(evc), absMaxInitPrice, address(paymentToken), paymentReceiver, EPOCH_PERIOD, 1.1e18, absMaxInitPrice);

        // Mint payment tokens to buyer
        paymentToken.mint(buyer, type(uint216).max);

        vm.startPrank(buyer);
        // Approve payment token from buyer to FeeFlowController
        paymentToken.approve(address(tempFeeFlowController), type(uint256).max);
        // Buy
        tempFeeFlowController.buy(assetsAddresses(), assetsReceiver, block.timestamp + 1 days, type(uint216).max);
        vm.stopPrank();

        // Assert new init price
        FeeFlowController.Slot1 memory slot1 = tempFeeFlowController.getSlot1();
        assertEq(slot1.initPrice, uint216(absMaxInitPrice));
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