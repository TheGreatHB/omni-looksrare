// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ILooksRareBridgeSender.sol";
import "./BaseLooksRareBridge.sol";

abstract contract LooksRareBridgeSenderV1Abs is BaseLooksRareBridge, ILooksRareBridgeSender {
    using SafeERC20 for IERC20;

    // throw error in case of revert
    function _swapInSrcChain(TokenSwapParam[] calldata swapData) internal virtual {
        for (uint256 i; i < swapData.length; i = _inc(i)) {
            if (swapData[i].tokenIn != address(0)) {
                _forceIncreaseAllowance(IERC20(swapData[i].tokenIn), address(oneInchRouter), swapData[i].amountIn);
            }
            if (!_isValidSwapSelector(bytes4(swapData[i].data))) revert InvalidSwapFunction();

            (bool success, ) = address(oneInchRouter).call{
                value: swapData[i].msgValue,
                gas: swapData[i].swapGas == 0 ? swapGasLimit : swapData[i].swapGas
            }(swapData[i].data);
            if (!success) revert SwapFailure();
        }
    }

    function _forceIncreaseAllowance(IERC20 token, address spender, uint256 value) internal virtual {
        uint256 allowance = token.allowance(address(this), spender);
        try token.approve(spender, allowance + value) {} catch {
            token.approve(spender, 0);
            token.approve(spender, allowance + value);
        }
    }

    function lzBuyNFT(
        TokenTransfer[] calldata tokenTransfers,
        TokenSwapParam[] calldata swapData,
        DstSwapAndExecutionParam calldata dstData
    ) external payable virtual {
        for (uint256 i; i < tokenTransfers.length; i = _inc(i)) {
            IERC20(tokenTransfers[i].currency).safeTransferFrom(msg.sender, address(this), tokenTransfers[i].amount);
        }

        _swapInSrcChain(swapData);

        address tokenOut = IStargatePool(
            IStargateFactory(IStargateRouter(stargateRouter).factory()).getPool(dstData.sgSwapParam.srcPoolId)
        ).token();
        uint256 tokenOutAmount = dstData.sgSwapParam.amountOut != 0
            ? dstData.sgSwapParam.amountOut
            : IERC20(tokenOut).balanceOf(address(this));

        _forceIncreaseAllowance(IERC20(tokenOut), stargateRouter, tokenOutAmount);
        IStargateRouter(stargateRouter).swap{value: address(this).balance}(
            dstData.sgSwapParam.dstChainId,
            dstData.sgSwapParam.srcPoolId,
            dstData.sgSwapParam.dstPoolId,
            payable(msg.sender), // refund address
            tokenOutAmount,
            dstData.sgSwapParam.minAmountOut,
            IStargateRouter.lzTxObj(
                dstData.sgSwapParam.dstGasForCall,
                dstData.sgSwapParam.dstNativeAmount,
                abi.encodePacked(dstData.sgSwapParam.dstRefundAddress)
            ),
            abi.encodePacked(dstData.sgSwapParam.dstTokenReceiver), // destination address, which implements a sgReceive() function
            abi.encode(
                dstData.sgSwapParam.dstRefundAddress,
                dstData.dstSwapData,
                dstData.dstIsAtomicSwap,
                dstData.dstBuyNFTsInSwapFailure,
                dstData.dstLooksRareExecutionData
            )
        );

        for (uint256 i; i < tokenTransfers.length; i = _inc(i)) {
            _returnERC20(tokenTransfers[i].currency, msg.sender);
        }
        for (uint256 i; i < swapData.length; i = _inc(i)) {
            if (swapData[i].tokenIn != tokenOut && Address.isContract(swapData[i].tokenIn))
                _returnERC20(swapData[i].tokenIn, msg.sender);
            if (swapData[i].tokenOut != tokenOut && Address.isContract(swapData[i].tokenOut))
                _returnERC20(swapData[i].tokenOut, msg.sender);
        }
        _returnERC20(tokenOut, msg.sender);
        _returnETH(msg.sender);

        // emit SendMsgForLooksRareExecution(); //TODO
    }

    function estimateFee(
        uint16 dstChainId,
        address dstTokenReceiver,
        bytes calldata payload,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address dstRefundAddress
    ) external view virtual returns (uint256) {
        (uint256 fee, ) = IStargateRouter(stargateRouter).quoteLayerZeroFee(
            dstChainId,
            1 /*TYPE_SWAP_REMOTE*/,
            abi.encodePacked(dstTokenReceiver),
            payload,
            IStargateRouter.lzTxObj(dstGasForCall, dstNativeAmount, abi.encodePacked(dstRefundAddress))
        );
        return fee;
    }

    function estimateFee(
        uint16 dstChainId,
        address dstTokenReceiver,
        DstSwapAndExecutionParam calldata dstData,
        uint256 dstGasForCall,
        uint256 dstNativeAmount,
        address dstRefundAddress
    ) external view virtual returns (uint256) {
        (uint256 fee, ) = IStargateRouter(stargateRouter).quoteLayerZeroFee(
            dstChainId,
            1 /*TYPE_SWAP_REMOTE*/,
            abi.encodePacked(dstTokenReceiver),
            abi.encode(
                dstData.sgSwapParam.dstRefundAddress,
                dstData.dstSwapData,
                dstData.dstIsAtomicSwap,
                dstData.dstBuyNFTsInSwapFailure,
                dstData.dstLooksRareExecutionData
            ),
            IStargateRouter.lzTxObj(dstGasForCall, dstNativeAmount, abi.encodePacked(dstRefundAddress))
        );
        return fee;
    }
}