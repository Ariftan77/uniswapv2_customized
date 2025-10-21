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

    // ============ Initialization ============

    /// @notice Initialize the pair with token addresses (called once by factory)
    /// @param token0Address Address of token0
    /// @param token1Address Address of token1
    function initialize(address token0Address, address token1Address) external;
}
