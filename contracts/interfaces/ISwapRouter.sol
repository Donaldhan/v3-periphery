// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface ISwapRouter is IUniswapV3SwapCallback {
    //swap token输入参数
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;//截止时间
        uint256 amountIn;
        uint256 amountOutMinimum;//最小输出
        uint160 sqrtPriceLimitX96;//当前价格
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token ，使用给定数量的amountIn，尽可能的swap出更多的另一个token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    // 根据path swap token输入参数
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum; //最小输出
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path 使用给定数量的amountIn，尽可能的swap出更多依赖给定path的token
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
    // swap 给定token，需要输入的以外一个token数量
    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum; //限制最大输入
        uint160 sqrtPriceLimitX96; //最大价格限制
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token 在给定token数量amountOut的情况下，需要输入的最小以外一个token数量
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);
    // swap 给定token，需要输入的以外一个token数量
    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;  //限制最大输入
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// 在给定token数量amountOut的情况下和给定path下，需要输入的最小以外一个token数量
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
}
