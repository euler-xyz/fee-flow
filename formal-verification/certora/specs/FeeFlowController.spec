import "methods/IFeeFlowController.spec";
import "helpers/erc20.spec";

rule minPriceNeverBelowMIN_PRICE()
{
	// todo: verify the constructor args separately and that they revert if they are not valid
	uint initPriceStart = getInitPrice();
	uint minInitPriceStart = getMinInitPrice();
	require initPriceStart >= minInitPriceStart;

	uint startTime = getStartTime();
	require startTime > 0;

	uint epochPeriodStart = getEpochPeriod();
	uint MIN_EPOCH_PERIOD = getMIN_EPOCH_PERIOD();
	require epochPeriodStart >= MIN_EPOCH_PERIOD;

	uint priceMultiplierStart = getPriceMultiplier();
	uint MIN_PRICE_MULTIPLIER = getMIN_PRICE_MULTIPLIER();
	require priceMultiplierStart >= MIN_PRICE_MULTIPLIER;
	
	uint MIN_MIN_INIT_PRICE = getMIN_MIN_INIT_PRICE();
	require minInitPriceStart >= MIN_MIN_INIT_PRICE;

	env e;

	require e.block.timestamp >= startTime;

	calldataarg args;
	buy(e, args);
	
	uint initPrice = getInitPrice();
	uint minInitPrice = getMinInitPrice();
	assert initPrice >= minInitPrice, "initPrice >= minInitPrice";
} 
