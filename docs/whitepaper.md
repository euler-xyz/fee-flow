# Fee Flow

## Authors

Mick de Graaf & Michael Bentley

## Introduction 

Protocols in decentralised finance (DeFi) often generate revenues by accruing fees across a range of markets in a variety of different asset types. The default behaviour of the protocol will typically be to hold all these asset types on the protocol’s balance sheet as protocol-owned liquidity (POL). However, this will often be a suboptimal use of accrued fees. 

In many instances it might be beneficial for the protocol to convert accrued fees into a single currency (perhaps USDC or ETH or the project’s native token) for accumulation or future distribution. Yet mechanisms for converting accrued fees into a single asset are notoriously problematic and generally not common in DeFi. Specifically, they are often inefficient, vulnerable to value extraction by validators (MEV), or otherwise require interventions by governance or trusted parties.

Here, we outline Fee Flow: an efficient, decentralised, MEV-resistant mechanism for protocols to be able to auction their accrued fees for a single type of asset. 

## Fee Flow Dutch Auction

Let us assume a protocol is accruing fees in a variety of different asset types across a wide variety of markets. Each market has a function that allows anyone to transfer accrued fees from the market to a `FeeFlowController` smart contract inside of `FeeFlow` at a time of their choosing. Being costly to do this, and in the absence of any other incentive to do so, this function is unlikely to be called on a market very often.

The `FeeFlowController` accumulates fees (often implicitly, see below) and periodically auctions them via a Dutch auction. The auction takes place in discrete epochs. Each epoch, the `initPrice` of the auction starts at a factor `priceMultiplier` times the settlement price of the auction in the prior epoch. It then falls linearly over time, tending to zero, over an `epochPeriod`. For example, the auction might start at a factor `priceMultiplier=2` times the settlement price of the prior auction and last an `epochPeriod=100` days. 

At the beginning of an epoch, the `FeeFlowController` holds no fees and has a high price, so is unlikely to settle any time soon. However, as fees accrue on markets, and the auction price falls, there will usually come a time when the auction price is lower than the aggregate value of all accrued fees. The first person to pay the auction price at this point is allowed to claim all assets in the `FeeFlowController`. 

Note that in practice the winning auction bidder will likely monitor the value of accrued fees across markets off chain and only transfer them to the `FeeFlowController` just-in-time; that is, in the same transaction or same block as the pay the winning bid for the auction. Thus the `FeeFlowController` will often not actually hold many, or indeed any, assets. It will instead usually only implicitly hold assets. 

Inevitably, accrued fees in some of the markets will not be desired by bidders. They might not be worth the cost of gas to transfer them, or sell them, in the future. These will simply remain in their respective markets and may or may not be purchased in a later auction. 

## Example

Let us assume that there is a lending protocol accruing fees over 100 different markets. At epoch 0, the `FeeFlowController` initial price is set to 100 USDC, parameterised with `priceMultiplier=2`, and `epochPeriod=1` month. Suppose the lending protocol accumulates, on average, $20 worth of accrued fees per day. 

After five days, there are $100 worth of assets to claim. Each day the auction decreases in price by 100 / 30 USDC. So, after five days, the auction price is 100 - 5 * 100 / 30 = 83.333 USDC. 

Potential bidders monitor the value of accrued fees and the price of the auction carefully. Paying 83.33 USDC for $100 worth of assets might seem like a good deal, but the winning bidder has to account for the cost of gas to transfer all the assets to the `FeeFlowController`, and then to themselves, and then the cost to sell them. Thus, five days might not be enough to let this auction settle, but six or seven days might be. 

Each potential bidder wants to wait as long as they can to let the price of the auction fall, and the accrued fee value rise, in order to maximise their profit. But allowing any extra time after the auction has become profitable risks losing profit to a competing bidder. Thus, in an efficient-market the auction settlement price is predicted to approach the marginal price of profitability of the auction. 

In this regard, the auction is likely to get as close to maximal efficiency as possible. The auction also requires no human or governance intervention. It can run automatically every epoch. Finally, the auction is also MEV-resistant. In fact, MEV searchers are likely to participate in the auction helping to increase its economic efficiency.

## Use cases

Fee Flow is very flexible. It is agnostic to the underlying protocol it accrues fees from, and can convert fees into any kind of token. Popular choices might be ETH, USDC, some kind of LP token, or the broader project’s native token. In the latter case, Fee Flow represents a maximally efficient buy-back mechanism for the project’s native token that does not expose the buy-back to MEV or require intervention from governance or trusted parties. Accumulated purchase tokens inside the `FeeFlowController` can be deposited back into the protocol, deposited into a project’s treasury, redistributed via staking, or burned, depending on the goals of the project [1]. 

## References

[1] 2020. *Stop Burning Tokens – Buyback And Make Instead*. Joel Monegro, Placeholder.vc. https://www.placeholder.vc/blog/2020/9/17/stop-burning-tokens-buyback-and-make-instefad.