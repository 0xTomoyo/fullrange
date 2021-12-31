// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {OracleLibrary} from "../libraries/OracleLibrary.sol";

library Oracle {
    struct Observation {
        uint32 blockTimestamp;
        int56 tickCumulative;
        uint160 secondsPerLiquidityCumulativeX128;
        bool initialized;
    }

    function transform(
        Observation memory last,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity
    ) private pure returns (Observation memory) {
        uint32 delta = blockTimestamp - last.blockTimestamp;
        return
            Observation({
                blockTimestamp: blockTimestamp,
                tickCumulative: last.tickCumulative + int56(tick) * int56(uint56(delta)),
                secondsPerLiquidityCumulativeX128: last.secondsPerLiquidityCumulativeX128 +
                    ((uint160(delta) << 128) / (liquidity > 0 ? liquidity : 1)),
                initialized: true
            });
    }

    function initialize(Observation[65535] storage self, uint32 time)
        internal
        returns (uint16 cardinality, uint16 cardinalityNext)
    {
        self[0] = Observation({
            blockTimestamp: time,
            tickCumulative: 0,
            secondsPerLiquidityCumulativeX128: 0,
            initialized: true
        });
        return (1, 1);
    }

    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 blockTimestamp,
        int24 tick,
        uint128 liquidity,
        uint16 cardinality,
        uint16 cardinalityNext
    ) internal returns (uint16 indexUpdated, uint16 cardinalityUpdated) {
        Observation memory last = self[index];

        // early return if we've already written an observation this block
        if (last.blockTimestamp == blockTimestamp) return (index, cardinality);

        // if the conditions are right, we can bump the cardinality
        if (cardinalityNext > cardinality && index == (cardinality - 1)) {
            cardinalityUpdated = cardinalityNext;
        } else {
            cardinalityUpdated = cardinality;
        }

        indexUpdated = (index + 1) % cardinalityUpdated;
        self[indexUpdated] = transform(last, blockTimestamp, tick, liquidity);
    }

    function grow(
        Observation[65535] storage self,
        uint16 current,
        uint16 next
    ) internal returns (uint16) {
        require(current > 0, "I");
        // no-op if the passed next value isn't greater than the current next value
        if (next <= current) return current;
        // store in each slot to prevent fresh SSTOREs in swaps
        // this data will not be used because the initialized boolean is still false
        for (uint16 i = current; i < next; i++) self[i].blockTimestamp = 1;
        return next;
    }

    function lte(
        uint32 time,
        uint32 a,
        uint32 b
    ) private pure returns (bool) {
        // if there hasn't been overflow, no need to adjust
        if (a <= time && b <= time) return a <= b;

        uint256 aAdjusted = a > time ? a : a + 2**32;
        uint256 bAdjusted = b > time ? b : b + 2**32;

        return aAdjusted <= bAdjusted;
    }

    function binarySearch(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        uint16 index,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        uint256 l = (index + 1) % cardinality; // oldest observation
        uint256 r = l + cardinality - 1; // newest observation
        uint256 i;
        while (true) {
            i = (l + r) / 2;

            beforeOrAt = self[i % cardinality];

            // we've landed on an uninitialized tick, keep searching higher (more recently)
            if (!beforeOrAt.initialized) {
                l = i + 1;
                continue;
            }

            atOrAfter = self[(i + 1) % cardinality];

            bool targetAtOrAfter = lte(time, beforeOrAt.blockTimestamp, target);

            // check if we've found the answer!
            if (targetAtOrAfter && lte(time, target, atOrAfter.blockTimestamp)) break;

            if (!targetAtOrAfter) r = i - 1;
            else l = i + 1;
        }
    }

    function getSurroundingObservations(
        Observation[65535] storage self,
        uint32 time,
        uint32 target,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) private view returns (Observation memory beforeOrAt, Observation memory atOrAfter) {
        // optimistically set before to the newest observation
        beforeOrAt = self[index];

        // if the target is chronologically at or after the newest observation, we can early return
        if (lte(time, beforeOrAt.blockTimestamp, target)) {
            if (beforeOrAt.blockTimestamp == target) {
                // if newest observation equals target, we're in the same block, so we can ignore atOrAfter
                return (beforeOrAt, atOrAfter);
            } else {
                // otherwise, we need to transform
                return (beforeOrAt, transform(beforeOrAt, target, tick, liquidity));
            }
        }

        // now, set before to the oldest observation
        beforeOrAt = self[(index + 1) % cardinality];
        if (!beforeOrAt.initialized) beforeOrAt = self[0];

        // ensure that the target is chronologically at or after the oldest observation
        require(lte(time, beforeOrAt.blockTimestamp, target), "OLD");

        // if we've reached this point, we have to binary search
        return binarySearch(self, time, target, index, cardinality);
    }

    function observeSingle(
        Observation[65535] storage self,
        uint32 time,
        uint32 secondsAgo,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56 tickCumulative, uint160 secondsPerLiquidityCumulativeX128) {
        if (secondsAgo == 0) {
            Observation memory last = self[index];
            if (last.blockTimestamp != time) last = transform(last, time, tick, liquidity);
            return (last.tickCumulative, last.secondsPerLiquidityCumulativeX128);
        }

        uint32 target = time - secondsAgo;

        (Observation memory beforeOrAt, Observation memory atOrAfter) = getSurroundingObservations(
            self,
            time,
            target,
            tick,
            index,
            liquidity,
            cardinality
        );

        if (target == beforeOrAt.blockTimestamp) {
            // we're at the left boundary
            return (beforeOrAt.tickCumulative, beforeOrAt.secondsPerLiquidityCumulativeX128);
        } else if (target == atOrAfter.blockTimestamp) {
            // we're at the right boundary
            return (atOrAfter.tickCumulative, atOrAfter.secondsPerLiquidityCumulativeX128);
        } else {
            // we're in the middle
            uint32 observationTimeDelta = atOrAfter.blockTimestamp - beforeOrAt.blockTimestamp;
            uint32 targetDelta = target - beforeOrAt.blockTimestamp;
            return (
                beforeOrAt.tickCumulative +
                    ((atOrAfter.tickCumulative - beforeOrAt.tickCumulative) / int56(uint56(observationTimeDelta))) *
                    int56(uint56(targetDelta)),
                beforeOrAt.secondsPerLiquidityCumulativeX128 +
                    uint160(
                        (uint256(
                            atOrAfter.secondsPerLiquidityCumulativeX128 - beforeOrAt.secondsPerLiquidityCumulativeX128
                        ) * targetDelta) / observationTimeDelta
                    )
            );
        }
    }

    function observe(
        Observation[65535] storage self,
        uint32 time,
        uint32[] memory secondsAgos,
        int24 tick,
        uint16 index,
        uint128 liquidity,
        uint16 cardinality
    ) internal view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) {
        require(cardinality > 0, "I");

        tickCumulatives = new int56[](secondsAgos.length);
        secondsPerLiquidityCumulativeX128s = new uint160[](secondsAgos.length);
        for (uint256 i = 0; i < secondsAgos.length; i++) {
            (tickCumulatives[i], secondsPerLiquidityCumulativeX128s[i]) = observeSingle(
                self,
                time,
                secondsAgos[i],
                tick,
                index,
                liquidity,
                cardinality
            );
        }
    }
}

