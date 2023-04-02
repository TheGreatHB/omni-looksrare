// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/ILooksRareIntergrator.sol";

contract LooksRareIntergratorV1 is Ownable, ILooksRareIntergrator {
    using SafeERC20 for IERC20;
    using Address for address;

    address public immutable stargateRouter;
    IOneInchAggregationRouterV5 public oneInchRouter;
    ILooksRareAggregator public looksRareAggregator;
    IERC20EnabledLooksRareAggregator public looksRareAggregatorWithERC20;

    uint256 public swapGasLimit;

    constructor() {
        stargateRouter = 0x8731d54E9D02c286767d56ac03e8037C07e01e98;
        oneInchRouter = IOneInchAggregationRouterV5(0x1111111254EEB25477B68fb85Ed929f73A960582);
        looksRareAggregator = ILooksRareAggregator(0x00000000005228B791a99a61f36A130d50600106);
        looksRareAggregatorWithERC20 = IERC20EnabledLooksRareAggregator(0x0000000000a35231D7706BD1eE827d43245655aB);

        swapGasLimit = 300_000;
    }

    receive() external payable {}

    // ownership functions
    function setLooksRareAggregator(ILooksRareAggregator newAddress) external onlyOwner {
        looksRareAggregator = newAddress;
        emit SetLooksRareAggregator(newAddress);
    }

    function setLooksRareAggregatorWithERC20(IERC20EnabledLooksRareAggregator newAddress) external onlyOwner {
        looksRareAggregatorWithERC20 = newAddress;
        emit SetLooksRareAggregatorWithERC20(newAddress);
    }

    function setOneInchRouter(IOneInchAggregationRouterV5 newAddress) external onlyOwner {
        oneInchRouter = newAddress;
        emit SetOneInchRouter(newAddress);
    }

    /**
     * @dev TheGreatHB
     * I analyzed about 9000 transactions whose selector is one of swap, unoswap, uniswapV3Swap, or clipperSwap. About 75% of them used less than 200_000 gas. and about 15% of them used between 200_000 and 300_000 gas. only 10% used more than 300_000.
     */
    function setOneInchSwapGasLimit(uint256 newGasLimit) external onlyOwner {
        swapGasLimit = newGasLimit;
        emit SetOneInchSwapGasLimit(newGasLimit);
    }

    function _isValidSwapSelector(bytes4 _selector) internal pure virtual returns (bool) {
        return (_selector == IOneInchAggregationRouterV5.swap.selector ||
            _selector == IOneInchAggregationRouterV5.unoswap.selector ||
            _selector == IOneInchAggregationRouterV5.uniswapV3Swap.selector ||
            _selector == IOneInchAggregationRouterV5.clipperSwap.selector);
    }

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

    // don't throw error in case of revert
    function _swapInDstChain(
        TokenSwapParam[] memory swapData,
        bool isAtomic
    ) internal virtual returns (bool failExists) {
        uint256 length = swapData.length;
        for (uint256 i; i < length; i = _inc(i)) {
            if (Address.isContract(swapData[i].tokenIn)) {
                bool approvalSuccess = _forceIncreaseAllowanceWORevert(
                    IERC20(swapData[i].tokenIn),
                    address(oneInchRouter),
                    swapData[i].amountIn
                );
                if (!approvalSuccess) {
                    failExists = true;
                    if (isAtomic) break;
                    continue;
                }
            }
            if (!_isValidSwapSelector(bytes4(swapData[i].data))) {
                failExists = true;
                if (isAtomic) break;
                continue;
            }

            (bool success, ) = address(oneInchRouter).call{
                value: swapData[i].msgValue,
                gas: swapData[i].swapGas == 0 ? swapGasLimit : swapData[i].swapGas
            }(swapData[i].data);
            if (!success) {
                failExists = true;
                if (isAtomic) break;
            }
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

    function estimateGas(
        bytes calldata swapETHtoTokenPayload,
        uint16 _chainId,
        bytes calldata _srcAddress,
        uint256 _nonce,
        address token,
        uint256 amountLD,
        bytes calldata payload
    ) external payable returns (uint256 gasUsed) {
        if (msg.sender != address(0)) revert FunctionForOnlyCallstaticUsage();

        address(oneInchRouter).functionCallWithValue(swapETHtoTokenPayload, msg.value);

        uint256 gasLeft = gasleft();
        _sgReceive(_chainId, _srcAddress, _nonce, token, amountLD, payload);
        return gasleft() - gasLeft;
    }

    function sgReceive(
        uint16 _chainId, //srcChainId
        bytes calldata _srcAddress, //srcBridgeAddress
        uint256 _nonce, //nonce
        address token, //tokenReceivedViaSTG
        uint256 amountLD, //amountOfTokenReceivedViaSTG
        bytes calldata payload //payload in stargateRouter.swap
    ) external virtual {
        if (msg.sender != stargateRouter) revert InvalidStargateRouter();
        _sgReceive(_chainId, _srcAddress, _nonce, token, amountLD, payload);
    }

    function _sgReceive(
        uint16, //srcChainId
        bytes calldata, //srcBridgeAddress
        uint256, //nonce
        address token, //tokenReceivedViaSTG
        uint256, //amountOfTokenReceivedViaSTG
        bytes calldata payload //payload in stargateRouter.swap
    ) internal virtual {
        (
            address refundAddress,
            TokenSwapParam[] memory swapData,
            bool isAtomicSwap,
            bool buyNFTsInSwapFailure,
            bytes memory looksRareExecutionData
        ) = abi.decode(payload, (address, TokenSwapParam[], bool, bool, bytes));

        bool isSwapFailed = _swapInDstChain(swapData, isAtomicSwap);

        if (!isSwapFailed || buyNFTsInSwapFailure) {
            // to avoid revert of decoding, using try catch pattern with an external call of this contract
            try this.decodeLooksRareExecutionData(looksRareExecutionData) returns (
                TokenTransfer[] memory tokenTransfers,
                ILooksRareAggregator.TradeData[] memory tradeData,
                address recipient,
                bool isAtomicPurchase
            ) {
                uint256 length = tokenTransfers.length;
                if (length == 0) {
                    try
                        looksRareAggregator.execute{value: address(this).balance}(
                            tokenTransfers,
                            tradeData,
                            address(this),
                            recipient,
                            isAtomicPurchase
                        )
                    {} catch {
                        // TODO in case of failure. at the moment, just refund all tokens.
                    }
                } else {
                    for (uint256 i; i < length; i = _inc(i)) {
                        address currency = tokenTransfers[i].currency;
                        _forceIncreaseAllowanceWORevert(
                            IERC20(currency),
                            address(looksRareAggregatorWithERC20),
                            IERC20(currency).balanceOf(address(this))
                        );
                    }
                    try
                        looksRareAggregatorWithERC20.execute{value: address(this).balance}(
                            tokenTransfers,
                            tradeData,
                            recipient,
                            isAtomicPurchase
                        )
                    {} catch {
                        // TODO in case of failure. at the moment, just refund all tokens.
                    }

                    for (uint256 i; i < length; i = _inc(i)) {
                        _returnERC20(tokenTransfers[i].currency, refundAddress);
                    }
                }
            } catch {
                // TODO in case of failure. at the moment, just refund all tokens.
            }
        }

        for (uint256 i; i < swapData.length; i = _inc(i)) {
            if (swapData[i].tokenIn != token && Address.isContract(swapData[i].tokenIn))
                _returnERC20(swapData[i].tokenIn, refundAddress);
            if (swapData[i].tokenOut != token && Address.isContract(swapData[i].tokenOut))
                _returnERC20(swapData[i].tokenOut, refundAddress);
        }
        _returnERC20(token, refundAddress);
        _returnETH(refundAddress);

        // emit ReceiveMsgForLooksRareExecution(); //TODO
    }

    function decodeLooksRareExecutionData(
        bytes calldata looksRareExecutionData
    )
        external
        pure
        virtual
        returns (
            TokenTransfer[] memory tokenTransfers,
            ILooksRareAggregator.TradeData[] memory tradeData,
            address recipient,
            bool isAtomicPurchase
        )
    {
        (tokenTransfers, tradeData, recipient, isAtomicPurchase) = abi.decode(
            looksRareExecutionData,
            (TokenTransfer[], ILooksRareAggregator.TradeData[], address, bool)
        );
    }

    function _forceIncreaseAllowance(IERC20 token, address spender, uint256 value) internal virtual {
        uint256 allowance = token.allowance(address(this), spender);
        try token.approve(spender, allowance + value) {} catch {
            token.approve(spender, 0);
            token.approve(spender, allowance + value);
        }
    }

    function _forceIncreaseAllowanceWORevert(
        IERC20 token,
        address spender,
        uint256 value
    ) internal virtual returns (bool success) {
        (bool _success, bytes memory res) = address(token).call(
            abi.encodeWithSelector(IERC20.allowance.selector, address(this), spender)
        );
        if (_success && res.length == 32) {
            uint256 allowance = abi.decode(res, (uint256));

            try token.approve(spender, allowance + value) {
                return true;
            } catch {
                try token.approve(spender, 0) {
                    try token.approve(spender, allowance + value) {
                        return true;
                    } catch {}
                } catch {}
            }
        }
    }

    function _returnERC20(address token, address recipient) internal virtual {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance != 0) IERC20(token).safeTransfer(recipient, balance);
    }

    function _returnETH(address recipient) internal virtual {
        uint256 balance = address(this).balance;
        if (balance != 0) Address.sendValue(payable(recipient), balance);
    }

    function _inc(uint256 i) internal pure returns (uint256) {
        unchecked {
            return i + 1;
        }
    }
}
