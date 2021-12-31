// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {SafeCast} from "../libraries/SafeCast.sol";

contract SafeCastTest is DSTest {
    function testToUint128() public {
        assertEq(SafeCast.toUint128(2.5e27), 2.5e27);
        assertEq(SafeCast.toUint128(2.5e18), 2.5e18);
    }

    function testFailToUint128() public pure {
        SafeCast.toUint128(type(uint128).max + 1);
    }

    function testToUint128(uint256 x) public {
        x %= type(uint128).max;

        assertEq(SafeCast.toUint128(x), x);
    }

    function testFailToUint128(uint256 x) public pure {
        if (type(uint128).max > x) revert();

        SafeCast.toUint128(x);
    }
}
