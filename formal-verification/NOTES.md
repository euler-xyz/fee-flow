1. Sending an empty array of assets would still transfer your funds. Maybe consider checking the length of the array?
2. minInitPrice_ can be instantiated to up to uint256(-1) (2^256 - 1)
   However in case if(newInitPrice < minInitPrice) we are setting newInitPrice = minInitPrice; and then we are casting to uint128. This means that initPrice can be less then the minInitPrice in some edge cases.
   A mitigation can be for the minInitPrice to be uint128(-1) (2^128 - 1) and then we can cast to uint128 safely.
