// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

interface IFullRange {
    struct PoolKey {
        address tokenA;
        address tokenB;
        uint24 fee;
    }

    function getPool(address pair) external view returns (address);

    function getPair(address pool) external view returns (address);

    function addLiquidity(
        PoolKey memory poolKey,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            uint256 shares
        );
}