contract MockOracleLibrary {
    function consult(
        address pool,
        uint32 secondsAgo,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality
    ) external view returns (int24 arithmeticMeanTick) {
        return OracleLibrary.consult(pool, secondsAgo, tick, observationIndex, observationCardinality);
    }

    function getBlockStartingTick(
        address pool,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality
    ) external view returns (int24) {
        return OracleLibrary.getBlockStartingTick(pool, tick, observationIndex, observationCardinality);
    }
}

contract MockObservable {
    Observation private observation0;
    Observation private observation1;

    struct Observation {
        uint32 secondsAgo;
        int56 tickCumulatives;
        uint160 secondsPerLiquidityCumulativeX128s;
    }

    constructor(
        uint32[] memory secondsAgos,
        int56[] memory tickCumulatives,
        uint160[] memory secondsPerLiquidityCumulativeX128s
    ) {
        require(
            secondsAgos.length == 2 && tickCumulatives.length == 2 && secondsPerLiquidityCumulativeX128s.length == 2,
            "Invalid test case size"
        );

        observation0 = Observation(secondsAgos[0], tickCumulatives[0], secondsPerLiquidityCumulativeX128s[0]);
        observation1 = Observation(secondsAgos[1], tickCumulatives[1], secondsPerLiquidityCumulativeX128s[1]);
    }

    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s)
    {
        require(
            secondsAgos[0] == observation0.secondsAgo && secondsAgos[1] == observation1.secondsAgo,
            "Invalid test case"
        );

        int56[] memory _tickCumulatives = new int56[](2);
        _tickCumulatives[0] = observation0.tickCumulatives;
        _tickCumulatives[1] = observation1.tickCumulatives;

        uint160[] memory _secondsPerLiquidityCumulativeX128s = new uint160[](2);
        _secondsPerLiquidityCumulativeX128s[0] = observation0.secondsPerLiquidityCumulativeX128s;
        _secondsPerLiquidityCumulativeX128s[1] = observation1.secondsPerLiquidityCumulativeX128s;

        return (_tickCumulatives, _secondsPerLiquidityCumulativeX128s);
    }
}

