// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStargateFactory.sol";
import "./IStargatePool.sol";
import "./IBaseOmniLooksRare.sol";

interface IOmniLooksRareSender is IBaseOmniLooksRare {
    // event SendMsgForLooksRareExecution();

    function omniExecute(
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
}
