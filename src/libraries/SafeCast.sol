// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

library SafeCast {
    function toUint128(uint256 x) internal pure returns (uint128 y) {
        require(x <= type(uint128).max);
        y = uint128(x);
    }
}
