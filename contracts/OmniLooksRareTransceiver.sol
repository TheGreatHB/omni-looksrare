// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./bases/OmniLooksRareSenderAbs.sol";
import "./bases/OmniLooksRareReceiverAbs.sol";

contract OmniLooksRareTransceiverV1 is OmniLooksRareSenderV1Abs, OmniLooksRareReceiverV1Abs {
    constructor(
        address _stargateRouter,
        address _oneInchRouter,
        uint256 _swapGasLimit,
        address _looksRareAggregator,
        address _looksRareAggregatorWithERC20
    )
        BaseOmniLooksRare(_stargateRouter, _oneInchRouter, _swapGasLimit)
        OmniLooksRareReceiverV1Abs(_looksRareAggregator, _looksRareAggregatorWithERC20)
    {}
}
