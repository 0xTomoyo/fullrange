// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {PoolAddress} from "./libraries/PoolAddress.sol";
import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";
import {OracleLibrary} from "./libraries/OracleLibrary.sol";
import {FullRangePair} from "./FullRangePair.sol";
import {IFullRange} from "./interfaces/IFullRange.sol";
import {FullRangeLibrary} from "./libraries/FullRangeLibrary.sol";
import {TransferHelper} from "./libraries/TransferHelper.sol";
import {PairDescriptor} from "./libraries/PairDescriptor.sol";

contract FullRange is IFullRange {
    struct Oracle {
        int24 maxTickDeviation;
        uint32 secondsAgo;
        uint16 observationCardinality;
    }

    struct MintCallbackData {
        PoolKey poolKey;
        address payer;
    }

    address public immutable override factory;

    address public immutable override weth;

    Oracle public override oracle;

    mapping(address => address) public override getPool;

    mapping(address => address) public override getPair;

    constructor(address _factory, address _weth) {
        factory = _factory;
        weth = _weth;

        oracle = Oracle({maxTickDeviation: 100, secondsAgo: 0, observationCardinality: 2});
    }

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "Transaction too old");
        _;
    }

    function createPair(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override returns (address pair, address pool) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        PoolKey memory poolKey = PoolKey(tokenA, tokenB, fee);
        FullRangeLibrary.Vars memory vars = FullRangeLibrary.getVars(poolKey, getPair, factory);
        _createPair(poolKey, vars);
        pool = vars.pool;
        pair = vars.pair;
    }

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
        override
        checkDeadline(deadline)
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1,
            uint256 shares
        )
    {
        (amountADesired, amountBDesired, amountAMin, amountBMin) = FullRangeLibrary.sortParams(
            poolKey,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        FullRangeLibrary.Vars memory vars = FullRangeLibrary.getVars(poolKey, getPair, factory);
        _createPair(poolKey, vars);
        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            vars.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(vars.tickLower),
            TickMath.getSqrtRatioAtTick(vars.tickUpper),
            amountADesired,
            amountBDesired
        );
        (amount0, amount1) = _addLiquidity(poolKey, vars, msg.sender, liquidity);
        require(amount0 >= amountAMin && amount1 >= amountBMin, "Price slippage check");
        shares = _mint(vars, to, liquidity);
    }

    function collect(PoolKey memory poolKey)
        external
        override
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        FullRangeLibrary.sortParams(poolKey);
        FullRangeLibrary.Vars memory vars = FullRangeLibrary.getVars(poolKey, getPair, factory);
        Oracle memory _oracle = oracle;
        require(_canCollect(_oracle, vars), "Cannot collect");
        _updateOracle(vars, _oracle.observationCardinality);
        (liquidity, amount0, amount1) = _collect(vars);
        (amount0, amount1) = liquidity != 0 ? _addLiquidity(poolKey, vars, address(this), liquidity) : (0, 0);
    }

    function removeLiquidity(
        PoolKey memory poolKey,
        uint256 shares,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        override
        checkDeadline(deadline)
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (amountAMin, amountBMin) = FullRangeLibrary.sortParams(poolKey, amountAMin, amountBMin);
        FullRangeLibrary.Vars memory vars = FullRangeLibrary.getVars(poolKey, getPair, factory);
        liquidity = _burn(vars, msg.sender, shares);
        (amount0, amount1) = _removeLiquidity(vars, to, liquidity);
        require(amount0 >= amountAMin && amount1 >= amountBMin, "Price slippage check");
    }

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external override {
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));
        require(
            msg.sender ==
                PoolAddress.computeAddress(
                    factory,
                    decoded.poolKey.tokenA,
                    decoded.poolKey.tokenB,
                    decoded.poolKey.fee
                ),
            "Invalid sender"
        );
        if (amount0Owed > 0) _pay(decoded.poolKey.tokenA, decoded.payer, msg.sender, amount0Owed);
        if (amount1Owed > 0) _pay(decoded.poolKey.tokenB, decoded.payer, msg.sender, amount1Owed);
    }

    function constructSymbol(address pair) external view returns (string memory) {
        return PairDescriptor.constructSymbol(getPool[pair]);
    }

    function constructName(address pair) external view returns (string memory) {
        return PairDescriptor.constructName(getPool[pair]);
    }

    function _createPair(PoolKey memory poolKey, FullRangeLibrary.Vars memory vars) internal {
        if (vars.pair == address(0)) {
            require(vars.sqrtPriceX96 != 0, "Pool uninitialized");
            vars.pair = address(
                new FullRangePair{salt: keccak256(abi.encode(poolKey.tokenA, poolKey.tokenB, poolKey.fee))}()
            );
            getPool[vars.pair] = vars.pool;
            getPair[vars.pool] = vars.pair;
            _updateOracle(vars, oracle.observationCardinality);
        }
    }

    function _updateOracle(FullRangeLibrary.Vars memory vars, uint16 observationCardinality) internal {
        if (vars.observationCardinalityNext < observationCardinality) {
            IUniswapV3Pool(vars.pool).increaseObservationCardinalityNext(vars.observationCardinalityNext);
        }
    }

    function _addLiquidity(
        PoolKey memory poolKey,
        FullRangeLibrary.Vars memory vars,
        address from,
        uint128 liquidity
    ) internal returns (uint256 amount0, uint256 amount1) {
        if (liquidity != 0) {
            return
                IUniswapV3Pool(vars.pool).mint(
                    address(this),
                    vars.tickLower,
                    vars.tickUpper,
                    liquidity,
                    abi.encode(MintCallbackData(poolKey, from))
                );
        }
    }

    function _collect(FullRangeLibrary.Vars memory vars)
        internal
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        IUniswapV3Pool(vars.pool).burn(vars.tickLower, vars.tickUpper, 0);
        (amount0, amount1) = IUniswapV3Pool(vars.pool).collect(
            address(this),
            vars.tickLower,
            vars.tickUpper,
            type(uint128).max,
            type(uint128).max
        );
        return
            LiquidityAmounts.getLiquidityAmountsForAmounts(
                vars.sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(vars.tickLower),
                TickMath.getSqrtRatioAtTick(vars.tickUpper),
                amount0,
                amount1
            );
    }

    function _removeLiquidity(
        FullRangeLibrary.Vars memory vars,
        address to,
        uint128 liquidity
    ) internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IUniswapV3Pool(vars.pool).burn(vars.tickLower, vars.tickUpper, liquidity);
        (amount0, amount1) = IUniswapV3Pool(vars.pool).collect(
            to,
            vars.tickLower,
            vars.tickUpper,
            uint128(amount0),
            uint128(amount1)
        );
    }

    function _mint(
        FullRangeLibrary.Vars memory vars,
        address to,
        uint128 liquidity
    ) internal returns (uint256 shares) {
        uint256 totalSupply = FullRangePair(vars.pair).totalSupply();
        (uint128 totalLiquidity, , , , ) = IUniswapV3Pool(vars.pool).positions(
            keccak256(abi.encodePacked(address(this), vars.tickLower, vars.tickUpper))
        );
        if (totalSupply == 0 || totalLiquidity == 0) {
            shares = liquidity;
        } else {
            shares = (liquidity * totalSupply) / totalLiquidity;
        }
        FullRangePair(vars.pair).mint(to, shares);
    }

    function _burn(
        FullRangeLibrary.Vars memory vars,
        address from,
        uint256 shares
    ) internal returns (uint128 liquidity) {
        (uint128 totalLiquidity, , , , ) = IUniswapV3Pool(vars.pool).positions(
            keccak256(abi.encodePacked(address(this), vars.tickLower, vars.tickUpper))
        );
        uint256 _liquidity = (shares * totalLiquidity) / FullRangePair(vars.pair).totalSupply();
        // SafeCast to uint128
        require(_liquidity <= type(uint128).max);
        liquidity = uint128(_liquidity);
        FullRangePair(vars.pair).burn(from, shares);
    }

    function _pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (payer == address(this)) {
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }

    function _canCollect(Oracle memory _oracle, FullRangeLibrary.Vars memory vars) internal view returns (bool) {
        int24 twap = OracleLibrary.consult(
            vars.pool,
            _oracle.secondsAgo,
            vars.tick,
            vars.observationIndex,
            vars.observationCardinality
        );
        if ((vars.tick > twap ? vars.tick - twap : twap - vars.tick) > _oracle.maxTickDeviation) {
            return false;
        }
        return true;
    }
}
