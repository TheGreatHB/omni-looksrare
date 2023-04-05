# LooksRareBridge

LooksRareBridge is an EVM smart contract application that allows users to buy NFTs from LooksRare on the Ethereum mainnet using assets on a source chain (srcChain). The application uses Stargate dapp from LayerZero to facilitate cross-chain transactions and supports both ERC-721 and ERC-1155 NFT standards.

## Features

1. Utilizes Stargate for cross-chain transactions and 1inch for token swaps if needed.
2. Requires only one transaction on srcChain.
3. Supports both ERC-721 and ERC-1155 NFTs.
4. Allows multiple NFT purchases at once through LooksRare.
5. Supports buying NFTs using various tokens like ETH, WETH, USDC, USDT, and LOOKS.
6. Handles errors and reverts on both srcChain and dstChain.

## How it works

1. User sends a single transaction on srcChain.
2. Stargate relayer exchanges tokens and purchases NFTs as needed according to the given data.
3. NFTs are sent to the target wallet on dstChain.

## Error Handling

1. If an error occurs on srcChain (e.g., swap slippage is above the set value or incorrect data is entered), the transfer fails.
2. If there is no error on srcChain but an error occurs on dstChain, the handling depends on the type of error:
   - For most revert errors, the parameter token sent via Stargate is sent to the destination wallet on dstChain.
   - If there is an error in the swap, the same parameter token is returned or the swapped tokens may be returned depending on the given conditions.
   - When purchasing multiple NFTs on LooksRare, if only some of them are executed, the remaining balance is sent to the destination wallet along with the successfully purchased NFTs or sent without purchasing all NFTs, depending on the given conditions.
3. When sending transactions on srcChain and purchasing and receiving NFTs on dstChain, any remaining balance (native token and ERC20 used) is returned to the refund wallet of each chain.

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Author

- [TheGreatHB](https://twitter.com/TheGreatHB_/)
