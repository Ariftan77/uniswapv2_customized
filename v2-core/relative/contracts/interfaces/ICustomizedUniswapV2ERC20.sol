// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title ICustomizedUniswapV2ERC20
 * @notice Interface for the ERC20 LP token functionality with EIP-2612 permit support
 * @dev Upgraded to Solidity 0.8.28 for better security and gas optimization
 *      Implements standard ERC20 + gasless approvals via signatures (EIP-2612)
 */
interface ICustomizedUniswapV2ERC20 {
    // ============ Events ============

    /// @notice Emitted when allowance is set via approve() or permit()
    /// @param owner Token owner who granted allowance
    /// @param spender Address allowed to spend tokens
    /// @param value Amount approved
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Emitted when tokens are transferred
    /// @param from Sender address
    /// @param to Recipient address
    /// @param value Amount transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    // ============ ERC20 Metadata ============

    /// @notice Name of the LP token
    /// @return Token name (e.g., "Uniswap V2")
    function name() external pure returns (string memory);

    /// @notice Symbol of the LP token
    /// @return Token symbol (e.g., "UNI-V2")
    function symbol() external pure returns (string memory);

    /// @notice Decimals of the LP token
    /// @return Always returns 18
    function decimals() external pure returns (uint8);

    // ============ ERC20 Core Functions ============

    /// @notice Total supply of LP tokens
    /// @return Total tokens in circulation
    function totalSupply() external view returns (uint256);

    /// @notice Get token balance of an address
    /// @param owner Address to check
    /// @return Token balance
    function balanceOf(address owner) external view returns (uint256);

    /// @notice Get allowance for a spender
    /// @param owner Token owner
    /// @param spender Approved spender
    /// @return Remaining allowance
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Approve spender to transfer tokens
    /// @param spender Address to approve
    /// @param value Amount to approve
    /// @return success True if successful
    function approve(address spender, uint256 value) external returns (bool success);

    /// @notice Transfer tokens to another address
    /// @param to Recipient address
    /// @param value Amount to transfer
    /// @return success True if successful
    function transfer(address to, uint256 value) external returns (bool success);

    /// @notice Transfer tokens from another address (requires allowance)
    /// @param from Sender address
    /// @param to Recipient address
    /// @param value Amount to transfer
    /// @return success True if successful
    function transferFrom(address from, address to, uint256 value) external returns (bool success);

    // ============ EIP-2612 Permit (Gasless Approvals) ============

    /// @notice EIP-712 domain separator for signature validation
    /// @return Domain separator hash
    /// @dev Used to prevent signature replay across different chains/contracts
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /// @notice EIP-712 typehash for permit function
    /// @return Permit typehash constant
    function PERMIT_TYPEHASH() external pure returns (bytes32);

    /// @notice Get current nonce for permit signatures
    /// @param owner Address to check nonce
    /// @return Current nonce value
    /// @dev Nonce increments after each successful permit
    function nonces(address owner) external view returns (uint256);

    /// @notice Approve tokens via signature (gasless approval)
    /// @param owner Token owner granting approval
    /// @param spender Address being approved
    /// @param value Amount to approve
    /// @param deadline Signature expiry timestamp
    /// @param v ECDSA signature parameter
    /// @param r ECDSA signature parameter
    /// @param s ECDSA signature parameter
    /// @dev Allows approvals without spending gas (relayer pays gas instead)
    ///      Prevents front-running and enables better UX
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}
