// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

address constant HEVM = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
address constant FACTORY = 0x1F98431c8aD98523631AE4a59f267346ea31F984;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

library FeeAmount {
    uint24 internal constant LOWEST = 100;
    uint24 internal constant LOW = 500;
    uint24 internal constant MEDIUM = 3000;
    uint24 internal constant HIGH = 10000;
}
