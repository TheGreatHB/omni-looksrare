// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IOmniLooksRareSender.sol";
import "./bases/OmniLooksRareSenderAbs.sol";

contract OmniLooksRareSenderV1 is OmniLooksRareSenderV1Abs {
    constructor(
        address _stargateRouter,
        address _oneInchRouter,
        uint256 _swapGasLimit
    ) BaseOmniLooksRare(_stargateRouter, _oneInchRouter, _swapGasLimit) {}
}
