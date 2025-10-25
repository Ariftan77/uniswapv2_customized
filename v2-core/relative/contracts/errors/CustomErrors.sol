// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title CustomErrors
 * @notice Gas-efficient custom errors for the DEX
 * @dev Custom errors save ~90% gas compared to require() strings
 */

// ============ Factory Errors ============

/// @notice Thrown when trying to create a pair with identical tokens
/// @param token The token address that was duplicated
error IdenticalAddresses(address token);

/// @notice Thrown when token address is zero
error ZeroAddress();

/// @notice Thrown when pair already exists
/// @param token0 First token address
/// @param token1 Second token address
/// @param existingPair Address of existing pair
error PairExists(address token0, address token1, address existingPair);

/// @notice Thrown when caller is not authorized
/// @param caller Address that attempted the action
/// @param required Address that is required
error Forbidden(address caller, address required);

// ============ Pair Errors ============

/// @notice Thrown when output amount is insufficient
/// @param amountOut Actual output amount
/// @param minAmountOut Minimum required amount
error InsufficientOutputAmount(uint256 amountOut, uint256 minAmountOut);

/// @notice Thrown when liquidity is insufficient
/// @param available Available liquidity
/// @param required Required liquidity
error InsufficientLiquidity(uint256 available, uint256 required);

/// @notice Thrown when trying to mint insufficient liquidity
/// @param liquidity Amount of liquidity minted
error InsufficientLiquidityMinted(uint256 liquidity);

/// @notice Thrown when trying to burn insufficient liquidity
/// @param liquidity Amount of liquidity to burn
error InsufficientLiquidityBurned(uint256 liquidity);

/// @notice Thrown when balance overflows uint112
/// @param balance The balance that overflowed
error BalanceOverflow(uint256 balance);

/// @notice Thrown when recipient address is invalid
/// @param to The invalid recipient address
error InvalidRecipient(address to);

/// @notice Thrown when input amount is insufficient
error InsufficientInputAmount();

/// @notice Thrown when K invariant check fails
/// @param k0 Initial K value
/// @param k1 Final K value
error KInvariantViolation(uint256 k0, uint256 k1);

/// @notice Thrown when function is locked (reentrancy guard)
error Locked();

// ============ ERC20 Errors ============

/// @notice Thrown when transfer amount exceeds balance
/// @param from Sender address
/// @param balance Available balance
/// @param amount Transfer amount
error InsufficientBalance(address from, uint256 balance, uint256 amount);

/// @notice Thrown when allowance is insufficient
/// @param owner Token owner
/// @param spender Spender address
/// @param allowance Current allowance
/// @param amount Required amount
error InsufficientAllowance(address owner, address spender, uint256 allowance, uint256 amount);

// ============ Permit Errors ============

/// @notice Thrown when permit signature has expired
/// @param deadline Signature deadline
/// @param currentTime Current block timestamp
error PermitExpired(uint256 deadline, uint256 currentTime);

/// @notice Thrown when permit signature is invalid
/// @param signer Recovered signer address
/// @param owner Expected owner address
error InvalidSignature(address signer, address owner);

// ============ Router Errors ============

/// @notice Thrown when deadline has passed
/// @param deadline Transaction deadline
/// @param currentTime Current block timestamp
error DeadlineExpired(uint256 deadline, uint256 currentTime);

/// @notice Thrown when path is invalid
error InvalidPath();

/// @notice Thrown when amount is below minimum
/// @param amount Actual amount
/// @param minAmount Minimum required amount
error InsufficientAmount(uint256 amount, uint256 minAmount);

/// @notice Thrown when excessive input is required
/// @param amount Required input amount
/// @param maxAmount Maximum allowed amount
error ExcessiveInputAmount(uint256 amount, uint256 maxAmount);