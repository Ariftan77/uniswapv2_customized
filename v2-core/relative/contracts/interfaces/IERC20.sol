// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title IERC20
 * @notice Standard ERC20 token interface
 * @dev Upgraded to Solidity 0.8.28 for better security and gas optimization
 *      This is the minimal interface for interacting with ERC20 tokens
 *
 * NOTE: Some tokens (e.g., USDT) don't return bool on transfer/approve
 *       Use SafeERC20 wrapper when interacting with external tokens
 */
interface IERC20 {
    // ============ Events ============

    /// @notice Emitted when allowance is set
    /// @param owner Token owner
    /// @param spender Approved spender
    /// @param value Amount approved
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Emitted when tokens are transferred
    /// @param from Sender address
    /// @param to Recipient address
    /// @param value Amount transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    // ============ Metadata Functions ============

    /// @notice Token name
    /// @return Token name string
    /// @dev Optional in ERC20 spec, but most tokens implement it
    function name() external view returns (string memory);

    /// @notice Token symbol
    /// @return Token symbol string (e.g., "USDC", "WETH")
    /// @dev Optional in ERC20 spec, but most tokens implement it
    function symbol() external view returns (string memory);

    /// @notice Token decimals
    /// @return Number of decimals (usually 18, but can be 6 for USDC/USDT)
    /// @dev Optional in ERC20 spec, but most tokens implement it
    function decimals() external view returns (uint8);

    // ============ Core Functions ============

    /// @notice Total token supply
    /// @return Total tokens in circulation
    function totalSupply() external view returns (uint256);

    /// @notice Get token balance
    /// @param owner Address to check
    /// @return Token balance
    function balanceOf(address owner) external view returns (uint256);

    /// @notice Get allowance
    /// @param owner Token owner
    /// @param spender Approved spender
    /// @return Remaining allowance
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Approve spender
    /// @param spender Address to approve
    /// @param value Amount to approve
    /// @return success True if successful
    /// @dev Some tokens (USDT) require allowance to be 0 before setting new value
    function approve(address spender, uint256 value) external returns (bool success);

    /// @notice Transfer tokens
    /// @param to Recipient address
    /// @param value Amount to transfer
    /// @return success True if successful
    function transfer(address to, uint256 value) external returns (bool success);

    /// @notice Transfer tokens from another address
    /// @param from Sender address
    /// @param to Recipient address
    /// @param value Amount to transfer
    /// @return success True if successful
    /// @dev Requires prior approval
    function transferFrom(address from, address to, uint256 value) external returns (bool success);
}
