// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/ILooksRareBridgeSender.sol";
import "./bases/LooksRareBridgeSenderAbs.sol";

contract LooksRareBridgeSenderV1 is LooksRareBridgeSenderV1Abs {
    constructor(
        address _stargateRouter,
        address _oneInchRouter,
        uint256 _swapGasLimit
    ) BaseLooksRareBridge(_stargateRouter, _oneInchRouter, _swapGasLimit) {}
}
