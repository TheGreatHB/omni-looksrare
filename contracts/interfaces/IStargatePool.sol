// SPDX-License-Identifier: BUSL-1.1
pragma solidity >0.7.6;

interface IStargatePool {
    function poolId() external view returns (uint256);

    function token() external view returns (address);
}
