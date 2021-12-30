// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {PoolAddress} from "./libraries/PoolAddress.sol";
import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";
import {OracleLibrary} from "./libraries/OracleLibrary.sol";
import {FullRangePair} from "./FullRangePair.sol";

contract FullRange {
    address public immutable factory;

    address public immutable weth;

    struct Oracle {
        int24 maxTickDeviation;
        uint32 secondsAgo;
        uint16 observationCardinality;
    }

    Oracle public oracle;

    mapping(address => address) public getPool;

    mapping(address => address) public getPair;

    constructor(address _factory, address _weth) {
        factory = _factory;
        weth = _weth;

        oracle = Oracle({maxTickDeviation: 100, secondsAgo: 0, observationCardinality: 2});
    }

    struct MintCallbackData {
        PoolAddress.PoolKey poolKey;
        address payer;
    }
    struct AddLiquidityParams {
        address tokenA;
        address tokenB;
        uint24 fee;
        uint256 amountADesired;
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        address to;
    }

    function sortParams(
        PoolAddress.PoolKey memory poolKey,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    )
        internal
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        if (poolKey.token0 > poolKey.token1)
            (poolKey.token0, poolKey.token1, amountADesired, amountBDesired, amountAMin, amountBMin) = (
                poolKey.token1,
                poolKey.token0,
                amountBDesired,
                amountADesired,
                amountBMin,
                amountAMin
            );
    }

    struct LocalVars {
        address pair;
        address pool;
        int24 tickLower;
        int24 tickUpper;
    }

    function addLiquidity(
        PoolAddress.PoolKey memory poolKey,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    )
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            uint256 shares
        )
    {
        {
            (amountADesired, amountBDesired, amountAMin, amountBMin) = sortParams(
                poolKey,
                amountADesired,
                amountBDesired,
                amountAMin,
                amountBMin
            );
        }
        LocalVars memory vars;
        (vars.pair, vars.pool) = _createPair(poolKey);
        (vars.tickLower, vars.tickUpper) = TickMath.getTicks(
            IUniswapV3Factory(factory).feeAmountTickSpacing(poolKey.fee)
        );

        (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(vars.pool).slot0();
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(vars.tickLower),
            TickMath.getSqrtRatioAtTick(vars.tickUpper),
            amountADesired,
            amountBDesired
        );
        (amount0, amount1) = _mintLiquidity(poolKey, vars, msg.sender, liquidity);
        require(amount0 >= amountAMin && amount1 >= amountBMin, "Price slippage check");
        shares = _mint(vars, to, liquidity);
    }

    function _createPair(PoolAddress.PoolKey memory poolKey) internal returns (address pair, address pool) {
        pool = IUniswapV3Factory(factory).getPool(poolKey.token0, poolKey.token1, poolKey.fee);
        pair = getPair[pool];
        if (pair == address(0)) {
            require(pool != address(0), "Pool not deployed");
            pair = address(
                new FullRangePair{salt: keccak256(abi.encode(poolKey.token0, poolKey.token1, poolKey.fee))}()
            );
            getPool[pair] = pool;
            getPair[pool] = pair;
        }
    }

    // TODO: Mint callback fn
    function _mintLiquidity(
        PoolAddress.PoolKey memory poolKey,
        LocalVars memory vars,
        address from,
        uint128 liquidity
    ) internal returns (uint256 amount0, uint256 amount1) {
        return
            IUniswapV3Pool(vars.pool).mint(
                address(this),
                vars.tickLower,
                vars.tickUpper,
                liquidity,
                abi.encode(MintCallbackData(poolKey, from))
            );
    }

    struct RemoveLiquidityParams {
        address tokenA;
        address tokenB;
        uint24 fee;
        uint256 shares;
        uint256 amountAMin;
        uint256 amountBMin;
        address to;
    }

    function sortParams(RemoveLiquidityParams memory params) internal pure {
        if (params.tokenA > params.tokenB)
            (params.tokenA, params.tokenB, params.amountAMin, params.amountBMin) = (
                params.tokenB,
                params.tokenA,
                params.amountBMin,
                params.amountAMin
            );
    }

    function removeLiquidity(RemoveLiquidityParams memory params)
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        sortParams(params);
        (address pair, address pool) = PoolAddress.getPair(getPair, factory, params.tokenA, params.tokenB, params.fee);
        (int24 tickLower, int24 tickUpper) = TickMath.getTicks(
            IUniswapV3Factory(factory).feeAmountTickSpacing(params.fee)
        );
        liquidity = _burn(pair, pool, msg.sender, params.shares, tickLower, tickUpper);
        (amount0, amount1) = _removeLiquidity(params, pool, liquidity, tickLower, tickUpper);
    }

    function _removeLiquidity(
        RemoveLiquidityParams memory params,
        address pool,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IUniswapV3Pool(pool).burn(tickLower, tickUpper, liquidity);
        (amount0, amount1) = IUniswapV3Pool(pool).collect(
            params.to,
            tickLower,
            tickUpper,
            uint128(amount0),
            uint128(amount1)
        );
        require(amount0 >= params.amountAMin && amount1 >= params.amountBMin, "Price slippage check");
    }

    function collect(
        address tokenA,
        address tokenB,
        uint24 fee
    )
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        address pool = PoolAddress.computeAddress(factory, tokenA, tokenB, fee);
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = IUniswapV3Pool(pool).slot0();
        require(_canCollect(pool, tick), "Cannot collect");
        (int24 tickLower, int24 tickUpper) = TickMath.getTicks(IUniswapV3Factory(factory).feeAmountTickSpacing(fee));
        (liquidity, amount0, amount1) = _collect(tokenA, tokenB, fee, pool, sqrtPriceX96, tickLower, tickUpper);
    }

    function _collect(
        address token0,
        address token1,
        uint24 fee,
        address pool,
        uint160 sqrtPriceX96,
        int24 tickLower,
        int24 tickUpper
    )
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        {
            IUniswapV3Pool(pool).burn(tickLower, tickUpper, 0);
            (amount0, amount1) = IUniswapV3Pool(pool).collect(
                address(this),
                tickLower,
                tickUpper,
                type(uint128).max,
                type(uint128).max
            );
            (liquidity, amount0, amount1) = LiquidityAmounts.getLiquidityAmountsForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
        }
        (amount0, amount1) = IUniswapV3Pool(pool).mint(address(this), tickLower, tickUpper, liquidity, "");
    }

    function _canCollect(address pool, int24 tick) internal view returns (bool) {
        Oracle memory _oracle = oracle;
        int24 twap = OracleLibrary.consult(pool, _oracle.secondsAgo);
        if ((tick > twap ? tick - twap : twap - tick) > _oracle.maxTickDeviation) {
            return false;
        }
        return true;
    }

    function _mint(
        LocalVars memory vars,
        address to,
        uint128 liquidity
    ) internal returns (uint256 shares) {
        uint256 totalSupply = FullRangePair(vars.pair).totalSupply();
        (uint128 totalLiquidity, , , , ) = IUniswapV3Pool(vars.pool).positions(
            keccak256(abi.encodePacked(address(this), vars.tickLower, vars.tickUpper))
        );
        if (totalSupply == 0 || totalLiquidity == 0) {
            shares = liquidity;
        } else {
            shares = (liquidity * totalSupply) / totalLiquidity;
        }
        FullRangePair(vars.pair).mint(to, shares);
    }

    // function _burn(
    //     address pair,
    //     address pool,
    //     address from,
    //     uint128 liquidity,
    //     int24 tickLower,
    //     int24 tickUpper
    // ) internal returns (uint256 shares) {
    //     (uint128 totalLiquidity, , , , ) = IUniswapV3Pool(pool).positions(
    //         keccak256(abi.encodePacked(address(this), tickLower, tickUpper))
    //     );
    //     shares = (liquidity * FullRangePair(pair).totalSupply()) / totalLiquidity;
    //     FullRangePair(pair).burn(from, shares);
    // }

    function _burn(
        address pair,
        address pool,
        address from,
        uint256 shares,
        int24 tickLower,
        int24 tickUpper
    ) internal returns (uint128 liquidity) {
        (uint128 totalLiquidity, , , , ) = IUniswapV3Pool(pool).positions(
            keccak256(abi.encodePacked(address(this), tickLower, tickUpper))
        );
        uint256 _liquidity = (shares * totalLiquidity) / FullRangePair(pair).totalSupply();
        // SafeCast to uint128
        require(_liquidity <= type(uint128).max);
        liquidity = uint128(_liquidity);
        FullRangePair(pair).burn(from, shares);
    }

    // removeLiquidity and removeLiquidityShares

    // TODO: separate into external and internal
    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) public returns (address pair, address pool) {
        pool = IUniswapV3Factory(factory).getPool(tokenA, tokenB, fee);
        pair = getPair[pool];
        if (pair == address(0)) {
            require(pool != address(0), "Pool not deployed");
            if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
            pair = address(new FullRangePair{salt: keccak256(abi.encode(tokenA, tokenB, fee))}());
            getPool[pair] = pool;
            getPair[pool] = pair;
        }
    }
}
