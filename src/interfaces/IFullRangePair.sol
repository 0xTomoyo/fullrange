// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

import {IERC20} from "./IERC20.sol";

interface IFullRangePair is IERC20 {
    function fullRange() external view returns (address);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
