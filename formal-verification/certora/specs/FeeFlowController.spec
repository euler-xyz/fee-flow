import "methods/IFeeFlowController.spec";
import "helpers/erc20.spec";

using FeeFlowControllerHarness as feeFlowController;

// Reusable functions
function constructorAssumptions(env e) {
	uint initPriceStart = getInitPrice();
	uint minInitPriceStart = getMinInitPrice();
	uint ABS_MIN_INIT_PRICE = getABS_MIN_INIT_PRICE();
	uint ABS_MAX_INIT_PRICE = getABS_MAX_INIT_PRICE();
	uint MIN_PRICE_MULTIPLIER = getMIN_PRICE_MULTIPLIER();
	uint MAX_PRICE_MULTIPLIER = getMAX_PRICE_MULTIPLIER();

	//! if(initPrice < minInitPrice_) revert InitPriceBelowMin();
	require initPriceStart >= minInitPriceStart;
	
	//! if(initPrice > ABS_MAX_INIT_PRICE) revert InitPriceAboveMax();
	require initPriceStart <= ABS_MAX_INIT_PRICE;

	uint epochPeriodStart = getEpochPeriod();
	uint MIN_EPOCH_PERIOD = getMIN_EPOCH_PERIOD();
	
	//! if(epochPeriod_ < MIN_EPOCH_PERIOD) revert EpochPeriodBelowMin();
	require epochPeriodStart >= MIN_EPOCH_PERIOD;
	
	//! if(epochPeriod_ > MAX_EPOCH_PERIOD) revert EpochPeriodExceedsMax();
	uint MAX_EPOCH_PERIOD = getMAX_EPOCH_PERIOD();
	require epochPeriodStart <= MAX_EPOCH_PERIOD;

	uint priceMultiplierStart = getPriceMultiplier();
	
	//! if(priceMultiplier_ < MIN_PRICE_MULTIPLIER) revert PriceMultiplierBelowMin();
	require priceMultiplierStart >= MIN_PRICE_MULTIPLIER;

	// ! if(priceMultiplier_ > MAX_PRICE_MULTIPLIER) revert PriceMultiplierAboveMax();
	require priceMultiplierStart <= MAX_PRICE_MULTIPLIER;
	
	//! if(minInitPrice_ < ABS_MIN_INIT_PRICE) revert MinInitPriceBelowMin();
	require minInitPriceStart >= ABS_MIN_INIT_PRICE;

	//! if(minInitPrice_ > ABS_MAX_INIT_PRICE) revert MinInitPriceExceedsuint128();
	require minInitPriceStart <= ABS_MAX_INIT_PRICE;

	//! if(paymentReceiver_ == address(this)) revert PaymentReceiverIsThis();
	address paymentReceiver = getPaymentReceiver();
	require(paymentReceiver != feeFlowController);
}

function initialStateAssertions(env e) {
	uint initPrice = getInitPrice();
	uint minInitPrice = getMinInitPrice();
	uint epochPeriod = getEpochPeriod();
	uint priceMultiplier = getPriceMultiplier();
	uint startTime = getStartTime();
	uint MIN_EPOCH_PERIOD = getMIN_EPOCH_PERIOD();
	uint MIN_PRICE_MULTIPLIER = getMIN_PRICE_MULTIPLIER();
	uint ABS_MIN_INIT_PRICE = getABS_MIN_INIT_PRICE();
	uint ABS_MAX_INIT_PRICE = getABS_MAX_INIT_PRICE();

	assert initPrice >= minInitPrice, "initPrice >= minInitPrice";
	assert initPrice <= ABS_MAX_INIT_PRICE, "initPrice < ABS_MAX_INIT_PRICE";
	assert epochPeriod >= MIN_EPOCH_PERIOD, "epochPeriod >= MIN_EPOCH_PERIOD";
	assert priceMultiplier >= MIN_PRICE_MULTIPLIER, "priceMultiplier >= MIN_PRICE_MULTIPLIER";
	assert minInitPrice >= ABS_MIN_INIT_PRICE, "minInitPrice >= ABS_MIN_INIT_PRICE";
	assert minInitPrice <= ABS_MAX_INIT_PRICE, "minInitPrice <= ABS_MAX_INIT_PRICE";
	assert e.block.timestamp >= startTime, "e.block.timestamp >= startTime";
}

