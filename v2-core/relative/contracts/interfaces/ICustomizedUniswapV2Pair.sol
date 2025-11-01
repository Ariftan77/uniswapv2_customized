// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import './ICustomizedUniswapV2ERC20.sol';

/**
 * @title ICustomizedUniswapV2Pair
 * @notice Interface for the Pair contract - the core AMM liquidity pool
 * @dev Upgraded to Solidity 0.8.28 for better security and gas optimization
 *      Combines ERC20 functionality with AMM trading logic
 */
interface ICustomizedUniswapV2Pair is ICustomizedUniswapV2ERC20 {
    // ============ AMM Events ============

    /// @notice Emitted when liquidity is added
    /// @param sender Address that added liquidity
    /// @param amount0 Amount of token0 deposited
    /// @param amount1 Amount of token1 deposited
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    /// @notice Emitted when liquidity is removed
    /// @param sender Address that removed liquidity
    /// @param amount0 Amount of token0 withdrawn
    /// @param amount1 Amount of token1 withdrawn
    /// @param to Recipient of tokens
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);

    /// @notice Emitted when a swap occurs
    /// @param sender Address that initiated swap
    /// @param amount0In Amount of token0 sent to pair
    /// @param amount1In Amount of token1 sent to pair
    /// @param amount0Out Amount of token0 sent from pair
    /// @param amount1Out Amount of token1 sent from pair
    /// @param to Recipient of output tokens
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    /// @notice Emitted when reserves are updated
    /// @param reserve0 New reserve of token0
    /// @param reserve1 New reserve of token1
    event Sync(uint112 reserve0, uint112 reserve1);

    // ============ AMM State Functions ============

    /// @notice Minimum liquidity locked forever on first mint
    /// @return Always returns 1000 wei
    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    /// @notice Address of the factory that created this pair
    /// @return Factory address
    function factory() external view returns (address);

    /// @notice Address of the first token (lower address)
    /// @return Token0 address
    function token0() external view returns (address);

    /// @notice Address of the second token (higher address)
    /// @return Token1 address
    function token1() external view returns (address);

    /// @notice Get current reserves and last update timestamp
    /// @return reserve0 Reserve of token0
    /// @return reserve1 Reserve of token1
    /// @return blockTimestampLast Timestamp of last reserve update
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    /// @notice Cumulative price of token0 (for TWAP oracle)
    /// @return Cumulative price
    function price0CumulativeLast() external view returns (uint256);

    /// @notice Cumulative price of token1 (for TWAP oracle)
    /// @return Cumulative price
    function price1CumulativeLast() external view returns (uint256);

    /// @notice Product of reserves as of last liquidity event (for protocol fee calculation)
    /// @return k value (reserve0 * reserve1)
    function kLast() external view returns (uint256);

    // ============ Dynamic Fee State ============

    /// @notice Current fee tier for this pair (in basis points)
    /// @return Fee tier (e.g., 1 = 0.01%, 30 = 0.3%, 100 = 1%)
    function feeTier() external view returns (uint24);

    /// @notice Current volatility score (0-100)
    /// @return Volatility score
    function volatility() external view returns (uint8);

    /// @notice Timestamp of last volatility update
    /// @return Last update timestamp
    function lastVolatilityUpdate() external view returns (uint32);

    /// @notice Current index in observations circular buffer
    /// @return Index value (0-23)
    function observationIndex() external view returns (uint8);

    /// @notice Number of observations recorded so far
    /// @return Count value (0-24)
    function observationCount() external view returns (uint8);

    // ============ AMM Actions ============

    /// @notice Add liquidity to the pool
    /// @param to Recipient of LP tokens
    /// @return liquidity Amount of LP tokens minted
    function mint(address to) external returns (uint256 liquidity);

    /// @notice Remove liquidity from the pool
    /// @param to Recipient of underlying tokens
    /// @return amount0 Amount of token0 returned
    /// @return amount1 Amount of token1 returned
    function burn(address to) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap tokens
    /// @param amount0Out Amount of token0 to receive
    /// @param amount1Out Amount of token1 to receive
    /// @param to Recipient of output tokens
    /// @param data Calldata for flash swap callback
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;

    /// @notice Force balances to match reserves (remove excess tokens)
    /// @param to Recipient of excess tokens
    function skim(address to) external;

    /// @notice Force reserves to match balances (sync after direct transfer)
    function sync() external;

    // ============ Dynamic Fee Management ============

    /// @notice Update volatility score and adjust fee tier if needed
    /// @dev Can be called by anyone, updates once per 24 hours
    function updateVolatility() external;

    /// @notice Get current price of token1 per token0
    /// @return price Current price (scaled by 1e18)
    function getCurrentPrice() external view returns (uint256 price);

    // ============ Initialization ============

    /// @notice Initialize the pair with token addresses (called once by factory)
    /// @param token0Address Address of token0
    /// @param token1Address Address of token1
    function initialize(address token0Address, address token1Address) external;

    // ============ Dynamic Fee Events ============

    /// @notice Emitted when fee tier is updated due to volatility change
    /// @param oldFeeTier Previous fee tier (basis points)
    /// @param newFeeTier New fee tier (basis points)
    /// @param newVolatility Updated volatility score (0-100)
    event FeeTierUpdated(uint24 indexed oldFeeTier, uint24 indexed newFeeTier, uint8 newVolatility);

    /// @notice Emitted when a new observation is recorded for TWAP oracle
    /// @param timestamp When the observation was recorded
    /// @param price0Cumulative Cumulative price of token0 at this time
    /// @param price1Cumulative Cumulative price of token1 at this time
    event ObservationRecorded(uint32 indexed timestamp, uint256 price0Cumulative, uint256 price1Cumulative);
}