contract MockObservations {
    Oracle.Observation[4] internal oracleObservations;

    uint16 internal slot0ObservationIndex;
    bool internal lastObservationCurrentTimestamp;

    constructor(
        uint32[4] memory _blockTimestamps,
        int56[4] memory _tickCumulatives,
        uint128[4] memory _secondsPerLiquidityCumulativeX128s,
        bool[4] memory _initializeds,
        uint16 _observationIndex,
        bool _lastObservationCurrentTimestamp
    ) {
        for (uint256 i = 0; i < _blockTimestamps.length; i++) {
            oracleObservations[i] = Oracle.Observation({
                blockTimestamp: _blockTimestamps[i],
                tickCumulative: _tickCumulatives[i],
                secondsPerLiquidityCumulativeX128: _secondsPerLiquidityCumulativeX128s[i],
                initialized: _initializeds[i]
            });
        }

        slot0ObservationIndex = _observationIndex;
        lastObservationCurrentTimestamp = _lastObservationCurrentTimestamp;
    }

    function observations(uint256 index)
        external
        view
        returns (
            uint32,
            int56,
            uint160,
            bool
        )
    {
        Oracle.Observation memory observation = oracleObservations[index];
        if (lastObservationCurrentTimestamp) {
            observation.blockTimestamp =
                uint32(block.timestamp) -
                (oracleObservations[slot0ObservationIndex].blockTimestamp - observation.blockTimestamp);
        }
        return (
            observation.blockTimestamp,
            observation.tickCumulative,
            observation.secondsPerLiquidityCumulativeX128,
            observation.initialized
        );
    }
}

