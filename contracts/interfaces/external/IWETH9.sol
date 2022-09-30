// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @title Interface for WETH9
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether 存ETH
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether 提取ETH
    function withdraw(uint256) external;
}
