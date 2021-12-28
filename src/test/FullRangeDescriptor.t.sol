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

    function toAsciiString(address addr, uint256 len) external pure returns (string memory) {
        return FullRangeDescriptor.toAsciiString(addr, len);
    }
}

contract MockCompliantERC20 {
    string public name;
    string public symbol;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }
}

contract MockNonCompliantERC20 {
    bytes32 public name;
    bytes32 public symbol;

    constructor(bytes32 name_, bytes32 symbol_) {
        name = name_;
        symbol = symbol_;
    }
}

contract MockOptionalERC20 {}

contract FullRangeDescriptorTest is DSTest {
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

    function testTokenSymbol() public {
        address token;

        token = address(new MockCompliantERC20("token name", "tn"));
        assertEq(FullRangeDescriptor.tokenSymbol(token), "tn");

        token = address(new MockNonCompliantERC20("token name", "tn"));
        assertEq(FullRangeDescriptor.tokenSymbol(token), "tn");

        token = address(new MockNonCompliantERC20("", ""));
        assertEq(FullRangeDescriptor.tokenSymbol(token), FullRangeDescriptor.toAsciiString(token, 6));

        token = address(new MockOptionalERC20());
        assertEq(FullRangeDescriptor.tokenSymbol(token), FullRangeDescriptor.toAsciiString(token, 6));

        token = address(0);
        assertEq(FullRangeDescriptor.tokenSymbol(token), FullRangeDescriptor.toAsciiString(token, 6));

        token = address(new MockCompliantERC20("", ""));
        assertEq(FullRangeDescriptor.tokenSymbol(token), FullRangeDescriptor.toAsciiString(token, 6));
    }

    function testFeeToPercentString() public {
        assertEq(FullRangeDescriptor.feeToPercentString(0), "0%");

        assertEq(FullRangeDescriptor.feeToPercentString(1), "0.0001%");

        assertEq(FullRangeDescriptor.feeToPercentString(30), "0.003%");

        assertEq(FullRangeDescriptor.feeToPercentString(33), "0.0033%");

        assertEq(FullRangeDescriptor.feeToPercentString(500), "0.05%");

        assertEq(FullRangeDescriptor.feeToPercentString(2500), "0.25%");

        assertEq(FullRangeDescriptor.feeToPercentString(3000), "0.3%");

        assertEq(FullRangeDescriptor.feeToPercentString(10000), "1%");

        assertEq(FullRangeDescriptor.feeToPercentString(17000), "1.7%");

        assertEq(FullRangeDescriptor.feeToPercentString(100000), "10%");

        assertEq(FullRangeDescriptor.feeToPercentString(150000), "15%");

        assertEq(FullRangeDescriptor.feeToPercentString(102000), "10.2%");

        assertEq(FullRangeDescriptor.feeToPercentString(1000000), "100%");

        assertEq(FullRangeDescriptor.feeToPercentString(1005000), "100.5%");

        assertEq(FullRangeDescriptor.feeToPercentString(10000000), "1000%");

        assertEq(FullRangeDescriptor.feeToPercentString(12300000), "1230%");
    }

    function testToAsciiString() public {
        assertEq(FullRangeDescriptor.toAsciiString(address(0), 40), "0000000000000000000000000000000000000000");

        address example = 0xC257274276a4E539741Ca11b590B9447B26A8051;

        assertEq(FullRangeDescriptor.toAsciiString(example, 40), "C257274276A4E539741CA11B590B9447B26A8051");

        try fullRangeDescriptor.toAsciiString(example, 39) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "INVALID_LEN");
        }

        try fullRangeDescriptor.toAsciiString(example, 42) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "INVALID_LEN");
        }

        try fullRangeDescriptor.toAsciiString(example, 0) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "INVALID_LEN");
        }

        assertEq(FullRangeDescriptor.toAsciiString(example, 4), "C257");

        assertEq(FullRangeDescriptor.toAsciiString(example, 10), "C257274276");

        assertEq(FullRangeDescriptor.toAsciiString(example, 16), "C257274276A4E539");
    }
}
