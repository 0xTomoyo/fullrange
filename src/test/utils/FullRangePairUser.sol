// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {FullRangePair} from "../../FullRangePair.sol";

contract FullRangePairUser {
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
