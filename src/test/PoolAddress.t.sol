// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {PoolAddress} from "../libraries/PoolAddress.sol";

contract MockPoolAddress {
    function computeAddress(
        address factory,
        address token0,
        address token1,
        uint24 fee
    ) external pure returns (address pool) {
        return PoolAddress.computeAddress(factory, token0, token1, fee);
    }
}

contract PoolAddressTest is DSTest {
    MockPoolAddress public poolAddress;

    function setUp() public {
        poolAddress = new MockPoolAddress();
    }

    function testComputeAddress() public {
        try poolAddress.computeAddress(address(0), address(0), address(0), 0) {
            fail();
        } catch {}

        assertEq(
            poolAddress.computeAddress(
                0x5FbDB2315678afecb367f032d93F642f64180aa3,
                0x1000000000000000000000000000000000000000,
                0x2000000000000000000000000000000000000000,
                250
            ),
            0x03D8bab195A5BC23d249693F53dfA0e358F2650D
        );

        try
            poolAddress.computeAddress(
                0x5FbDB2315678afecb367f032d93F642f64180aa3,
                0x2000000000000000000000000000000000000000,
                0x1000000000000000000000000000000000000000,
                3000
            )
        {
            fail();
        } catch {}
    }
}
