// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {FullRangeDescriptor} from "../libraries/FullRangeDescriptor.sol";

contract MockFullRangeDescriptor {
    mapping(address => address) public getPool;

    function constructName(address pool) external returns (string memory name) {
        getPool[address(this)] = pool;
        name = FullRangeDescriptor.constructName(address(this));
        getPool[address(this)] = address(0);
    }

    function constructSymbol(address pool) external returns (string memory symbol) {
        getPool[address(this)] = pool;
        symbol = FullRangeDescriptor.constructSymbol(address(this));
        getPool[address(this)] = address(0);
    }
}

contract FullMathTest is DSTest {
    struct MetadataTestCase {
        address pool;
        string symbol;
        string name;
    }

    MockFullRangeDescriptor public fullRangeDescriptor;

    function setUp() public {
        fullRangeDescriptor = new MockFullRangeDescriptor();
    }

    function testMetaData() public {
        MetadataTestCase[5] memory metadataTestCases = [
            MetadataTestCase(
                0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8,
                "UNI-V3-USDC/WETH-0.3%",
                "Uniswap V3 USDC/WETH 0.3% LP"
            ),
            MetadataTestCase(
                0x7BeA39867e4169DBe237d55C8242a8f2fcDcc387,
                "UNI-V3-USDC/WETH-1%",
                "Uniswap V3 USDC/WETH 1% LP"
            ),
            MetadataTestCase(
                0x6c6Bc977E13Df9b0de53b251522280BB72383700,
                "UNI-V3-DAI/USDC-0.05%",
                "Uniswap V3 DAI/USDC 0.05% LP"
            ),
            MetadataTestCase(
                0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35,
                "UNI-V3-WBTC/USDC-0.3%",
                "Uniswap V3 WBTC/USDC 0.3% LP"
            ),
            MetadataTestCase(
                0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168,
                "UNI-V3-DAI/USDC-0.01%",
                "Uniswap V3 DAI/USDC 0.01% LP"
            )
        ];
        for (uint256 i = 0; i < metadataTestCases.length; i++) {
            MetadataTestCase memory metadataTestCase = metadataTestCases[i];
            assertEq(fullRangeDescriptor.constructSymbol(metadataTestCase.pool), metadataTestCase.symbol);
            assertEq(fullRangeDescriptor.constructName(metadataTestCase.pool), metadataTestCase.name);
        }
    }
}
