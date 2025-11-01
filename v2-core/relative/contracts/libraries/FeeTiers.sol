// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title FeeTiers
 * @notice Dynamic fee tier system for different pair types
 */
 library FeeTiers {
    // Fee tier constants (in basis points, 1 bp = 0.01%)
    uint24 public constant FEE_ULTRA_LOW = 1;      // 0.01% for stablecoins
    uint24 public constant FEE_VERY_LOW = 5;       // 0.05% for major pairs
    uint24 public constant FEE_LOW = 10;           // 0.10% for established tokens
    uint24 public constant FEE_MEDIUM = 30;        // 0.30% for standard pairs (original Uniswap)
    uint24 public constant FEE_HIGH = 100;         // 1.00% for volatile/risky pairs

    // Fee denominator (10000 = 100%)
    uint24 public constant FEE_DENOMINATOR = 10000;

    /**
     * @notice Get fee tier for a token pair
     * @param token0 First token address
     * @param token1 Second token address
     * @param volatility Volatility score (0-100)
     * @return feeTier Fee in basis points
     */
     function getFeeTier(address token0, address token1, uint8 volatility) internal pure returns (uint24 feeTier) {
        if (isStablecoin(token0) && isStablecoin(token1)){
            return FEE_ULTRA_LOW;
        }

        // Check if one token is stablecoin and other is major token (ETH, BTC, BNB)
        if (
            (isStablecoin(token0) && isMajorToken(token1)) ||
            (isStablecoin(token1) && isMajorToken(token0))
        ) {
            return FEE_VERY_LOW;  // 0.05%
        }

        // Check volatility
        if (volatility > 50) {
            return FEE_HIGH;  // 1.00%
        } else if (volatility > 30) {
            return FEE_MEDIUM;  // 0.30%
        } else {
            return FEE_LOW;  // 0.10%
        }        
     }    


    /**
     * @notice Check if token is a stablecoin
     * @dev This is a simplified check - in production, use a registry
     */
    function isStablecoin(address token) internal pure returns (bool) {
        // USDT, USDC, DAI, BUSD, IDRT (Indonesian Rupiah Token)
        // TODO: Replace with actual token addresses on your deployment chain
        return
            token == 0xdAC17F958D2ee523a2206206994597C13D831ec7 || // USDT (Ethereum)
            token == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 || // USDC (Ethereum)
            token == 0x6B175474E89094C44Da98b954EedeAC495271d0F || // DAI (Ethereum)
            token == 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56 || // BUSD (BSC)
            token == 0x6B175474E89094C44Da98b954EedeAC495271d0F;   // IDRT (example)
    }

    /**
     * @notice Check if token is a major token (ETH, BTC, BNB)
     */
    function isMajorToken(address token) internal pure returns (bool) {
        // WETH, WBTC, WBNB
        // TODO: Replace with actual token addresses
        return
            token == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 || // WETH (Ethereum)
            token == 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 || // WBTC (Ethereum)
            token == 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;   // WBNB (BSC)
    }     
 }