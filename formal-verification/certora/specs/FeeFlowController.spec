import "methods/IFeeFlowController.spec";
import "helpers/erc20.spec";

using FeeFlowControllerHarness as feeFlowController;

// Reusable functions
function constructorAssumptions(env e) {
	uint initPriceStart = getInitPrice();
	uint minInitPriceStart = getMinInitPrice();
	// if(initPrice < minInitPrice_) revert InitPriceBelowMin();
	require initPriceStart >= minInitPriceStart;

	// // this one is interesting. If we don't assume we are starting
	// // from a block with a later timestamp then the math breaks
	// uint startTime = getStartTime();
	// require startTime > 0;

	uint epochPeriodStart = getEpochPeriod();
	uint MIN_EPOCH_PERIOD = getMIN_EPOCH_PERIOD();
	// if(epochPeriod_ < MIN_EPOCH_PERIOD) revert EpochPeriodBelowMin();
	require epochPeriodStart >= MIN_EPOCH_PERIOD;

	uint priceMultiplierStart = getPriceMultiplier();
	uint MIN_PRICE_MULTIPLIER = getMIN_PRICE_MULTIPLIER();
	// if(priceMultiplier_ < MIN_PRICE_MULTIPLIER) revert PriceMultiplierBelowMin();
	require priceMultiplierStart >= MIN_PRICE_MULTIPLIER;
	
	uint MIN_MIN_INIT_PRICE = getMIN_MIN_INIT_PRICE();
	// if(minInitPrice_ < MIN_MIN_INIT_PRICE) revert MinInitPriceBelowMin();
	require minInitPriceStart >= MIN_MIN_INIT_PRICE;

	// require e.block.timestamp >= startTime;
}

function initialStateAssertions(env e) {
	uint initPrice = getInitPrice();
	uint minInitPrice = getMinInitPrice();
	uint epochPeriod = getEpochPeriod();
	uint priceMultiplier = getPriceMultiplier();
	uint startTime = getStartTime();
	uint MIN_EPOCH_PERIOD = getMIN_EPOCH_PERIOD();
	uint MIN_PRICE_MULTIPLIER = getMIN_PRICE_MULTIPLIER();
	uint MIN_MIN_INIT_PRICE = getMIN_MIN_INIT_PRICE();

	assert initPrice >= minInitPrice, "initPrice >= minInitPrice";
	assert epochPeriod >= MIN_EPOCH_PERIOD, "epochPeriod >= MIN_EPOCH_PERIOD";
	assert priceMultiplier >= MIN_PRICE_MULTIPLIER, "priceMultiplier >= MIN_PRICE_MULTIPLIER";
	assert minInitPrice >= MIN_MIN_INIT_PRICE, "minInitPrice >= MIN_MIN_INIT_PRICE";
	assert e.block.timestamp >= startTime, "e.block.timestamp >= startTime";
}

// Ghost functions and hooks
// https://docs.certora.com/en/latest/docs/cvl/ghosts.html?highlight=saw_user_defined_revert_msg#persistent-ghosts-that-survive-reverts
// this only works for solidity versions prior to 0.8.x
// persistent ghost bool saw_user_defined_revert_msg;

// hook REVERT(uint offset, uint size) {
//     if (size > 0) {
//         saw_user_defined_revert_msg = true;
// 	}
// }
persistent ghost bool reentrancy_happened {
    init_state axiom !reentrancy_happened;
}

hook CALL(uint g, address addr, uint value, uint argsOffset, uint argsLength, 
          uint retOffset, uint retLength) uint rc {
    if (addr == currentContract) {
        reentrancy_happened = reentrancy_happened 
                                || executingContract == currentContract;
    }
}

// Invariants
invariant no_reentrant_calls() !reentrancy_happened;

// Rules
rule reachability(method f)
{
	env e;
	calldataarg args;
	feeFlowController.f(e,args);
	satisfy true, "a non-reverting path through this method was found";
}

rule check_initailStateAssertionsAfterBuy() {
	env e;
	constructorAssumptions(e);
	calldataarg args;
	buy(e, args);
	initialStateAssertions(e);
}

rule check_buyNeverRevertsUnexpectedly() {
	env e;
	constructorAssumptions(e);
	reentrancyMock();
	address[] assets; address assetsReceiver; uint256 deadline; uint256 maxPaymentTokenAmount;
	uint initPriceStart = getInitPrice();
	require(maxPaymentTokenAmount > initPriceStart);
	require(e.block.timestamp <= deadline);
	uint paymentAmount = getPrice(e);
	require(paymentAmount <= maxPaymentTokenAmount && paymentAmount > 0);
	require(e.msg.value == 0); // if we send ether the transaction will revert
	// we have enough allowance and we have enough balance
	uint256 allowance = feeFlowController.getPymentTokenAllowance(e, e.msg.sender);
	uint256 balance = feeFlowController.getPaymentTokenBalanceOf(e, e.msg.sender);
	address receiver = feeFlowController.paymentReceiver();
	uint256 receiverBalance = feeFlowController.getPaymentTokenBalanceOf(e, receiver);
	require(balance >= paymentAmount && balance > 0 && allowance >= paymentAmount && allowance > 0);
	mathint afterBalance =  receiverBalance + paymentAmount;
	require(afterBalance < max_uint256);
	buy@withrevert(e, assets, assetsReceiver, deadline, maxPaymentTokenAmount);
	assert !lastReverted, "buy never reverts with arithmetic exceptions or internal solidity reverts";
}

rule check_buyNextInitPriceAtLeastBuyPriceTimesMultiplier() {
	env e;
	constructorAssumptions(e);
	calldataarg args;
	
	mathint paymentAmount = buy@withrevert(e, args);

	mathint priceMultiplier = getPriceMultiplier();
	mathint PRICE_MULTIPLIER_SCALE = getPRICE_MULTIPLIER_SCALE();
	mathint predictedInitPrice = paymentAmount * priceMultiplier / PRICE_MULTIPLIER_SCALE;

	mathint initPriceAfter = getInitPrice();
	assert initPriceAfter == predictedInitPrice, "initPrice >= newInitPrice";
}

// todo: check if after epoch ends you can buy without paying?
