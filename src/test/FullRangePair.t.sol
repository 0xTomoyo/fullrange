// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {FullRange} from "../FullRange.sol";
import {FullRangePair} from "../FullRangePair.sol";
import {FACTORY, WETH, USDC, WBTC, DAI, FeeAmount} from "./utils/Constants.sol";

contract MockFullRangePair {
    FullRangePair public fullRangePair;

    constructor(FullRangePair _fullRangePair) {
        fullRangePair = _fullRangePair;
    }

    function mint(address to, uint256 amount) public virtual {
        fullRangePair.mint(to, amount);
    }

    function burn(address from, uint256 amount) public virtual {
        fullRangePair.burn(from, amount);
    }

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        return fullRangePair.approve(spender, amount);
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        return fullRangePair.transfer(to, amount);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        return fullRangePair.transferFrom(from, to, amount);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        return fullRangePair.permit(owner, spender, value, deadline, v, r, s);
    }
}

contract FullRangePairTest is DSTest {
    struct MetadataTestCase {
        address token0;
        address token1;
        uint24 fee;
        string symbol;
        string name;
    }

    FullRangePair public fullRangePair;

    function setUp() public {
        fullRangePair = new FullRangePair();
    }

    function testDecimals() public {
        assertEq(fullRangePair.decimals(), 18);
    }

    function testFullRange() public {
        assertEq(fullRangePair.fullRange(), address(this));
    }

    function testMetadata() public {
        try fullRangePair.symbol() {
            fail();
        } catch {}
        try fullRangePair.name() {
            fail();
        } catch {}

        FullRange fullRange = new FullRange(FACTORY, WETH);
        MetadataTestCase[3] memory metadataTestCases = [
            MetadataTestCase(USDC, WETH, FeeAmount.MEDIUM, "UNI-V3-USDC/WETH-0.3%", "Uniswap V3 USDC/WETH 0.3% LP"),
            MetadataTestCase(USDC, WETH, FeeAmount.HIGH, "UNI-V3-USDC/WETH-1%", "Uniswap V3 USDC/WETH 1% LP"),
            MetadataTestCase(DAI, USDC, FeeAmount.LOW, "UNI-V3-DAI/USDC-0.05%", "Uniswap V3 DAI/USDC 0.05% LP")
        ];
        for (uint256 i = 0; i < metadataTestCases.length; i++) {
            MetadataTestCase memory metadataTestCase = metadataTestCases[i];
            (address pair, ) = fullRange.createPair(
                metadataTestCase.token0,
                metadataTestCase.token1,
                metadataTestCase.fee
            );
            assertEq(FullRangePair(pair).symbol(), metadataTestCase.symbol);
            assertEq(FullRangePair(pair).name(), metadataTestCase.name);
        }
    }

    function testMint(address from, uint256 amount) public {
        MockFullRangePair user = new MockFullRangePair(fullRangePair);

        try user.mint(from, amount) {
            fail();
        } catch {}
        fullRangePair.mint(from, amount);

        assertEq(fullRangePair.totalSupply(), amount);
        assertEq(fullRangePair.balanceOf(from), amount);
    }

    function testBurn(
        address from,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        if (burnAmount > mintAmount) return;
        MockFullRangePair user = new MockFullRangePair(fullRangePair);

        fullRangePair.mint(from, mintAmount);
        try user.burn(from, burnAmount) {
            fail();
        } catch {}
        fullRangePair.burn(from, burnAmount);

        assertEq(fullRangePair.totalSupply(), mintAmount - burnAmount);
        assertEq(fullRangePair.balanceOf(from), mintAmount - burnAmount);
    }

    function testApprove(address from, uint256 amount) public {
        assertTrue(fullRangePair.approve(from, amount));

        assertEq(fullRangePair.allowance(address(this), from), amount);
    }

    function testTransfer(address from, uint256 amount) public {
        fullRangePair.mint(address(this), amount);

        assertTrue(fullRangePair.transfer(from, amount));
        assertEq(fullRangePair.totalSupply(), amount);

        if (address(this) == from) {
            assertEq(fullRangePair.balanceOf(address(this)), amount);
        } else {
            assertEq(fullRangePair.balanceOf(address(this)), 0);
            assertEq(fullRangePair.balanceOf(from), amount);
        }
    }

    function testTransferFrom(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        if (amount > approval) return;

        MockFullRangePair user = new MockFullRangePair(fullRangePair);

        fullRangePair.mint(address(user), amount);

        user.approve(address(this), approval);

        assertTrue(fullRangePair.transferFrom(address(user), to, amount));
        assertEq(fullRangePair.totalSupply(), amount);

        uint256 app = address(user) == address(this) || approval == type(uint256).max ? approval : approval - amount;
        assertEq(fullRangePair.allowance(address(user), address(this)), app);

        if (address(user) == to) {
            assertEq(fullRangePair.balanceOf(address(user)), amount);
        } else {
            assertEq(fullRangePair.balanceOf(address(user)), 0);
            assertEq(fullRangePair.balanceOf(to), amount);
        }
    }

    function testFailTransferFromInsufficientAllowance(
        address to,
        uint256 approval,
        uint256 amount
    ) public {
        require(approval < amount);

        MockFullRangePair user = new MockFullRangePair(fullRangePair);

        fullRangePair.mint(address(user), amount);
        user.approve(address(this), approval);
        fullRangePair.transferFrom(address(user), to, amount);
    }

    function testFailTransferFromInsufficientBalance(
        address to,
        uint256 mintAmount,
        uint256 sendAmount
    ) public {
        require(mintAmount < sendAmount);

        MockFullRangePair user = new MockFullRangePair(fullRangePair);

        fullRangePair.mint(address(user), mintAmount);
        user.approve(address(this), sendAmount);
        fullRangePair.transferFrom(address(user), to, sendAmount);
    }
}
