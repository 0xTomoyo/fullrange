// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

interface IFullRange {
    function getPool(address pair) external view returns (address);
}
