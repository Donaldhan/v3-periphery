// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity =0.7.6;
pragma abicoder v2;

import '@uniswap/v3-core/contracts/libraries/SafeCast.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';

import './interfaces/ISwapRouter.sol';
import './base/PeripheryImmutableState.sol';
import './base/PeripheryValidation.sol';
import './base/PeripheryPaymentsWithFee.sol';
import './base/Multicall.sol';
import './base/SelfPermit.sol';
import './libraries/Path.sol';
import './libraries/PoolAddress.sol';
import './libraries/CallbackValidation.sol';
import './interfaces/external/IWETH9.sol';

/// @title Uniswap V3 Swap Router 路由
/// @notice Router for stateless execution of swaps against Uniswap V3
contract SwapRouter is
    ISwapRouter,
    PeripheryImmutableState,
    PeripheryValidation,
    PeripheryPaymentsWithFee,
    Multicall,
    SelfPermit
{
    using Path for bytes;
    using SafeCast for uint256;

    /// @dev Used as the placeholder value for amountInCached, because the computed amount in for an exact output swap
    /// can never actually be this value 输入数量最大值
    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

    /// @dev Transient storage variable used for returning the computed amount in for an exact output swap. 
    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

    constructor(address _factory, address _WETH9) PeripheryImmutableState(_factory, _WETH9) {}

    /// @dev Returns the pool for the given token pair and fee. The pool contract may or may not exist. 获取交易池地址
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) private view returns (IUniswapV3Pool) {
        return IUniswapV3Pool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(tokenA, tokenB, fee)));
    }
    //swap 回调数据
    struct SwapCallbackData {
        bytes path; //路径
        address payer; //支付者
    }

    /// @inheritdoc IUniswapV3SwapCallback swap回调
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata _data
    ) external override {
        require(amount0Delta > 0 || amount1Delta > 0); // swaps entirely within 0-liquidity regions are not supported
        //解析回调数据
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        //从回调data中解析出一个交易池信息
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();
        //验证swap回调
        CallbackValidation.verifyCallback(factory, tokenIn, tokenOut, fee);
        //
        (bool isExactInput, uint256 amountToPay) =
            amount0Delta > 0
                ? (tokenIn < tokenOut, uint256(amount0Delta))
                : (tokenOut < tokenIn, uint256(amount1Delta));
        if (isExactInput) {//swap input 操作，添加流动性
            pay(tokenIn, data.payer, msg.sender, amountToPay);
        } else {
            // either initiate the next swap or pay
            if (data.path.hasMultiplePools()) {//路径中包含多个交易池
               //跳过token
                data.path = data.path.skipToken();
                exactOutputInternal(amountToPay, msg.sender, 0, data);
            } else {
                amountInCached = amountToPay;
                tokenIn = tokenOut; // swap in/out because exact output swaps are reversed
                pay(tokenIn, data.payer, msg.sender, amountToPay);
            }
        }
    }
    // allow swapping to the router address with address 0 接收者允许swap接收者为路由地址，主要考虑针对swap的token0，token1，存在交易池时的情况
    //多路径的的情况编码为：token0+fee01+token1+fee12+token2+fee23+token3+fee34+token4+..., 这种是针对swap是如果没有对应的交易对pair，则从不同的
    // 交易池进行swap， 比如使用token0，想swap token3，整个swap的路径为（token0+fee01+token1，token1+fee12+token2，token2+fee23+token3），使用token0从
    // pool01中swap出token1，使用swap出的token1从pool12中swap出token2， 使用swap出的token2从pool23中swap出token3；
    /// @dev Performs a single exact input swap  执行单个swap
    /// 此处swap的时候，如果不存在可以通过uniswapV3SwapCallback回调继续沿路径进行swap，直到swap处理想要的token
    function exactInputInternal(
        uint256 amountIn,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountOut) {
        // allow swapping to the router address with address 0 接收者允许swap接收者为路由地址，主要考虑针对swap的token0，token1，不存在交易池时的情况
        //多路径的的情况编码为：token0+fee01+token1+fee12+token2+fee23+token3+fee34+token4+..., 这种是针对swap是如果没有对应的交易对pair，则从不同的
        // 交易池进行swap， 比如使用token0，想swap token3，整个swap的路径为（token0+fee01+token1，token1+fee12+token2，token2+fee23+token3），使用token0从
        // pool01中swap出token1，使用swap出的token1从pool12中swap出token2， 使用swap出的token2从pool23中swap出token3；
        if (recipient == address(0)) recipient = address(this);
        //第一个交易池
        (address tokenIn, address tokenOut, uint24 fee) = data.path.decodeFirstPool();

        bool zeroForOne = tokenIn < tokenOut;
        //从交易池使用tokenIn，swap处理tokenOut
        (int256 amount0, int256 amount1) =
            getPool(tokenIn, tokenOut, fee).swap(
                recipient,
                zeroForOne,
                amountIn.toInt256(),
                sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );

        return uint256(-(zeroForOne ? amount1 : amount0));
    }

    /// @inheritdoc ISwapRouter 执行单个swap
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        amountOut = exactInputInternal(
            params.amountIn,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({path: abi.encodePacked(params.tokenIn, params.fee, params.tokenOut), payer: msg.sender})
        );
        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    /// @inheritdoc ISwapRouter 执行带路径的swap
    function exactInput(ExactInputParams memory params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 amountOut)
    {
        address payer = msg.sender; // msg.sender pays for the first hop

        while (true) {
            //路径中是否有多个交易池
            bool hasMultiplePools = params.path.hasMultiplePools();

            // the outputs of prior swaps become the inputs to subsequent ones 执行内部swap
            params.amountIn = exactInputInternal(
                params.amountIn,
                hasMultiplePools ? address(this) : params.recipient, // for intermediate swaps, this contract custodies
                0,
                SwapCallbackData({
                    path: params.path.getFirstPool(), // only the first pool in the path is necessary
                    payer: payer
                })
            );

            // decide whether to continue or terminate
            if (hasMultiplePools) {//路径中存在多个交易池
                payer = address(this); // at this point, the caller has paid
                params.path = params.path.skipToken();
            } else {//单个直接结束
                amountOut = params.amountIn;
                break;
            }
        }

        require(amountOut >= params.amountOutMinimum, 'Too little received');
    }

    /// @dev Performs a single exact output swap 执行内部swap评估操作
    function exactOutputInternal(
        uint256 amountOut,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) private returns (uint256 amountIn) {
         // allow swapping to the router address with address 0 接收者允许swap接收者为路由地址，主要考虑针对swap的token0，token1，不存在交易池时的情况
        //多路径的的情况编码为：token0+fee01+token1+fee12+token2+fee23+token3+fee34+token4+..., 这种是针对swap是如果没有对应的交易对pair，则从不同的
        // 交易池进行swap， 比如使用token0，想swap token3，整个swap的路径为（token0+fee01+token1，token1+fee12+token2，token2+fee23+token3），使用token0从
        // pool01中swap出token1，使用swap出的token1从pool12中swap出token2， 使用swap出的token2从pool23中swap出token3；
        if (recipient == address(0)) recipient = address(this);
        
        (address tokenOut, address tokenIn, uint24 fee) = data.path.decodeFirstPool();

        bool zeroForOne = tokenIn < tokenOut;
        //swap
        (int256 amount0Delta, int256 amount1Delta) =
            getPool(tokenIn, tokenOut, fee).swap(
                recipient,
                zeroForOne,
                -amountOut.toInt256(),
                sqrtPriceLimitX96 == 0
                    ? (zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1)
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );

        uint256 amountOutReceived;
        (amountIn, amountOutReceived) = zeroForOne
            ? (uint256(amount0Delta), uint256(-amount1Delta))
            : (uint256(amount1Delta), uint256(-amount0Delta));
        // it's technically possible to not receive the full output amount,
        // so if no price limit has been specified, require this possibility away
        if (sqrtPriceLimitX96 == 0) require(amountOutReceived == amountOut);
    }

    /// @inheritdoc ISwapRouter  执行单个swap评估操作
    function exactOutputSingle(ExactOutputSingleParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 amountIn)
    {
        // avoid an SLOAD by using the swap return data
        amountIn = exactOutputInternal(
            params.amountOut,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({path: abi.encodePacked(params.tokenOut, params.fee, params.tokenIn), payer: msg.sender})
        );

        require(amountIn <= params.amountInMaximum, 'Too much requested');
        // has to be reset even though we don't use it in the single hop case
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }

    /// @inheritdoc ISwapRouter 根据路径执行swap out评估，置换出tokenOut，需要输入的tokenIn数量
    function exactOutput(ExactOutputParams calldata params)
        external
        payable
        override
        checkDeadline(params.deadline)
        returns (uint256 amountIn)
    {
        // it's okay that the payer is fixed to msg.sender here, as they're only paying for the "final" exact output
        // swap, which happens first, and subsequent swaps are paid for within nested callback frames
        exactOutputInternal(
            params.amountOut,
            params.recipient,
            0,
            SwapCallbackData({path: params.path, payer: msg.sender})
        );

        amountIn = amountInCached;
        require(amountIn <= params.amountInMaximum, 'Too much requested');
        amountInCached = DEFAULT_AMOUNT_IN_CACHED;
    }
}
