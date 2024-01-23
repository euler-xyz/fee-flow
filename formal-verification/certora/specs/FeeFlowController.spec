import "methods/IFeeFlowController.spec";
import "helpers/erc20.spec";

// rule reachability(method f)
// {
// 	env e;
// 	calldataarg args;
// 	f(e,args);
// 	satisfy true, "a non-reverting path through this method was found";
// }

// NOTE: interesting finding is that when msg.value > 0, everything would revert becasue of no receive?

rule minPriceNeverBelowMIN_PRICE()
{
	env e;
	calldataarg args;
	buy(e, args);
	uint initPrice = getInitPrice();
	uint minInitPrice = getMinInitPrice();
	assert initPrice >= minInitPrice, "initPrice >= minInitPrice";
} 
