// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

/// @title Oracle library
/// @notice Provides functions to integrate with V3 pool oracle
library OracleLibrary {
    /// @notice Calculates time-weighted mean of the tick for a given Uniswap V3 pool
    /// @param pool Address of Uniswap V3 pool that we want to observe
    /// @param secondsAgo Number of seconds in the past from which to calculate the time-weighted means
    /// @return arithmeticMeanTick The arithmetic mean tick from (block.timestamp - secondsAgo) to block.timestamp
    function consult(address pool, uint32 secondsAgo) internal view returns (int24 arithmeticMeanTick) {
        if (secondsAgo == 0) {
            return getBlockStartingTick(pool);
        }

        uint32[] memory secondAgos = new uint32[](2);
        secondAgos[0] = secondsAgo;
        secondAgos[1] = 0;

        unchecked {
            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(pool).observe(secondAgos);
            int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

            arithmeticMeanTick = int24(tickCumulativesDelta / int56(uint56(secondsAgo)));

            // Always round to negative infinity
            if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int56(uint56(secondsAgo)) != 0))
                arithmeticMeanTick--;
        }
    }

    /// @notice Given a pool, it returns the tick value as of the start of the current block
    /// @param pool Address of Uniswap V3 pool
    /// @return The tick that the pool was in at the start of the current block
    function getBlockStartingTick(address pool) internal view returns (int24) {
        (, int24 tick, uint16 observationIndex, uint16 observationCardinality, , , ) = IUniswapV3Pool(pool).slot0();

        // 2 observations are needed to reliably calculate the block starting tick
        require(observationCardinality > 1, "NEO");

        // If the latest observation occurred in the past, then no tick-changing trades have happened in this block
        // therefore the tick in `slot0` is the same as at the beginning of the current block.
        // We don't need to check if this observation is initialized - it is guaranteed to be.
        (uint32 observationTimestamp, int56 tickCumulative, , ) = IUniswapV3Pool(pool).observations(observationIndex);
        if (observationTimestamp != uint32(block.timestamp)) {
            return tick;
        }

        unchecked {
            uint256 prevIndex = (uint256(observationIndex) + observationCardinality - 1) % observationCardinality;
            (uint32 prevObservationTimestamp, int56 prevTickCumulative, , bool prevInitialized) = IUniswapV3Pool(pool)
                .observations(prevIndex);

            require(prevInitialized, "ONI");

            uint32 delta = observationTimestamp - prevObservationTimestamp;
            return int24((tickCumulative - prevTickCumulative) / int56(uint56(delta)));
        }
    }
}
