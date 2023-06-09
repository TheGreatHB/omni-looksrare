// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../interfaces/IOmniLooksRareReceiver.sol";
import "./BaseOmniLooksRare.sol";

abstract contract OmniLooksRareReceiverV1Abs is BaseOmniLooksRare, IOmniLooksRareReceiver {
    using SafeERC20 for IERC20;
    using Address for address;

    ILooksRareAggregator public immutable looksRareAggregator;
    IERC20EnabledLooksRareAggregator public immutable looksRareAggregatorWithERC20;

    constructor(address _looksRareAggregator, address _looksRareAggregatorWithERC20) {
        looksRareAggregator = ILooksRareAggregator(_looksRareAggregator);
        looksRareAggregatorWithERC20 = IERC20EnabledLooksRareAggregator(_looksRareAggregatorWithERC20);
    }

    /**
     * @notice Calls a swap using the 1inch router. Parameters are entered as an array, allowing for multiple swaps. In case of an error, it just returns true without reverts.
     * @param swapData details:
     * tokenIn: This is the token before the swap. It is actually transferred. For native tokens, both address(0) and 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE can be used.
     * amountIn: This is the amount of tokenIn.
     * tokenOut: This is the token after the swap. There is no guarantee that it will be the same as the actual swapped token. It is used for the subsequent return of any remaining tokens. For native tokens, both address(0) and 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE can be used.
     * msgValue: This is used when swapping native tokens. Enter the amount to be used for the swap call.
     * swapGas: This is the gasLimit used during the swap. If 0 is entered, the contract's swapGasLimit is used. Most simple swaps do not exceed 300,000 gas.
     * data: This is the msg.data of the swap call. The selector should be one of swap, unoswap, uniswapV3Swap, or clipperSwap.
     */
    function _swapInDstChain(TokenSwapParam[] memory swapData) internal virtual returns (bool failExists) {
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
                    continue;
                }
            }
            if (!_isValidSwapSelector(bytes4(swapData[i].data))) {
                failExists = true;
                continue;
            }

            (bool success, ) = address(oneInchRouter).call{
                value: swapData[i].msgValue,
                gas: swapData[i].swapGas == 0 ? swapGasLimit : swapData[i].swapGas
            }(swapData[i].data);
            if (!success) {
                failExists = true;
            }
        }
    }

    // @notice Returns false if an error occurs instead of reverting during forceIncreaseAllowance.
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

    /**
     * @notice Sends looksRareExecutionData to looksRareAggregator or looksRareAggregatorWithERC20 to attempt to purchase an NFT. In all cases, the NFT and any remaining tokens are sent to refundAddress.
     * @param refundAddress The address that will receive the NFT and any remaining tokens.
     * @param looksRareExecutionData The data that will be sent to looksRareAggregator or looksRareAggregatorWithERC20.
     */
    function _executeLooksRareAggregator(address refundAddress, bytes memory looksRareExecutionData) internal {
        // to avoid revert of decoding, using try catch pattern with an external call of this contract
        try this.decodeLooksRareExecutionData(looksRareExecutionData) returns (
            TokenTransfer[] memory tokenTransfers,
            TradeData[] memory tradeData,
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

        if (isAtomicSwap) {
            try this.swapInDstChain(swapData) {
                _executeLooksRareAggregator(refundAddress, looksRareExecutionData);
            } catch {
                if (buyNFTsInSwapFailure) _executeLooksRareAggregator(refundAddress, looksRareExecutionData);
            }
        } else {
            bool isSwapFailed = _swapInDstChain(swapData);
            if (!isSwapFailed || buyNFTsInSwapFailure) {
                _executeLooksRareAggregator(refundAddress, looksRareExecutionData);
            }
            for (uint256 i; i < swapData.length; i = _inc(i)) {
                if (swapData[i].tokenIn != token && Address.isContract(swapData[i].tokenIn))
                    _returnERC20(swapData[i].tokenIn, refundAddress);
                if (swapData[i].tokenOut != token && Address.isContract(swapData[i].tokenOut))
                    _returnERC20(swapData[i].tokenOut, refundAddress);
            }
        }

        _returnERC20(token, refundAddress);
        _returnETH(refundAddress);

        // emit ReceiveMsgForLooksRareExecution(); //TODO
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

    // @notice This function is identical to _swapInDstChain, but reverts if an error occurs. Only this contract can call this function.
    function swapInDstChain(TokenSwapParam[] calldata swapData) external virtual {
        if (msg.sender != address(this)) revert InvalidCaller();

        uint256 length = swapData.length;
        for (uint256 i; i < length; i = _inc(i)) {
            if (Address.isContract(swapData[i].tokenIn)) {
                _forceIncreaseAllowanceWORevert(
                    IERC20(swapData[i].tokenIn),
                    address(oneInchRouter),
                    swapData[i].amountIn
                );
            }

            if (!_isValidSwapSelector(bytes4(swapData[i].data))) revert InvalidSwapFunction();

            (bool success, ) = address(oneInchRouter).call{
                value: swapData[i].msgValue,
                gas: swapData[i].swapGas == 0 ? swapGasLimit : swapData[i].swapGas
            }(swapData[i].data);
            if (!success) revert SwapFailure();
        }
    }

    /**
     * @notice This function is used to predict the value of the "dstGasForCall" argument and is used in the OmniLooksRareSender contract. The "dstGasForCall" argument is used when calling sgReceive. This function is designed to be called using callStatic method in ethers.js and the caller's address is set to address(0) to prevent abuse. The swapETHtoTokenPayload parameter is the data that will be used to swap ETH for a specific token using 1inch router. This function uses callStatic to swap a large amount of ETH for a specific token and then returns the predicted value of "dstGasForCall". The token that is being swapped for must be specified in the "token" parameter of this function.
     * @param swapETHtoTokenPayload The data that will be used to swap ETH for a specific token using 1inch router.
     * @param _chainId The remote chainId sending the tokens.
     * @param _srcAddress The remote Bridge address
     * @param _nonce The message ordering nonce
     * @param token The token contract on the local chain
     * @param amountLD The qty of local _token contract tokens
     * @param payload The bytes containing the refundAddress, swapData, isAtomicSwap, buyNFTsInSwapFailure, looksRareExecutionData
     * @return gasUsed The predicted value of "dstGasForCall".
     */
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
        return gasLeft - gasleft();
    }

    function decodeLooksRareExecutionData(
        bytes calldata looksRareExecutionData
    )
        external
        pure
        virtual
        returns (
            TokenTransfer[] memory tokenTransfers,
            TradeData[] memory tradeData,
            address recipient,
            bool isAtomicPurchase
        )
    {
        (tokenTransfers, tradeData, recipient, isAtomicPurchase) = abi.decode(
            looksRareExecutionData,
            (TokenTransfer[], TradeData[], address, bool)
        );
    }

    /**
     * @notice This function encodes the looksRareExecutionData that will be sent to looksRareAggregator or looksRareAggregatorWithERC20 to attempt to purchase an NFT.
     * @param tokenTransfers The token transfers that will be performed as part of the purchase.
     * @param tradeData The trade data that will be used to perform the purchase.
     * @param recipient The address that will receive the NFT.
     * @param isAtomicPurchase Whether or not the purchase is atomic.
     * @return The encoded looksRareExecutionData.
     */
    function encodeLooksRareExecutionData(
        TokenTransfer[] calldata tokenTransfers,
        TradeData[] calldata tradeData,
        address recipient,
        bool isAtomicPurchase
    ) external pure returns (bytes memory) {
        return abi.encode(tokenTransfers, tradeData, recipient, isAtomicPurchase);
    }

    /**
     * @notice This function encodes the payload that will be sent to sgReceive. The payload contains the refund address, swap data, and looksRareExecutionData.
     * @param refundAddress The address to receive remaining tokens.
     * @param swapData The data that will be used to perform the swap.
     * @param isAtomicSwap Whether or not the swap is atomic.
     * @param buyNFTsInSwapFailure Determining whether to attempt NFT purchases even if one or more swaps fail.
     * @param looksRareExecutionData The data that will be sent to looksRareAggregator or looksRareAggregatorWithERC20.
     * @return The encoded payload.
     */
    function encodePayload(
        address refundAddress,
        TokenSwapParam[] calldata swapData,
        bool isAtomicSwap,
        bool buyNFTsInSwapFailure,
        bytes calldata looksRareExecutionData
    ) external pure returns (bytes memory) {
        return abi.encode(refundAddress, swapData, isAtomicSwap, buyNFTsInSwapFailure, looksRareExecutionData);
    }
}
