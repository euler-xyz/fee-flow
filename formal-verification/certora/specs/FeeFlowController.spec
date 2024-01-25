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

rule check_initPriceAlwaysMoreThenMinInitPrice() {
	env e;
	constructorAssumptions(e);
	calldataarg args;
	buy(e, args);
	uint initPrice = getInitPrice();
	uint minInitPrice = getMinInitPrice();
	assert initPrice >= minInitPrice, "initPrice >= minInitPrice";
} 

// rule check_newPriceAlwaysAtLeast10PercentMoreThenPrvious {

// }

// check no reentrancy