function requirementsForSuccessfulBuyExecution(env e, address[] assets, address assetsReceiver,uint256 epochId, uint256 deadline, uint256 maxPaymentTokenAmount) {
	reentrancyMock(); // this sets the lock to the correct initial value
	uint256 initPriceStart = getInitPrice();
	require(epochId == getEpochId());
	require(maxPaymentTokenAmount > initPriceStart);
	require(e.block.timestamp <= deadline);
	uint256 paymentAmount = getPrice(e);
	require(paymentAmount <= maxPaymentTokenAmount && paymentAmount > 0);
	require(e.msg.value == 0); // if we send ether the transaction will revert
	// we have enough allowance and we have enough balance
	uint256 allowance = feeFlowController.getPaymentTokenAllowance(e, e.msg.sender);
	uint256 balance = feeFlowController.getPaymentTokenBalanceOf(e, e.msg.sender);
	address receiver = feeFlowController.paymentReceiver();
	require(receiver != 0); // this is for us to cover the ERC20Basic implementation
	require(e.msg.sender != 0);

	uint256 receiverBalance = feeFlowController.getPaymentTokenBalanceOf(e, receiver);
	mathint receiverNewBalance = receiverBalance + paymentAmount;
	require(receiverNewBalance < max_uint256);
	require(balance >= paymentAmount && allowance >= balance);
	require(assets.length == 1); // making 1 transfer for simplicity

	address token = assets[0];
	require(assetsReceiver != 0); // make sure the receiver is not 0
	require(assetsReceiver != receiver); // make sure the receiver is not the payment receiver
	uint256 feeControllerTokenBalance = feeFlowController.getTokenBalanceOf(e, token, feeFlowController);
	uint256 assetReceiverTokenBalance = feeFlowController.getTokenBalanceOf(e, token, assetsReceiver);
	uint256 assetReceiverTokenBalanceAfter = require_uint256(feeControllerTokenBalance + assetReceiverTokenBalance);
}

persistent ghost bool reentrancy_happened {
    init_state axiom !reentrancy_happened;
}

persistent ghost bool reverted {
	init_state axiom !reverted;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, 
          uint retOffset, uint retLength) uint rc {
    if (addr == currentContract) {
        reentrancy_happened = reentrancy_happened 
                                || executingContract == currentContract;
    }
}

hook REVERT(uint offset, uint size) {
	reverted = true;
}

// Invariants
// NOTE: we are executing optimistic dispatches for the ERC20 tokens
invariant invariant_no_reentrant_calls() !reentrancy_happened || reentrancy_happened && reverted;
invariant invariant_init_price_must_be_in_range() getInitPrice() >= getMinInitPrice() && getInitPrice() <= getABS_MAX_INIT_PRICE();
invariant invariant_price_must_be_below_max_init_price(env e) getPrice(e) <= getInitPrice();


// Rules
rule reachability(method f)
{
	env e;
	calldataarg args;
	feeFlowController.f(e,args);
	satisfy true, "a non-reverting path through this method was found";
}

rule check_constructorAssumptionsSatisfiedAfterBuy() {
	env e;
	constructorAssumptions(e);
	calldataarg args;
	buy(e, args);
	initialStateAssertions(e);
}

rule check_buyNeverRevertsUnexpectedly() {
	env e;
	constructorAssumptions(e);
	address[] assets; address assetsReceiver; uint256 epochId; uint256 deadline; uint256 maxPaymentTokenAmount;
	requirementsForSuccessfulBuyExecution(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);
	buy@withrevert(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);
	assert !lastReverted, "buy never reverts with arithmetic exceptions or internal solidity reverts";
}

