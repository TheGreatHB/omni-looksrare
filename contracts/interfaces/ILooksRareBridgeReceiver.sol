// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IBaseLooksRareBridge.sol";

error FunctionForOnlyCallstaticUsage();
error InvalidStargateRouter();

interface ILooksRareBridgeReceiver is IBaseLooksRareBridge {
    event SetLooksRareAggregator(ILooksRareAggregator newAddress);
    event SetLooksRareAggregatorWithERC20(IERC20EnabledLooksRareAggregator newAddress);

    // event ReceiveMsgForLooksRareExecution();

    function looksRareAggregator() external view returns (ILooksRareAggregator);

    function looksRareAggregatorWithERC20() external view returns (IERC20EnabledLooksRareAggregator);

    function encodeLooksRareExecutionData(
        TokenTransfer[] calldata tokenTransfers,
        TradeData[] calldata tradeData,
        address recipient,
        bool isAtomicPurchase
    ) external pure returns (bytes memory);

    function encodePayload(
        address refundAddress,
        TokenSwapParam[] calldata swapData,
        bool isAtomicSwap,
        bool buyNFTsInSwapFailure,
        bytes calldata looksRareExecutionData
    ) external pure returns (bytes memory);

    function estimateGas(
        bytes calldata swapETHtoTokenPayload,
        uint16 _chainId,
        bytes calldata _srcAddress,
        uint256 _nonce,
        address token,
        uint256 amountLD,
        bytes calldata payload
    ) external payable returns (uint256 gasUsed);

    function sgReceive(
        uint16, //srcChainId
        bytes calldata, //srcBridgeAddress
        uint256, //nonce
        address token, //tokenReceivedViaSTG
        uint256, //amountOfTokenReceivedViaSTG
        bytes calldata payload //payload in stargateRouter.swap
    ) external;
}
