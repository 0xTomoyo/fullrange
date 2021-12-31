// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {PairDescriptor} from "../libraries/PairDescriptor.sol";

contract MockPairDescriptor {
    function toAsciiString(address addr, uint256 len) external pure returns (string memory) {
        return PairDescriptor.toAsciiString(addr, len);
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

contract PairDescriptorTest is DSTest {
    struct MetadataTestCase {
        address pool;
        string symbol;
        string name;
    }

    MockPairDescriptor public pairDescriptor;

    function setUp() public {
        pairDescriptor = new MockPairDescriptor();
    }

    function testMetaData() public {
        MetadataTestCase[3] memory metadataTestCases = [
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
            )
        ];
        for (uint256 i = 0; i < metadataTestCases.length; i++) {
            MetadataTestCase memory metadataTestCase = metadataTestCases[i];
            assertEq(PairDescriptor.constructSymbol(metadataTestCase.pool), metadataTestCase.symbol);
            assertEq(PairDescriptor.constructName(metadataTestCase.pool), metadataTestCase.name);
        }
    }

    function testTokenSymbol() public {
        address token;

        token = address(new MockCompliantERC20("token name", "tn"));
        assertEq(PairDescriptor.tokenSymbol(token), "tn");

        token = address(new MockNonCompliantERC20("token name", "tn"));
        assertEq(PairDescriptor.tokenSymbol(token), "tn");

        token = address(new MockNonCompliantERC20("", ""));
        assertEq(PairDescriptor.tokenSymbol(token), PairDescriptor.toAsciiString(token, 6));

        token = address(new MockOptionalERC20());
        assertEq(PairDescriptor.tokenSymbol(token), PairDescriptor.toAsciiString(token, 6));

        token = address(0);
        assertEq(PairDescriptor.tokenSymbol(token), PairDescriptor.toAsciiString(token, 6));

        token = address(new MockCompliantERC20("", ""));
        assertEq(PairDescriptor.tokenSymbol(token), PairDescriptor.toAsciiString(token, 6));
    }

    function testFeeToPercentString() public {
        assertEq(PairDescriptor.feeToPercentString(0), "0%");

        assertEq(PairDescriptor.feeToPercentString(1), "0.0001%");

        assertEq(PairDescriptor.feeToPercentString(30), "0.003%");

        assertEq(PairDescriptor.feeToPercentString(33), "0.0033%");

        assertEq(PairDescriptor.feeToPercentString(500), "0.05%");

        assertEq(PairDescriptor.feeToPercentString(2500), "0.25%");

        assertEq(PairDescriptor.feeToPercentString(3000), "0.3%");

        assertEq(PairDescriptor.feeToPercentString(10000), "1%");

        assertEq(PairDescriptor.feeToPercentString(17000), "1.7%");

        assertEq(PairDescriptor.feeToPercentString(100000), "10%");

        assertEq(PairDescriptor.feeToPercentString(150000), "15%");

        assertEq(PairDescriptor.feeToPercentString(102000), "10.2%");

        assertEq(PairDescriptor.feeToPercentString(1000000), "100%");

        assertEq(PairDescriptor.feeToPercentString(1005000), "100.5%");

        assertEq(PairDescriptor.feeToPercentString(10000000), "1000%");

        assertEq(PairDescriptor.feeToPercentString(12300000), "1230%");
    }

    function testToAsciiString() public {
        assertEq(PairDescriptor.toAsciiString(address(0), 40), "0000000000000000000000000000000000000000");

        address example = 0xC257274276a4E539741Ca11b590B9447B26A8051;

        assertEq(PairDescriptor.toAsciiString(example, 40), "C257274276A4E539741CA11B590B9447B26A8051");

        try pairDescriptor.toAsciiString(example, 39) {
            fail();
        } catch {}

        try pairDescriptor.toAsciiString(example, 42) {
            fail();
        } catch {}

        try pairDescriptor.toAsciiString(example, 0) {
            fail();
        } catch {}

        assertEq(PairDescriptor.toAsciiString(example, 4), "C257");

        assertEq(PairDescriptor.toAsciiString(example, 10), "C257274276");

        assertEq(PairDescriptor.toAsciiString(example, 16), "C257274276A4E539");
    }
}
