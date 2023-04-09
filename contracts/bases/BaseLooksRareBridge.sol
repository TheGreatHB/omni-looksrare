// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IBaseLooksRareBridge.sol";

contract BaseLooksRareBridge is Ownable, IBaseLooksRareBridge {
    using SafeERC20 for IERC20;
    using Address for address;

    address public immutable stargateRouter;
    IOneInchAggregationRouterV5 public immutable oneInchRouter;

    uint256 public swapGasLimit;

    constructor(address _stargateRouter, address _oneInchRouter, uint256 _swapGasLimit) {
        stargateRouter = _stargateRouter;
        oneInchRouter = IOneInchAggregationRouterV5(_oneInchRouter);

        swapGasLimit = _swapGasLimit;
    }

    receive() external payable {}

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