contract OracleLibraryTest is DSTest {
    MockOracleLibrary public oracleLibrary;

    function setUp() public {
        oracleLibrary = new MockOracleLibrary();
    }

    function testConsult() public {
        uint32 period = 3;
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = period;
        secondsAgos[1] = 0;
        int56[] memory tickCumulatives = new int56[](2);
        tickCumulatives[0] = 12;
        tickCumulatives[1] = 12;
        uint160[] memory secondsPerLiquidityCumulativeX128s = new uint160[](2);
        secondsPerLiquidityCumulativeX128s[0] = 10;
        secondsPerLiquidityCumulativeX128s[1] = 20;
        MockObservable observable = new MockObservable(
            secondsAgos,
            tickCumulatives,
            secondsPerLiquidityCumulativeX128s
        );
        assertEq(OracleLibrary.consult(address(observable), period, 0, 0, 0), 0);

        period = 4;
        secondsAgos[0] = period;
        secondsAgos[1] = 0;
        tickCumulatives[0] = -10;
        tickCumulatives[1] = -12;
        secondsPerLiquidityCumulativeX128s[0] = 10;
        secondsPerLiquidityCumulativeX128s[1] = 15;
        observable = new MockObservable(secondsAgos, tickCumulatives, secondsPerLiquidityCumulativeX128s);
        assertEq(OracleLibrary.consult(address(observable), period, 0, 0, 0), -1);

        period = 1;
        secondsAgos[0] = period;
        secondsAgos[1] = 0;
        tickCumulatives[0] = 12;
        tickCumulatives[1] = 12;
        secondsPerLiquidityCumulativeX128s[0] = 10;
        secondsPerLiquidityCumulativeX128s[1] = 11;
        observable = new MockObservable(secondsAgos, tickCumulatives, secondsPerLiquidityCumulativeX128s);
        assertEq(OracleLibrary.consult(address(observable), period, 0, 0, 0), 0);
    }

    function testGetBlockStartingTick() public {
        int24 tick = 0;
        uint16 observationIndex = 0;
        uint16 observationCardinality = 0;
        MockObservations observations = new MockObservations(
            [uint32(0), 0, 0, 0],
            [int56(0), 0, 0, 0],
            [uint128(0), 0, 0, 0],
            [false, false, false, false],
            observationIndex,
            false
        );
        try oracleLibrary.getBlockStartingTick(address(observations), tick, observationIndex, observationCardinality) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "NEO");
        }

        tick = 6;
        observationIndex = 2;
        observationCardinality = 3;
        observations = new MockObservations(
            [uint32(1), 3, 4, 0],
            [int56(0), 8, 13, 0],
            [uint128(0), 136112946768375385385349842972707284, 184724713471366594451546215462959885, 0],
            [true, true, true, false],
            observationIndex,
            false
        );
        assertEq(
            OracleLibrary.getBlockStartingTick(address(observations), tick, observationIndex, observationCardinality),
            tick
        );

        tick = 4;
        observationIndex = 0;
        observationCardinality = 1;
        observations = new MockObservations(
            [uint32(1), 0, 0, 0],
            [int56(8), 0, 0, 0],
            [uint128(136112946768375385385349842972707284), 0, 0, 0],
            [true, false, false, false],
            observationIndex,
            true
        );
        try oracleLibrary.getBlockStartingTick(address(observations), tick, observationIndex, observationCardinality) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "NEO");
        }

        tick = 4;
        observationIndex = 0;
        observationCardinality = 2;
        observations = new MockObservations(
            [uint32(1), 0, 0, 0],
            [int56(8), 0, 0, 0],
            [uint128(136112946768375385385349842972707284), 0, 0, 0],
            [true, false, false, false],
            observationIndex,
            true
        );
        try oracleLibrary.getBlockStartingTick(address(observations), tick, observationIndex, observationCardinality) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "ONI");
        }

        tick = 3;
        observationIndex = 0;
        observationCardinality = 3;
        uint32[4] memory blockTimestamps = [uint32(9), 5, 8, 0];
        int56[4] memory tickCumulatives = [int56(99), 80, 95, 0];
        observations = new MockObservations(
            blockTimestamps,
            tickCumulatives,
            [
                uint128(965320616647837491242414421221086683),
                839853488995212437053956034406948254,
                939565063595995342933046073701273770,
                0
            ],
            [true, true, true, false],
            observationIndex,
            true
        );
        assertEq(
            OracleLibrary.getBlockStartingTick(address(observations), tick, observationIndex, observationCardinality),
            (tickCumulatives[0] - tickCumulatives[2]) / int56(uint56(blockTimestamps[0] - blockTimestamps[2]))
        );
    }

    function testConsult0SecondsAgo() public {
        int24 tick = 0;
        uint16 observationIndex = 0;
        uint16 observationCardinality = 0;
        MockObservations observations = new MockObservations(
            [uint32(0), 0, 0, 0],
            [int56(0), 0, 0, 0],
            [uint128(0), 0, 0, 0],
            [false, false, false, false],
            observationIndex,
            false
        );
        try oracleLibrary.consult(address(observations), 0, tick, observationIndex, observationCardinality) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "NEO");
        }

        tick = 6;
        observationIndex = 2;
        observationCardinality = 3;
        observations = new MockObservations(
            [uint32(1), 3, 4, 0],
            [int56(0), 8, 13, 0],
            [uint128(0), 136112946768375385385349842972707284, 184724713471366594451546215462959885, 0],
            [true, true, true, false],
            observationIndex,
            false
        );
        assertEq(OracleLibrary.consult(address(observations), 0, tick, observationIndex, observationCardinality), tick);

        tick = 4;
        observationIndex = 0;
        observationCardinality = 1;
        observations = new MockObservations(
            [uint32(1), 0, 0, 0],
            [int56(8), 0, 0, 0],
            [uint128(136112946768375385385349842972707284), 0, 0, 0],
            [true, false, false, false],
            observationIndex,
            true
        );
        try oracleLibrary.consult(address(observations), 0, tick, observationIndex, observationCardinality) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "NEO");
        }

        tick = 4;
        observationIndex = 0;
        observationCardinality = 2;
        observations = new MockObservations(
            [uint32(1), 0, 0, 0],
            [int56(8), 0, 0, 0],
            [uint128(136112946768375385385349842972707284), 0, 0, 0],
            [true, false, false, false],
            observationIndex,
            true
        );
        try oracleLibrary.consult(address(observations), 0, tick, observationIndex, observationCardinality) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "ONI");
        }

        tick = 3;
        observationIndex = 0;
        observationCardinality = 3;
        uint32[4] memory blockTimestamps = [uint32(9), 5, 8, 0];
        int56[4] memory tickCumulatives = [int56(99), 80, 95, 0];
        observations = new MockObservations(
            blockTimestamps,
            tickCumulatives,
            [
                uint128(965320616647837491242414421221086683),
                839853488995212437053956034406948254,
                939565063595995342933046073701273770,
                0
            ],
            [true, true, true, false],
            observationIndex,
            true
        );
        assertEq(
            OracleLibrary.consult(address(observations), 0, tick, observationIndex, observationCardinality),
            (tickCumulatives[0] - tickCumulatives[2]) / int56(uint56(blockTimestamps[0] - blockTimestamps[2]))
        );
    }
}
