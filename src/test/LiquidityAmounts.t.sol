// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {LiquidityAmounts} from "../libraries/LiquidityAmounts.sol";

contract LiquidityAmountsTest is DSTest {
    function testGetLiquidityForAmounts() public {
        assertEq(
            LiquidityAmounts.getLiquidityForAmounts(
                79228162514264337593543950336,
                75541088972021052632782079082,
                83095197869223157896060286990,
                100,
                200
            ),
            2148
        );

        assertEq(
            LiquidityAmounts.getLiquidityForAmounts(
                75162434512514379355924140470,
                75541088972021052632782079082,
                83095197869223157896060286990,
                100,
                200
            ),
            1048
        );

        assertEq(
            LiquidityAmounts.getLiquidityForAmounts(
                83472048772503575395058907992,
                75541088972021052632782079082,
                83095197869223157896060286990,
                100,
                200
            ),
            2097
        );

        assertEq(
            LiquidityAmounts.getLiquidityForAmounts(
                75541088972021052632782079082,
                75541088972021052632782079082,
                83095197869223157896060286990,
                100,
                200
            ),
            1048
        );

        assertEq(
            LiquidityAmounts.getLiquidityForAmounts(
                83095197869223157896060286990,
                75541088972021052632782079082,
                83095197869223157896060286990,
                100,
                200
            ),
            2097
        );
    }

    function testGetAmountsForLiquidity() public {
        uint256 amount0;
        uint256 amount1;

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            79228162514264337593543950336,
            75541088972021052632782079082,
            83095197869223157896060286990,
            2148
        );
        assertEq(amount0, 99);
        assertEq(amount1, 99);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            75162434512514379355924140470,
            75541088972021052632782079082,
            83095197869223157896060286990,
            1048
        );
        assertEq(amount0, 99);
        assertEq(amount1, 0);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            83472048772503575395058907992,
            75541088972021052632782079082,
            83095197869223157896060286990,
            2097
        );
        assertEq(amount0, 0);
        assertEq(amount1, 199);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            75541088972021052632782079082,
            75541088972021052632782079082,
            83095197869223157896060286990,
            1048
        );
        assertEq(amount0, 99);
        assertEq(amount1, 0);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            83095197869223157896060286990,
            75541088972021052632782079082,
            83095197869223157896060286990,
            2097
        );
        assertEq(amount0, 0);
        assertEq(amount1, 199);
    }
}
