// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {FixedPoint128} from "@uniswap/v3-core/contracts/libraries/FixedPoint128.sol";
import {FullMath} from "../libraries/FullMath.sol";

contract MockFullMath {
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) external pure returns (uint256 result) {
        return FullMath.mulDiv(a, b, denominator);
    }

    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) external pure returns (uint256 result) {
        return FullMath.mulDivRoundingUp(a, b, denominator);
    }
}

contract FullMathTest is DSTest {
    MockFullMath public fullMath;

    function setUp() public {
        fullMath = new MockFullMath();
    }

    function testMulDiv() public {
        try fullMath.mulDiv(FixedPoint128.Q128, 5, 0) {
            fail();
        } catch {}

        try fullMath.mulDiv(FixedPoint128.Q128, FixedPoint128.Q128, 0) {
            fail();
        } catch {}

        try fullMath.mulDiv(FixedPoint128.Q128, FixedPoint128.Q128, 1) {
            fail();
        } catch {}

        try fullMath.mulDiv(type(uint256).max, type(uint256).max, type(uint256).max - 1) {
            fail();
        } catch {}

        assertEq(FullMath.mulDiv(type(uint256).max, type(uint256).max, type(uint256).max), type(uint256).max);

        assertEq(
            FullMath.mulDiv(FixedPoint128.Q128, (50 * FixedPoint128.Q128) / 100, (150 * FixedPoint128.Q128) / 100),
            FixedPoint128.Q128 / 3
        );

        assertEq(
            FullMath.mulDiv(FixedPoint128.Q128, 35 * FixedPoint128.Q128, 8 * FixedPoint128.Q128),
            (4375 * FixedPoint128.Q128) / 1000
        );

        assertEq(
            FullMath.mulDiv(FixedPoint128.Q128, 1000 * FixedPoint128.Q128, 3000 * FixedPoint128.Q128),
            FixedPoint128.Q128 / 3
        );
    }

    function testMulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) public {
        if (denominator == 0) return;
        unchecked {
            uint256 c = a * b;
            if (c / a != b) return;
        }
        assertEq(FullMath.mulDiv(a, b, denominator), (a * b) / denominator);
    }

    function testMulDivRoundingUp() public {
        try fullMath.mulDivRoundingUp(FixedPoint128.Q128, 5, 0) {
            fail();
        } catch {}

        try fullMath.mulDivRoundingUp(FixedPoint128.Q128, FixedPoint128.Q128, 0) {
            fail();
        } catch {}

        try fullMath.mulDivRoundingUp(FixedPoint128.Q128, FixedPoint128.Q128, 1) {
            fail();
        } catch {}

        try fullMath.mulDivRoundingUp(type(uint256).max, type(uint256).max, type(uint256).max - 1) {
            fail();
        } catch {}

        try
            fullMath.mulDivRoundingUp(
                535006138814359,
                432862656469423142931042426214547535783388063929571229938474969,
                2
            )
        {
            fail();
        } catch {}

        try
            fullMath.mulDivRoundingUp(
                115792089237316195423570985008687907853269984659341747863450311749907997002549,
                115792089237316195423570985008687907853269984659341747863450311749907997002550,
                115792089237316195423570985008687907853269984653042931687443039491902864365164
            )
        {
            fail();
        } catch {}

        assertEq(FullMath.mulDivRoundingUp(type(uint256).max, type(uint256).max, type(uint256).max), type(uint256).max);

        assertEq(
            FullMath.mulDivRoundingUp(
                FixedPoint128.Q128,
                (50 * FixedPoint128.Q128) / 100,
                (150 * FixedPoint128.Q128) / 100
            ),
            (FixedPoint128.Q128 / 3) + 1
        );

        assertEq(
            FullMath.mulDivRoundingUp(FixedPoint128.Q128, 35 * FixedPoint128.Q128, 8 * FixedPoint128.Q128),
            (4375 * FixedPoint128.Q128) / 1000
        );

        assertEq(
            FullMath.mulDivRoundingUp(FixedPoint128.Q128, 1000 * FixedPoint128.Q128, 3000 * FixedPoint128.Q128),
            (FixedPoint128.Q128 / 3) + 1
        );
    }

    function testMulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) public {
        if (denominator == 0) return;
        unchecked {
            uint256 c = a * b;
            if (c / a != b) return;
        }
        uint256 result = (a * b) / denominator;
        unchecked {
            if (mulmod(a, b, denominator) > 0) {
                if (result == type(uint256).max) return;
                result++;
            }
        }
        uint256 mulDivRoundingUp = FullMath.mulDivRoundingUp(a, b, denominator);
        assertEq(mulDivRoundingUp, result);
        assertGe(mulDivRoundingUp, FullMath.mulDiv(a, b, denominator));
    }
}
