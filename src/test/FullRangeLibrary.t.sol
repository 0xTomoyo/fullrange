// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {FullRangePair} from "../FullRangePair.sol";
import {IFullRange} from "../interfaces/IFullRange.sol";
import {FullRangeLibrary} from "../libraries/FullRangeLibrary.sol";
import {PoolAddress} from "../libraries/PoolAddress.sol";
import {TickMath} from "../libraries/TickMath.sol";
import {FACTORY} from "./utils/Constants.sol";

contract MockFullRangeLibrary {
    mapping(address => address) public getPair;

    function getVars(
        IFullRange.PoolKey memory poolKey,
        address pair,
        address factory
    ) external returns (FullRangeLibrary.Vars memory vars) {
        address pool = PoolAddress.computeAddress(factory, poolKey.tokenA, poolKey.tokenB, poolKey.fee);
        getPair[pool] = pair;
        vars = FullRangeLibrary.getVars(poolKey, getPair, factory);
        getPair[pool] = address(0);
    }
}

contract FullRangeLibraryTest is DSTest {
    MockFullRangeLibrary public fullRangeLibrary;

    function setUp() public {
        fullRangeLibrary = new MockFullRangeLibrary();
    }

    function testGetVars() public {
        IUniswapV3Pool pool = IUniswapV3Pool(0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8);
        IFullRange.PoolKey memory poolKey = IFullRange.PoolKey(pool.token0(), pool.token1(), pool.fee());
        (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            ,

        ) = pool.slot0();
        (int24 tickLower, int24 tickUpper) = TickMath.getTicks(
            IUniswapV3Factory(FACTORY).feeAmountTickSpacing(poolKey.fee)
        );
        FullRangePair pair = new FullRangePair();
        FullRangeLibrary.Vars memory vars = fullRangeLibrary.getVars(poolKey, address(pair), FACTORY);

        assertEq(vars.pair, address(pair));
        assertEq(vars.pool, address(pool));
        assertEq(vars.tickLower, tickLower);
        assertEq(vars.tickUpper, tickUpper);
        assertEq(vars.sqrtPriceX96, sqrtPriceX96);
        assertEq(vars.tick, tick);
        assertEq(vars.observationIndex, observationIndex);
        assertEq(vars.observationCardinality, observationCardinality);
        assertEq(vars.observationCardinalityNext, observationCardinalityNext);
    }

    function testSortParams() public {
        address tokenA = address(0);
        address tokenB = address(0);
        IFullRange.PoolKey memory poolKey = IFullRange.PoolKey(tokenA, tokenB, 3000);
        FullRangeLibrary.sortParams(poolKey);
        assertEq(poolKey.tokenA, tokenA);
        assertEq(poolKey.tokenB, tokenB);

        tokenA = address(0);
        tokenB = address(1);
        poolKey = IFullRange.PoolKey(tokenA, tokenB, 3000);
        FullRangeLibrary.sortParams(poolKey);
        assertEq(poolKey.tokenA, tokenA);
        assertEq(poolKey.tokenB, tokenB);

        tokenA = address(1);
        tokenB = address(0);
        poolKey = IFullRange.PoolKey(tokenA, tokenB, 3000);
        FullRangeLibrary.sortParams(poolKey);
        assertEq(poolKey.tokenA, tokenB);
        assertEq(poolKey.tokenB, tokenA);
    }

    function testSortParams(address tokenA, address tokenB) public {
        IFullRange.PoolKey memory poolKey = IFullRange.PoolKey(tokenA, tokenB, 3000);
        FullRangeLibrary.sortParams(poolKey);
        assertTrue((poolKey.tokenA < poolKey.tokenB) || (tokenA == tokenB));
    }

    function testSortParams(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) public {
        IFullRange.PoolKey memory poolKey = IFullRange.PoolKey(tokenA, tokenB, 3000);
        (
            uint256 newAmountADesired,
            uint256 newAmountBDesired,
            uint256 newAmountAMin,
            uint256 newAmountBMin
        ) = FullRangeLibrary.sortParams(poolKey, amountADesired, amountBDesired, amountAMin, amountBMin);
        if (tokenA != poolKey.tokenA) {
            assertEq(newAmountADesired, amountBDesired);
            assertEq(newAmountBDesired, amountADesired);
            assertEq(newAmountAMin, amountBMin);
            assertEq(newAmountBMin, amountAMin);
        } else {
            assertEq(newAmountADesired, amountADesired);
            assertEq(newAmountBDesired, amountBDesired);
            assertEq(newAmountAMin, amountAMin);
            assertEq(newAmountBMin, amountBMin);
        }
        assertTrue((poolKey.tokenA < poolKey.tokenB) || (tokenA == tokenB));
    }

    function testSortParams(
        address tokenA,
        address tokenB,
        uint256 amountAMin,
        uint256 amountBMin
    ) public {
        IFullRange.PoolKey memory poolKey = IFullRange.PoolKey(tokenA, tokenB, 3000);
        (uint256 newAmountAMin, uint256 newAmountBMin) = FullRangeLibrary.sortParams(poolKey, amountAMin, amountBMin);
        if (tokenA != poolKey.tokenA) {
            assertEq(newAmountAMin, amountBMin);
            assertEq(newAmountBMin, amountAMin);
        } else {
            assertEq(newAmountAMin, amountAMin);
            assertEq(newAmountBMin, amountBMin);
        }
        assertTrue((poolKey.tokenA < poolKey.tokenB) || (tokenA == tokenB));
    }
}
