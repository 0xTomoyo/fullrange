// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {TickMath} from "../libraries/TickMath.sol";

contract MockTickMath {
    function getSqrtRatioAtTick(int24 tick) external pure returns (uint160 sqrtPriceX96) {
        return TickMath.getSqrtRatioAtTick(tick);
    }

    function getTickAtSqrtRatio(uint160 sqrtPriceX96) external pure returns (int24 tick) {
        return TickMath.getTickAtSqrtRatio(sqrtPriceX96);
    }
}

contract TickMathTest is DSTest {
    MockTickMath public tickMath;

    function setUp() public {
        tickMath = new MockTickMath();
    }

    function testGetSqrtRatioAtTick() public {
        try tickMath.getSqrtRatioAtTick(TickMath.MIN_TICK - 1) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "T");
        }

        try tickMath.getSqrtRatioAtTick(TickMath.MAX_TICK + 1) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "T");
        }

        assertEq(tickMath.getSqrtRatioAtTick(TickMath.MIN_TICK), 4295128739);

        assertEq(tickMath.getSqrtRatioAtTick(TickMath.MIN_TICK), TickMath.MIN_SQRT_RATIO);

        assertEq(tickMath.getSqrtRatioAtTick(TickMath.MIN_TICK + 1), 4295343490);

        assertEq(tickMath.getSqrtRatioAtTick(TickMath.MAX_TICK - 1), 1461373636630004318706518188784493106690254656249);

        assertEq(tickMath.getSqrtRatioAtTick(TickMath.MAX_TICK), 1461446703485210103287273052203988822378723970342);

        assertEq(tickMath.getSqrtRatioAtTick(TickMath.MAX_TICK), TickMath.MAX_SQRT_RATIO);
    }

    function testGetSqrtRatioAtTick(int256 tick) public {
        if (tick < TickMath.MIN_TICK || tick > TickMath.MIN_TICK) return;

        uint160 ratio = TickMath.getSqrtRatioAtTick(int24(tick));
        if (tick > (TickMath.MIN_TICK + 1) && tick < (TickMath.MAX_TICK - 1)) {
            assertTrue(
                TickMath.getSqrtRatioAtTick(int24(tick) - 1) < ratio &&
                    ratio < TickMath.getSqrtRatioAtTick(int24(tick) + 1)
            );
        }
        assertTrue(ratio >= TickMath.MIN_SQRT_RATIO);
        assertTrue(ratio <= TickMath.MAX_SQRT_RATIO);
    }

    function testGetTickAtSqrtRatio() public {
        try tickMath.getTickAtSqrtRatio(TickMath.MIN_SQRT_RATIO - 1) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "R");
        }

        try tickMath.getTickAtSqrtRatio(TickMath.MAX_SQRT_RATIO) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "R");
        }

        assertEq(TickMath.getTickAtSqrtRatio(TickMath.MIN_SQRT_RATIO), TickMath.MIN_TICK);

        assertEq(TickMath.getTickAtSqrtRatio(4295343490), TickMath.MIN_TICK + 1);

        assertEq(TickMath.getTickAtSqrtRatio(1461373636630004318706518188784493106690254656249), TickMath.MAX_TICK - 1);

        assertEq(TickMath.getTickAtSqrtRatio(TickMath.MAX_SQRT_RATIO - 1), TickMath.MAX_TICK - 1);
    }

    function testGetTickAtSqrtRatio(uint256 ratio) public {
        if (ratio > type(uint160).max) return;

        int24 tick = TickMath.getTickAtSqrtRatio(uint160(ratio));
        assertTrue(ratio >= TickMath.getSqrtRatioAtTick(tick) && ratio < TickMath.getSqrtRatioAtTick(tick + 1));
        assertTrue(tick >= TickMath.MIN_TICK);
        assertTrue(tick < TickMath.MAX_TICK);
    }
}
