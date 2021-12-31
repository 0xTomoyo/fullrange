// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IFullRange} from "../interfaces/IFullRange.sol";
import {PoolAddress} from "./PoolAddress.sol";
import {TickMath} from "./TickMath.sol";

library FullRangeLibrary {
    struct Vars {
        address pair;
        address pool;
        int24 tickLower;
        int24 tickUpper;
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 observationIndex;
        uint16 observationCardinality;
        uint16 observationCardinalityNext;
    }

    function getVars(
        IFullRange.PoolKey memory poolKey,
        mapping(address => address) storage getPair,
        address factory
    ) internal view returns (Vars memory vars) {
        vars.pool = PoolAddress.computeAddress(factory, poolKey.tokenA, poolKey.tokenB, poolKey.fee);
        vars.pair = getPair[vars.pool];
        (vars.tickLower, vars.tickUpper) = TickMath.getTicks(
            IUniswapV3Factory(factory).feeAmountTickSpacing(poolKey.fee)
        );
        (
            vars.sqrtPriceX96,
            vars.tick,
            vars.observationIndex,
            vars.observationCardinality,
            vars.observationCardinalityNext,
            ,

        ) = IUniswapV3Pool(vars.pool).slot0();
    }

    function sortParams(IFullRange.PoolKey memory poolKey) internal pure {
        if (poolKey.tokenA > poolKey.tokenB) {
            (poolKey.tokenA, poolKey.tokenB) = (poolKey.tokenB, poolKey.tokenA);
        }
    }

    function sortParams(
        IFullRange.PoolKey memory poolKey,
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
        if (poolKey.tokenA > poolKey.tokenB) {
            (poolKey.tokenA, poolKey.tokenB) = (poolKey.tokenB, poolKey.tokenA);
            return (amountBDesired, amountADesired, amountBMin, amountAMin);
        }
        return (amountADesired, amountBDesired, amountAMin, amountBMin);
    }

    function sortParams(
        IFullRange.PoolKey memory poolKey,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal pure returns (uint256, uint256) {
        if (poolKey.tokenA > poolKey.tokenB) {
            (poolKey.tokenA, poolKey.tokenB) = (poolKey.tokenB, poolKey.tokenA);
            return (amountBMin, amountAMin);
        }
        return (amountAMin, amountBMin);
    }
}
