// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

/// @title Multicall interface 方法调用接口
/// @notice Enables calling multiple methods in a single call to the contract 在一个合约方法调用中，调用多个方法
interface IMulticall {
    /// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed 
    /// 调用多个方法，并返回结果过
    /// @dev The `msg.value` should not be trusted for any method callable from multicall.  `msg.value`为不可信任值
    /// @param data The encoded function data for each of the calls to make to this contract  方法调用数据
    /// @return results The results from each of the calls passed in via data
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
