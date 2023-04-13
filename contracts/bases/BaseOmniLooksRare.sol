// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IBaseOmniLooksRare.sol";

contract BaseOmniLooksRare is Ownable, IBaseOmniLooksRare {
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
     * I analyzed around 9,000 transactions with the selector being one of swap, unoswap, uniswapV3Swap, or clipperSwap. Approximately 75% of these transactions used less than 200,000 gas, while about 15% consumed between 200,000 and 300,000 gas. Only 10% of the transactions used more than 300,000 gas.
     */
    function setOneInchSwapGasLimit(uint256 newGasLimit) external onlyOwner {
        swapGasLimit = newGasLimit;
        emit SetOneInchSwapGasLimit(newGasLimit);
    }

    /**
     * This function checks whether the entered selector is valid.
     * @param _selector should be one of swap, unoswap, uniswapV3Swap, or clipperSwap in IOneInchAggregationRouterV5.
     */
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