rule check_buyNextInitPriceAtLeastBuyPriceTimesMultiplier() {
	env e;
	constructorAssumptions(e);
	calldataarg args;
	address[] assets; address assetsReceiver; uint256 epochId; uint256 deadline; uint256 maxPaymentTokenAmount;
	requirementsForSuccessfulBuyExecution(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);
	mathint paymentAmount = buy@withrevert(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);

	mathint priceMultiplier = getPriceMultiplier();
	mathint PRICE_MULTIPLIER_SCALE = getPRICE_MULTIPLIER_SCALE();
	mathint predictedInitPrice = paymentAmount * priceMultiplier / PRICE_MULTIPLIER_SCALE;

	mathint initPriceAfter = getInitPrice();
	mathint minInitPrice = getMinInitPrice();
	mathint absMaxInitPrice = getABS_MAX_INIT_PRICE();
	if (predictedInitPrice < minInitPrice) {
		assert initPriceAfter == minInitPrice, "initPrice == minInitPrice";
	} else {
		if(predictedInitPrice > absMaxInitPrice) { 
			assert initPriceAfter == absMaxInitPrice, "initPrice == ABS_MAX_INIT_PRICE";
		} else {
			assert initPriceAfter == predictedInitPrice, "initPrice == paymentAmount * priceMultiplier / PRICE_MULTIPLIER_SCALE";
		}
	}
}

// Balance of fee flow controller of a bought asset is always 0 after buy
rule check_feeFlowControllerTokenBalanceOfAfterBuy() {
	env e;
	constructorAssumptions(e);
	address[] assets; address assetsReceiver; uint256 epochId; uint256 deadline; uint256 maxPaymentTokenAmount;

	require(assets.length == 1); // making 1 transfer for simplicity and since we have no loops in CVL
	require(assetsReceiver != feeFlowController); // make sure the receiver is not feeFlowController

	buy(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);
	uint256 feeControllerTokenBalance = feeFlowController.getTokenBalanceOf(e, assets[0], feeFlowController);
	assert feeControllerTokenBalance == 0, "feeFlowController.getTokenBalanceOf(assets[0], feeFlowController) == 0";
}

// Balance of asset receiver is incremented by balance of fee flow controller after buy
rule check_balanceOfAssetsReceiverIsIncrementedByFeeFlowControllerTokenBalanceOfAfterBuy() {
	env e;
	constructorAssumptions(e);
	address[] assets; address assetsReceiver; uint256 epochId; uint256 deadline; uint256 maxPaymentTokenAmount;

	require(assets.length == 1); // making 1 transfer for simplicity and since we have no loops in CVL

	require(assetsReceiver != feeFlowController); // make sure the receiver is not feeFlowController
	require(assets[0] != getPaymentToken()); // make sure the asset is not the payment token

	uint256 assetReceiverTokenBalance = feeFlowController.getTokenBalanceOf(e, assets[0], assetsReceiver);
	uint256 feeControllerTokenBalance = feeFlowController.getTokenBalanceOf(e, assets[0], feeFlowController);
	uint256 assetReceiverTokenBalanceAfterPredicted = require_uint256(feeControllerTokenBalance + assetReceiverTokenBalance);

	buy(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);

	assert feeFlowController.getTokenBalanceOf(e, assets[0], assetsReceiver) == assetReceiverTokenBalanceAfterPredicted, "feeFlowController.getTokenBalanceOf(assets[0], assetsReceiver) == assetReceiverTokenBalanceAfter";
}

