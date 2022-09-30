// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Immutable state Periphery不可变状态
/// @notice Functions that return immutable state of the router
interface IPeripheryImmutableState {
    /// @return Returns the address of the Uniswap V3 factory v3工厂
    function factory() external view returns (address);

    /// @return Returns the address of WETH9  WETH9地址
    function WETH9() external view returns (address);
}
