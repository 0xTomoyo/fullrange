// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {PoolAddress} from "./libraries/PoolAddress.sol";
import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";
import {FullRangeDescriptor} from "./libraries/FullRangeDescriptor.sol";
import {FullRangePair} from "./FullRangePair.sol";

contract FullRange {
    address public immutable factory;

    address public immutable weth;

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

    struct AddLiquidityVars {
        address pair;
        address pool;
        int24 tickLower;
        int24 tickUpper;
    }

    function sortAddLiquidityParams(AddLiquidityParams memory params) internal pure {
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
        sortAddLiquidityParams(params);
        (address pair, address pool) = createPair(params.tokenA, params.tokenB, params.fee);
        int24 tickLower;
        int24 tickUpper;
        (liquidity, amount0, amount1, tickLower, tickUpper) = _addLiquidity(params, pool, msg.sender);
        shares = _mint(pair, pool, params.to, liquidity, tickLower, tickUpper);
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

    function _burn(
        address pair,
        address pool,
        address from,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper
    ) internal returns (uint256 shares) {
        (uint128 totalLiquidity, , , , ) = IUniswapV3Pool(pool).positions(
            keccak256(abi.encodePacked(address(this), tickLower, tickUpper))
        );
        shares = (liquidity * FullRangePair(pair).totalSupply()) / totalLiquidity;
        FullRangePair(pair).burn(from, shares);
    }

    function _burnShares(
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
        // TODO: SAFECAST
        liquidity = uint128((shares * totalLiquidity) / FullRangePair(pair).totalSupply());
        FullRangePair(pair).burn(from, shares);
    }

    // removeLiquidity and removeLiquidityShares

    // TODO: Mint callback fn
    function _addLiquidity(
        AddLiquidityParams memory params,
        address pool,
        address from
    )
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            int24 tickLower,
            int24 tickUpper
        )
    {
        {
            (uint160 sqrtPriceX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
            (tickLower, tickUpper) = TickMath.getTicks(IUniswapV3Factory(factory).feeAmountTickSpacing(params.fee));
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

    function constructPairSymbol(address pair) external view returns (string memory) {
        return FullRangeDescriptor.constructSymbol(getPool[pair]);
    }

    function constructPairName(address pair) external view returns (string memory) {
        return FullRangeDescriptor.constructName(getPool[pair]);
    }
}