// Balance of buyer is reduced by payment amount, and never by more than max payment amount
rule check_balanceOfBuyerIsReducedByPaymentAmount() {
	env e;
	constructorAssumptions(e);
	address[] assets; address assetsReceiver; uint256 epochId; uint256 deadline; uint256 maxPaymentTokenAmount;

	require(assets.length == 1); // making 1 transfer for simplicity and since we have no loops in CVL

	require(assetsReceiver != feeFlowController); // make sure the receiver is not feeFlowController
	require(assets[0] != getPaymentToken()); // make sure the asset is not the payment toke
	require(getPaymentReceiver() != e.msg.sender); // make sure the payment receiver is not the buyer

	uint256 paymentAmount = getPrice(e);
	uint256 balanceBefore = feeFlowController.getPaymentTokenBalanceOf(e, e.msg.sender);
	buy(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);
	uint256 balanceAfter = feeFlowController.getPaymentTokenBalanceOf(e, e.msg.sender);
	assert to_mathint(balanceAfter) == (balanceBefore - paymentAmount), "msg.sender (PaymentToken) => balanceAfter == (balanceBefore - paymentAmount)";
}

// Balance of payment receiver is increased by payment amount
rule check_balanceOfPaymentReceiverIsIncreasedByPaymentAmount() {
	env e;
	constructorAssumptions(e);
	address[] assets; address assetsReceiver; uint256 epochId; uint256 deadline; uint256 maxPaymentTokenAmount;

	require(assets.length == 1); // making 1 transfer for simplicity and since we have no loops in CVL

	require(assetsReceiver != feeFlowController); // make sure the receiver is not feeFlowController
	require(assets[0] != getPaymentToken()); // make sure the asset is not the payment token
	require(getPaymentReceiver() != e.msg.sender); // make sure the payment receiver is not the buyer

	uint256 paymentAmount = getPrice(e);
	address paymentReceiver = getPaymentReceiver();

	uint256 balanceBefore = feeFlowController.getPaymentTokenBalanceOf(e, paymentReceiver);
	buy(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);
	uint256 balanceAfter = feeFlowController.getPaymentTokenBalanceOf(e, paymentReceiver);
	assert to_mathint(balanceAfter) == (balanceBefore + paymentAmount), "paymentReceiver (PaymentToken) => balanceAfter == (balanceBefore + paymentAmount)";
}

// Payment amount returned on buy is never higher than maximum payout
rule check_paymentAmountReturnedOnBuyIsNeverHigherThanMaximumPayout() {
	env e;
	constructorAssumptions(e);
	address[] assets; address assetsReceiver; uint256 epochId; uint256 deadline; uint256 maxPaymentTokenAmount;

	require(assets.length == 1); // making 1 transfer for simplicity and since we have no loops in CVL

	require(assetsReceiver != feeFlowController); // make sure the receiver is not feeFlowController
	require(assets[0] != getPaymentToken()); // make sure the asset is not the payment token
	require(getPaymentReceiver() != e.msg.sender); // make sure the payment receiver is not the buyer

	uint256 paymentAmount = getPrice(e);
	uint256 balanceBefore = feeFlowController.getPaymentTokenBalanceOf(e, assetsReceiver);
	buy(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);
	uint256 balanceAfter = feeFlowController.getPaymentTokenBalanceOf(e, assetsReceiver);
	assert paymentAmount <= maxPaymentTokenAmount, "paymentAmount <= maxPaymentTokenAmount";
	assert to_mathint(balanceAfter) <= (balanceBefore + maxPaymentTokenAmount), "balanceAfter <= (balanceBefore + maxPaymentTokenAmount)";
}

// Epoch Id is always incremented by 1 after buy (and becomes 0 if it reaches max uint16)
rule check_epochIdAlwaysIncrementedBy1AfterBuy() {
	env e;
	constructorAssumptions(e);
	address[] assets; address assetsReceiver; uint256 epochId; uint256 deadline; uint256 maxPaymentTokenAmount;
	uint256 epochIdBefore = getEpochId();
	buy(e, assets, assetsReceiver, epochId, deadline, maxPaymentTokenAmount);
	uint256 epochIdAfter = getEpochId();
	assert (epochIdAfter == 0 && epochIdBefore == max_uint16) || epochIdAfter == assert_uint256(epochIdBefore + 1), "epochIdAfter == (epochIdBefore + 1) || (epochIdAfter == 0 && epochIdBefore == 65535)";
}
