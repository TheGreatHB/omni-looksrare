# OmniLooksRareV1 Limitations

## 1. Revert Issue

During the token swap or NFT purchase process on the destination chain, if a revert occurs, **LooksRareBridge V1** sends tokens to the target wallet (refundAddress) instead of storing them for a redo attempt. The reason why we do not provide a "redo" feature in Lookahead Bridge V1 is that we have not yet established a policy to distinguish when a redo is not necessary. Examples of such cases are as follows:

- (i) The desired NFT has already been sold by the time the srcChain asset reaches dstChain via Stargate.
- (ii) The NFT exists when the asset reaches dstChain, but the desired NFT has been sold while waiting for redo due to swap slippage, etc.
- (iii) Waiting for "redo" due to swap slippage, etc., but the relative value of the asset the user wants to purchase with the swap continues to increase and the swap cannot be executed for a long time (or forever).

However, this approach in **LooksRareBridge V1** results in users receiving unwanted intermediary tokens. For example, a user may prefer holding BNB rather than USDC, USDT, or LOOKS. During the purchase process, BNB might be converted into BUSD and sent via Stargate to receive USDC on Ethereum.

## 2. Gas Costs

Using LayerZero requires users to pay the Relayer Fee, which can be quite expensive as LooksRare operates on the Ethereum mainnet. In a test conducted on April 4th, 2023, a user spent approximately $100 in fees while swapping received USDC to ETH, purchasing 3 NFTs, and transferring all NFTs and all tokens (ETH, USDC). The transaction was from BSC chain to Ethereum. `dstGasForCall` was 85,000 and the estimated fee was about 0.26 BNB.

## 3. ETH Transfer Problem

This issue is related to gas costs. Since most NFTs are currently traded in ETH on Ethereum, gas costs could be slightly reduced if ETH is used in Stargate. However, at present, only Arbitrum, Optimism, and Ethereum itself use ETH as a gas token, with SGETH being released. V1 does not support ETH transfer as it is deemed impractical. If this feature becomes necessary, it will be implemented in future updates.
