// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./bases/LooksRareBridgeSenderAbs.sol";
import "./bases/LooksRareBridgeReceiverAbs.sol";

contract LooksRareBridgeTransceiverV1 is LooksRareBridgeSenderV1Abs, LooksRareBridgeReceiverV1Abs {
    constructor(
        address _stargateRouter,
        address _oneInchRouter,
        uint256 _swapGasLimit,
        address _looksRareAggregator,
        address _looksRareAggregatorWithERC20
    )
        BaseLooksRareBridge(_stargateRouter, _oneInchRouter, _swapGasLimit)
        LooksRareBridgeReceiverV1Abs(_looksRareAggregator, _looksRareAggregatorWithERC20)
    {}
}
