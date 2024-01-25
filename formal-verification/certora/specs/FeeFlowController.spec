import "methods/IFeeFlowController.spec";
import "helpers/erc20.spec";

using FeeFlowControllerHarness as feeFlowController;

rule reachability(method f)
{
	env e;
	calldataarg args;
	feeFlowController.f(e,args);
	satisfy true, "a non-reverting path through this method was found";
}

function constructorAssumptions(env e) {
	uint initPriceStart = getInitPrice();
	uint minInitPriceStart = getMinInitPrice();
	// if(initPrice < minInitPrice_) revert InitPriceBelowMin();
	require initPriceStart >= minInitPriceStart;

	// this one is interesting. If we don't assume we are starting
	// from a block with a later timestamp then the math breaks
	uint startTime = getStartTime();
	require startTime > 0;

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

	require e.block.timestamp >= startTime;
}

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

invariant no_reentrant_calls() !reentrancy_happened;

// make sure we never violate the initial state assumptions
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

rule check_initailStateAssertionsAfterBuy() {
	env e;
	constructorAssumptions(e);
	calldataarg args;
	buy(e, args);
	initialStateAssertions(e);
}

rule check_buyNeverThrows() {
	env e;
	constructorAssumptions(e);
	calldataarg args;
	buy@withrevert(e, args);
	assert !lastHasThrown, "buy never throws";
}

// todo: check if after epoch ends you can buy without paying?
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
