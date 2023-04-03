// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStargateRouter.sol";
import "./IOneInchAggregator.sol";
import {TokenTransfer, TradeData, ILooksRareAggregator, IERC20EnabledLooksRareAggregator} from "./ILooksRareAggregator.sol";

error InvalidSwapFunction();
error SwapFailure();

interface IBaseLooksRareBridge {
    event SetOneInchRouter(IOneInchAggregationRouterV5 newAddress);
    event SetOneInchSwapGasLimit(uint256 newGasLimit);

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

    function swapGasLimit() external view returns (uint256);
}
