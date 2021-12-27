// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {TickMath} from "./TickMath.sol";

library FullRangeMath {
    function getTicks(int24 tickSpacing) internal pure returns (int24 minTick, int24 maxTick) {
        minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
    }
}
