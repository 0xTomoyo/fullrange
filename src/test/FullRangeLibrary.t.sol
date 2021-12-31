// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {IFullRange} from "../interfaces/IFullRange.sol";
import {FullRangeLibrary} from "../libraries/FullRangeLibrary.sol";
import {PoolAddress} from "../libraries/PoolAddress.sol";

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
