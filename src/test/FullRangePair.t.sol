// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {DSTest} from "ds-test/test.sol";
import {FullRangePair} from "../FullRangePair.sol";
import {FullRangePairUser} from "./utils/users/FullRangePairUser.sol";

contract FullRangePairTest is DSTest {
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

    function testMint(address from, uint256 amount) public {
        FullRangePairUser user = new FullRangePairUser(fullRangePair);

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
        FullRangePairUser user = new FullRangePairUser(fullRangePair);

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

        FullRangePairUser user = new FullRangePairUser(fullRangePair);

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

        FullRangePairUser user = new FullRangePairUser(fullRangePair);

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

        FullRangePairUser user = new FullRangePairUser(fullRangePair);

        fullRangePair.mint(address(user), mintAmount);
        user.approve(address(this), sendAmount);
        fullRangePair.transferFrom(address(user), to, sendAmount);
    }
}
