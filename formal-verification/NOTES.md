~~ 1. Sending an empty array of assets would still transfer your funds. Maybe consider checking the length of the array?~~ (Resolved)

~~2. minInitPrice_ can be instantiated to up to uint256(-1) (2^256 - 1)~~
   ~~However in case if(newInitPrice < minInitPrice) we are setting newInitPrice = minInitPrice; and then we are casting to uint128. This means that initPrice can be less then the minInitPrice in some edge cases.~~
   ~~A mitigation can be for the minInitPrice to be uint128(-1) (2^128 - 1) and then we can cast to uint128 safely.~~ (Resolved)

3. Some tokens that are have some value but change their balance in a case of a real execution vs staticCall execution might bait a buy that transfers the payment amount but the received value is 0 for example. It would be more of a phishing attack if anyone can deploy a fee flow controller.

4. (INFO) Fee on transfer tokens might cause the emit of incorrect event amounts. Something to keep in mind.

5. (INFO) for gas optimization you can transfer the whole balance -1 wei to keep the slot non-zero. This will keep the gas cost constant and more predictable as well.

6. The init price casting has some edge cases where the price can go above uint128 and then it will be casted to uint128. This can be mitigated by setting the max price to uint128(-1) and then casting to uint128. This will make sure that the price will never go above uint128. The fix to this is in the FeeFlowController.sol.patch file.
