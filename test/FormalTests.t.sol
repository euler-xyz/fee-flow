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
        // vm.startPrank(buyer);
        // uint256 initPriceStart = 0xf428a;
        // uint256 minInitPriceStart = 0xf4240;
        // // set block.timestamp to 3
        // vm.warp(14);
        // uint256 epochPeriodStart = 0x3aef5;
        // uint256 priceMultiplierStart = 0x676925f103a388c689c33dac27fe21e9449f1f6120ce97;
        // feeFlowController = new FeeFlowController(
        //     address(1),
        //     initPriceStart,
        //     address(paymentToken),
        //     paymentReceiver,
        //     epochPeriodStart,
        //     priceMultiplierStart,
        //     minInitPriceStart
        // );
        // console.log("slot1.initPrice", feeFlowController.getSlot1().initPrice);
        // console.log("slot1.startTime", feeFlowController.getSlot1().startTime);

        // paymentToken.approve(address(feeFlowController), type(uint256).max);
        // vm.warp(4);
        // // address[] memory assets = new address[](0);
        // feeFlowController.buy(assetsAddresses(), assetsReceiver, 4, type(uint256).max);

        // uint256 initPrice = feeFlowController.getSlot1().initPrice;
        // uint256 minInitPrice = feeFlowController.minInitPrice();

        // console2.log("initPrice", initPrice);
        // console2.log("minInitPrice", minInitPrice);
        // assertGt(initPrice, minInitPrice);
        // vm.stopPrank();
        uint paymentAmount = 0xe8ba2e8c8ba2ab72d3a499cae3102907;
        uint priceMultiplier = 0xf43fc2c04ee0405;
        uint scale = 1e18;
        uint result = paymentAmount * priceMultiplier / scale;
        console2.log("paymentAmount", paymentAmount);
        console2.log("result", uint128(result));
        console2.log("paymentAmount < result", paymentAmount < uint128(result));
    }

    function assetsAddresses() public view returns (address[] memory addresses) {
        addresses = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            addresses[i] = address(tokens[i]);
        }
        return addresses;
    }
}
