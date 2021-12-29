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
        uint32 secondsAgo;
        int24 maxTickDeviation;
    }

    Oracle public oracle;

    mapping(address => address) public getPool;

    mapping(address => address) public getPair;

    constructor(address _factory, address _weth) {
        factory = _factory;
        weth = _weth;
    }

    struct MintCallbackData {
        address payer;
        address token0;
        address token1;
        uint24 fee;
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

    function sortParams(AddLiquidityParams memory params) internal pure {
        if (params.tokenA > params.tokenB)
            (
                params.tokenA,
                params.tokenB,
                params.amountADesired,
                params.amountBDesired,
                params.amountAMin,
                params.amountBMin
            ) = (
                params.tokenB,
                params.tokenA,
                params.amountBDesired,
                params.amountADesired,
                params.amountBMin,
                params.amountAMin
            );
    }

    function addLiquidity(AddLiquidityParams memory params)
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            uint256 shares
        )
    {
        sortParams(params);
        (address pair, address pool) = createPair(params.tokenA, params.tokenB, params.fee);
        (int24 tickLower, int24 tickUpper) = TickMath.getTicks(
            IUniswapV3Factory(factory).feeAmountTickSpacing(params.fee)
        );
        (liquidity, amount0, amount1) = _addLiquidity(params, pool, msg.sender, tickLower, tickUpper);
        shares = _mint(pair, pool, params.to, liquidity, tickLower, tickUpper);
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
    ) external {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        address pool = PoolAddress.computeAddress(factory, tokenA, tokenB, fee);
        require(canCollect(pool), "Cannot collect");
        (int24 tickLower, int24 tickUpper) = TickMath.getTicks(IUniswapV3Factory(factory).feeAmountTickSpacing(fee));
        IUniswapV3Pool(pool).burn(tickLower, tickUpper, 0);
        uint128 liquidity;
        {
            (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
            (, , , uint256 tokensOwed0, uint256 tokensOwed1) = IUniswapV3Pool(pool).positions(
                keccak256(abi.encodePacked(address(this), tickLower, tickUpper))
            );
            (liquidity, tokensOwed0, tokensOwed1) = LiquidityAmounts.getLiquidityAmountsForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                tokensOwed0,
                tokensOwed1
            );
            (tokensOwed0, tokensOwed1) = IUniswapV3Pool(pool).collect(
                address(this),
                tickLower,
                tickUpper,
                uint128(tokensOwed0),
                uint128(tokensOwed0)
            );
        }
        IUniswapV3Pool(pool).mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(MintCallbackData(address(this), tokenA, tokenB, fee))
        );
    }

    function canCollect(address pool) public view returns (bool) {
        Oracle memory _oracle = oracle;
        int24 twap = OracleLibrary.consult(pool, _oracle.secondsAgo);
        (, int24 tick, , , , , ) = IUniswapV3Pool(pool).slot0();
        if ((tick > twap ? tick - twap : twap - tick) > _oracle.maxTickDeviation) {
            return false;
        }
        return true;
    }

    function _mint(
        address pair,
        address pool,
        address to,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) internal returns (uint256 shares) {
        uint256 totalSupply = FullRangePair(pair).totalSupply();
        (uint128 totalLiquidity, , , , ) = IUniswapV3Pool(pool).positions(
            keccak256(abi.encodePacked(address(this), tickLower, tickUpper))
        );
        if (totalSupply == 0 || totalLiquidity == 0) {
            shares = liquidity;
        } else {
            shares = (liquidity * totalSupply) / totalLiquidity;
        }
        FullRangePair(pair).mint(to, shares);
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

    // TODO: Mint callback fn
    function _addLiquidity(
        AddLiquidityParams memory params,
        address pool,
        address from,
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
            (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                params.amountADesired,
                params.amountBDesired
            );
        }
        (amount0, amount1) = IUniswapV3Pool(pool).mint(
            address(this),
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(MintCallbackData(from, params.tokenA, params.tokenB, params.fee))
        );
        require(amount0 >= params.amountAMin && amount1 >= params.amountBMin, "Price slippage check");
    }

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
