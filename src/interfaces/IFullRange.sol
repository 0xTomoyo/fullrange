// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0;

interface IFullRange {
    struct PoolKey {
        address tokenA;
        address tokenB;
        uint24 fee;
    }

    function factory() external view returns (address);

    function weth() external view returns (address);

    function oracle()
        external
        view
        returns (
            int24 maxTickDeviation,
            uint32 secondsAgo,
            uint16 observationCardinality
        );

    function getPool(address pair) external view returns (address);

    function getPair(address pool) external view returns (address);

    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pair, address pool);

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

    function collect(PoolKey memory poolKey) external returns (uint128 liquidity);

    function removeLiquidity(
        PoolKey memory poolKey,
        uint256 shares,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;

    function constructSymbol(address pair) external view returns (string memory);

    function constructName(address pair) external view returns (string memory);
}
