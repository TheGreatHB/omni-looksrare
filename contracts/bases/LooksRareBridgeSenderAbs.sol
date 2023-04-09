// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/ILooksRareBridgeSender.sol";
import "./BaseLooksRareBridge.sol";

abstract contract LooksRareBridgeSenderV1Abs is BaseLooksRareBridge, ILooksRareBridgeSender {
    using SafeERC20 for IERC20;

    /**
     * @notice Calls a swap using the 1inch router. Parameters are entered as an array, allowing for multiple swaps. In case of an error, it reverts.
     * @param swapData details:
     * tokenIn: This is the token before the swap. It is actually transferred. For native tokens, both address(0) and 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE can be used.
     * amountIn: This is the amount of tokenIn.
     * tokenOut: This is the token after the swap. There is no guarantee that it will be the same as the actual swapped token. It is used for the subsequent return of any remaining tokens. For native tokens, both address(0) and 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE can be used.
     * msgValue: This is used when swapping native tokens. Enter the amount to be used for the swap call.
     * swapGas: This is the gasLimit used during the swap. If 0 is entered, the contract's swapGasLimit is used. Most simple swaps do not exceed 300,000 gas.
     * data: This is the msg.data of the swap call. The selector should be one of swap, unoswap, uniswapV3Swap, or clipperSwap.
     */
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

    /**
     * @notice Purchase NFTs on the dstChain.
     * @dev Note msg.value must be a value that includes the fee.
     * @param tokenTransfers : For when ERC20 transfers on the srcChain are needed
     * @param swapData : For when token swaps on the srcChain are needed through the 1inch router
     * @param dstData : Contains the information needed for the transfer.
     * sgSwapParam.dstChainId: The Id of the dstChain. It depends on the value stored in Stargate.
     * sgSwapParam.srcPoolId: The poolId of the srcChain token. It depends on the value stored in Stargate.
     * sgSwapParam.dstPoolId: The poolId of the dstChain token. It depends on the value stored in Stargate.
     * sgSwapParam.amountOut: The transfer amount of the srcChain token. The remaining amount will be returned to msg.sender.
     * sgSwapParam.minAmountOut: The minimum transfer amount of the srcChain token. If the transfer amount reflecting the Stargate fee is less than minAmountOut, it reverts.
     * sgSwapParam.dstGasForCall: The amount of gas needed for the sgReceive call on the dstChain. The fee is proportional to this value, so an appropriate value must be entered.
     * sgSwapParam.dstNativeAmount: Used when you want to airdrop the native token of the dstChain to the dstRefundAddress.
     * sgSwapParam.dstRefundAddress: The address to receive the NFTs and remaining tokens on the dstChain.
     * sgSwapParam.dstTokenReceiver: The LooksRareBridgeReceiver address on the dstChain.
     * dstSwapData: If swaps are needed on the dstChain, this contains the information.
     * dstIsAtomicSwap: Determining if swaps on the dstChain are atomic.
     * dstBuyNFTsInSwapFailure: Determining whether to attempt NFT purchases on the dstChain even if one or more swaps fail.
     * dstLooksRareExecutionData: The msg.data sent to looksRareAggregator / ERC20EnabledLooksRareAggregator on the dstChain to purchase NFTs. It can be obtained using the encodeLooksRareExecutionData function in the LooksRareBridgeReceiver.
     */
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

    // @notice Estimates the transaction fee required to execute a transaction on the dstChain. The estimated fee is returned as an amount of the srcChain's native token.
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

    // @notice Estimates the transaction fee required to execute a transaction on the dstChain. The estimated fee is returned as an amount of the srcChain's native token.
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
