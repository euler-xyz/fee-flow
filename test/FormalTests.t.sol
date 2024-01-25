// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./lib/MockToken.sol";
import "./lib/ReenteringMockToken.sol";
import "../src/FeeFlowController.sol";

contract FormalTests is Test {
    uint256 public constant INIT_PRICE = 1e18;
    uint256 public constant MIN_INIT_PRICE = 1e6;
    uint256 public constant EPOCH_PERIOD = 14 days;
    uint256 public constant PRICE_MULTIPLIER = 2e18;

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
        paymentToken.mint(buyer, type(uint256).max);
    }

    // test case: https://prover.certora.com/output/13/f34cd2a033ae472f83537c188335959a/?anonymousKey=31a6b84792ad495dcba17968bf24137aff9f9e65
    function testExampleReverting() public {
        vm.startPrank(buyer);
        uint256 initPriceStart = 0xe8cabb37565e37162aed68e9984797cd;
        uint256 minInitPriceStart = 0xaff322e62439fce2132b297212e022d8;
        // set block.timestamp to 3
        vm.warp(3);
        uint256 epochPeriodStart = 0xe11;
        uint256 priceMultiplierStart = 0x8cccccccccccbee026b36aec5421380c;
        feeFlowController = new FeeFlowController(
            initPriceStart,
            address(paymentToken),
            paymentReceiver,
            epochPeriodStart,
            priceMultiplierStart,
            minInitPriceStart
        );
        console.log("slot0.initPrice", feeFlowController.getSlot0().initPrice);
        console.log("slot0.startTime", feeFlowController.getSlot0().startTime);

        paymentToken.approve(address(feeFlowController), type(uint256).max);
        vm.warp(4);
        address[] memory assets = new address[](0);
        feeFlowController.buy(assets, assetsReceiver, 4, type(uint256).max);

        uint256 initPrice = feeFlowController.getSlot0().initPrice;
        uint256 minInitPrice = feeFlowController.minInitPrice();

        console2.log("initPrice", initPrice);
        console2.log("minInitPrice", minInitPrice);
        assertGt(initPrice, minInitPrice);
        vm.stopPrank();
    }

    function testOveflowingNewInitPrice() public {
        vm.startPrank(buyer);
        uint256 initPrice = 0xf4f41;
        uint256 minInitPrice = 0xf4f41;
        uint256 startTime = 0x114c;
        vm.warp(startTime);
        uint256 epochPeriod = 0x145856;
        uint256 priceMultiplier = 0x221ea49b44e0f5dbbc639297d149734ffe91a80bf8250;
        feeFlowController = new FeeFlowController(
            initPrice, address(paymentToken), paymentReceiver, epochPeriod, priceMultiplier, minInitPrice
        );
        console.log("slot0.initPrice", feeFlowController.getSlot0().initPrice);
        console.log("slot0.startTime", feeFlowController.getSlot0().startTime);

        paymentToken.approve(address(feeFlowController), type(uint256).max);
        vm.warp(0x145857);
        address[] memory assets = new address[](0);
        uint256 paymentAmount = feeFlowController.buy(assets, assetsReceiver, 0x145857, 0xd04);
        uint256 newInitPrice = feeFlowController.getSlot0().initPrice;

        // uint256 calculationInitPrice = paymentAmount * priceMultiplier / feeFlowController.PRICE_MULTIPLIER_SCALE();
        // console.log("calculationInitPrice", calculationInitPrice);
        console2.log("paymentAmount", paymentAmount);
        console2.log("newInitPrice", newInitPrice);
        vm.stopPrank();
    }
}
