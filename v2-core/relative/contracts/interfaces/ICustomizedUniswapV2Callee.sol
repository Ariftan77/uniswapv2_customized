// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title ICustomizedUniswapV2Callee
 * @notice Interface for flash swap callback - Contracts must implement this to receive flash swaps
 * @dev Upgraded to Solidity 0.8.28 for better security and gas optimization
 *
 * FLASH SWAP EXPLANATION:
 * - Flash swaps allow borrowing tokens from the pair without upfront collateral
 * - The pair calls uniswapV2Call() on the recipient during the swap
 * - Recipient can use borrowed tokens for arbitrage, liquidations, etc.
 * - Must repay the loan + fee in the same transaction or it reverts
 *
 * SECURITY WARNING:
 * - Only implement if you understand flash swap mechanics
 * - Always verify msg.sender is a legitimate Uniswap pair
 * - Beware of reentrancy attacks
 *
 * EXAMPLE USE CASES:
 * - Arbitrage: Borrow token A, swap on another DEX, repay with profit
 * - Liquidations: Borrow collateral, liquidate position, repay loan
 * - Collateral swaps: Change collateral type without closing position
 */
interface ICustomizedUniswapV2Callee {
    /// @notice Callback function called during flash swaps
    /// @param sender Address that initiated the swap (msg.sender of the swap call)
    /// @param amount0 Amount of token0 sent to this contract
    /// @param amount1 Amount of token1 sent to this contract
    /// @param data Arbitrary data passed from the swap caller
    /// @dev This function is called by the pair contract during swap()
    ///      You MUST repay the borrowed amount + fee before this function returns
    ///      Otherwise the transaction will revert due to K invariant check
    ///
    /// IMPLEMENTATION REQUIREMENTS:
    /// 1. Verify msg.sender is a valid pair from the factory
    /// 2. Use the borrowed tokens (amount0 or amount1)
    /// 3. Send back enough tokens to satisfy: newK >= oldK * 1000^2 / 997^2
    /// 4. Profit is yours to keep!
    ///
    /// EXAMPLE:
    /// function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
    ///     // 1. Verify caller is legitimate pair
    ///     address token0 = IUniswapV2Pair(msg.sender).token0();
    ///     address token1 = IUniswapV2Pair(msg.sender).token1();
    ///     require(msg.sender == IUniswapV2Factory(factory).getPair(token0, token1));
    ///
    ///     // 2. Use borrowed tokens (e.g., arbitrage on another DEX)
    ///     if (amount0 > 0) {
    ///         // Do something with token0
    ///     }
    ///
    ///     // 3. Repay the loan + 0.3% fee
    ///     uint256 amountToRepay = amount0 * 1000 / 997; // Add 0.3% fee
    ///     IERC20(token0).transfer(msg.sender, amountToRepay);
    /// }
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
