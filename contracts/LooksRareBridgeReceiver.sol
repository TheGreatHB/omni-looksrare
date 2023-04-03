// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ILooksRareBridgeReceiver.sol";
import "./bases/LooksRareBridgeReceiverAbs.sol";

contract LooksRareBridgeReceiverV1 is LooksRareBridgeReceiverV1Abs {
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
