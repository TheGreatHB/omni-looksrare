// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStargateFactory.sol";
import "./IStargatePool.sol";
import "./IStargateRouter.sol";
import "./IOneInchAggregator.sol";
import {TokenTransfer, ILooksRareAggregator, IERC20EnabledLooksRareAggregator} from "./ILooksRareAggregator.sol";

interface ILooksRareIntergrator {
    event SetLooksRareAggregator(ILooksRareAggregator newAddress);
    event SetLooksRareAggregatorWithERC20(IERC20EnabledLooksRareAggregator newAddress);
    event SetOneInchRouter(IOneInchAggregationRouterV5 newAddress);
    event SetOneInchSwapGasLimit(uint256 newGasLimit);

    // event SendMsgForLooksRareExecution();
    // event ReceiveMsgForLooksRareExecution();

    struct TokenSwapParam {
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        uint256 msgValue;
        uint256 swapGas;
        bytes data;
    }
    struct StargateSwapParam {
        uint16 dstChainId;
        uint256 srcPoolId;
        uint256 dstPoolId;
        uint256 amountOut;
        uint256 minAmountOut;
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        address dstRefundAddress;
        address dstTokenReceiver;
    }

    struct DstSwapAndExecutionParam {
        StargateSwapParam sgSwapParam;
        TokenSwapParam[] dstSwapData;
        bool dstIsAtomicSwap;
        bool dstBuyNFTsInSwapFailure;
        bytes dstLooksRareExecutionData;
    }

    function stargateRouter() external view returns (address);

    function oneInchRouter() external view returns (IOneInchAggregationRouterV5);

    function looksRareAggregator() external view returns (ILooksRareAggregator);

    function looksRareAggregatorWithERC20() external view returns (IERC20EnabledLooksRareAggregator);

    function swapGasLimit() external view returns (uint256);

    function lzBuyNFT(
        TokenTransfer[] calldata tokenTransfers,
        TokenSwapParam[] calldata swapData,
        DstSwapAndExecutionParam calldata dstData
    ) external payable;

    function estimateFee(
        uint16 dstChainId,
        address dstTokenReceiver,
        bytes calldata payload,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address dstRefundAddress
    ) external view returns (uint256);

    function estimateFee(
        uint16 dstChainId,
        address dstTokenReceiver,
        DstSwapAndExecutionParam calldata dstData,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address dstRefundAddress
    ) external view returns (uint256);

    function sgReceive(
        uint16, //srcChainId
        bytes calldata, //srcBridgeAddress
        uint256, //nonce
        address token, //tokenReceivedViaSTG
        uint256, //amountOfTokenReceivedViaSTG
        bytes calldata payload //payload in stargateRouter.swap
    ) external;
}
