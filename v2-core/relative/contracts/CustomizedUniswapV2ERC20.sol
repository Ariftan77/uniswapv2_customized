// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import './interfaces/ICustomizedUniswapV2ERC20.sol';

/**
 * @title CustomizedUniswapV2ERC20
 * @notice This contract represents the LP (Liquidity Provider) tokens that users receive when providing liquidity
 *
 * USE CASE: When you add liquidity to a pool (e.g., ETH/USDC), you receive LP tokens that represent your
 * share of the pool. These LP tokens are ERC20 tokens that you can transfer, hold, or burn to withdraw liquidity.
 *
 * KEY INNOVATION: Implements EIP-2612 "permit" - allows gasless approvals via off-chain signatures!
 * Instead of: approve() → swap() (2 transactions)
 * You can: Just swap() with a signature (1 transaction, no ETH needed for approval)
 */
contract CustomizedUniswapV2ERC20 is ICustomizedUniswapV2ERC20 {

    // ============ ERC20 Standard Token Metadata ============
    string public constant name = 'Uniswap V2';
    string public constant symbol = 'UNI-V2';      // Each pair has the same symbol
    uint8 public constant decimals = 18;           // Standard for most ERC20 tokens
    uint256  public totalSupply;                      // Total LP tokens minted (grows when liquidity added)
    mapping(address => uint256) public balanceOf;     // How many LP tokens each address owns
    mapping(address => mapping(address => uint256)) public allowance; // Who can spend your tokens

    // ============ EIP-2612 Permit (Gasless Approval) ============
    // DOMAIN_SEPARATOR: Unique identifier for this contract on this chain (prevents replay attacks)
    bytes32 public DOMAIN_SEPARATOR;

    // PERMIT_TYPEHASH: The structure of the permit message (standardized by EIP-2612)
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    // nonces: Counter for each address to prevent signature replay attacks
    // Each time you use permit(), your nonce increments
    mapping(address => uint256) public nonces;

    /**
     * @notice Constructor - Sets up EIP-712 domain separator for permit functionality
     * @dev Called only once when the Pair contract is deployed
     *
     * WHY: The DOMAIN_SEPARATOR prevents someone from taking a signature from one chain/contract
     * and replaying it on another. It's unique to this contract + this blockchain.
     */
    constructor(){
        uint256 chainId = block.chainid; // Updated way to get chain ID in Solidity 0.8.x

        // Create unique domain separator: hash of (contract name, version, chain, address)
        // This makes signatures valid ONLY for this specific contract on this specific chain
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),        // "Uniswap V2"
                keccak256(bytes('1')),         // Version "1"
                chainId,                       // e.g., 1 for Mainnet, 5 for Goerli
                address(this)                  // This contract's address
            )
        );
    }

    // ============ Internal Functions (Only called by Pair contract) ============

    /**
     * @notice Mint new LP tokens
     * @param to Address receiving the LP tokens
     * @param value Amount of LP tokens to mint
     *
     * USE CASE: Called by Pair.mint() when someone adds liquidity
     * Example: You deposit 1 ETH + 2000 USDC → you receive 44.7 LP tokens
     *
     * WHY MINT FROM address(0): Standard ERC20 convention - minting is a "transfer from nowhere"
     */
    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply + value;     // Increase total supply
        balanceOf[to] = balanceOf[to] + value; // Credit tokens to recipient
        emit Transfer(address(0), to, value);  // Emit transfer from zero address
    }

    /**
     * @notice Burn LP tokens (destroy them)
     * @param from Address whose LP tokens are being burned
     * @param value Amount of LP tokens to burn
     *
     * USE CASE: Called by Pair.burn() when someone removes liquidity
     * Example: You burn 44.7 LP tokens → you get back 1 ETH + 2000 USDC
     *
     * WHY BURN TO address(0): Standard ERC20 convention - burning is a "transfer to nowhere"
     */
    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from] - value; // Deduct tokens from holder
        totalSupply = totalSupply - value;         // Decrease total supply
        emit Transfer(from, address(0), value);       // Emit transfer to zero address
    }

    /**
     * @notice Internal approval function
     * @param owner Token owner granting approval
     * @param spender Address being approved to spend tokens
     * @param value Amount approved to spend
     */
    function _approve(address owner, address spender, uint256 value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @notice Internal transfer function
     * @param from Address sending tokens
     * @param to Address receiving tokens
     * @param value Amount to transfer
     *
     * SECURITY: Uses SafeMath.sub() which reverts if sender doesn't have enough balance
     */
    function _transfer(address from, address to, uint256 value) private {
        balanceOf[from] = balanceOf[from] - value; // Will revert if insufficient balance
        balanceOf[to] = balanceOf[to] + value;
        emit Transfer(from, to, value);
    }

    // ============ Public ERC20 Functions ============

    /**
     * @notice Approve someone to spend your LP tokens
     * @param spender Address being approved (e.g., Router contract)
     * @param value Amount of LP tokens they can spend
     * @return bool Always returns true
     *
     * USE CASE: Before removing liquidity through Router, you must approve Router to spend your LP tokens
     * Example: approve(RouterAddress, 100 LP tokens) → Router can now burn your LP tokens to return ETH+USDC
     */
    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice Transfer LP tokens to another address
     * @param to Recipient address
     * @param value Amount of LP tokens to transfer
     * @return bool Always returns true
     *
     * USE CASE: You can send LP tokens to someone else (they now own your share of the pool)
     * Example: transfer(friendAddress, 10 LP tokens) → Friend can now withdraw their share of liquidity
     */
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @notice Transfer LP tokens on behalf of someone else (requires prior approval)
     * @param from Token owner address
     * @param to Recipient address
     * @param value Amount to transfer
     * @return bool Always returns true
     *
     * ============ HOW IT WORKS ============
     *
     * This function lets someone spend YOUR tokens IF you previously approved them.
     *
     * STEP 1: You approve someone
     * STEP 2: They call transferFrom() to spend your tokens
     *
     * ============ EXAMPLE 1: Normal Approval (Most Common) ============
     *
     * Scenario: You want to remove liquidity via Uniswap Router
     *
     * 1. You own 100 LP tokens
     * 2. You call: approve(RouterAddress, 50)
     *    → allowance[you][Router] = 50
     *
     * 3. Router calls: transferFrom(you, RouterAddress, 30)
     *    → Checks: allowance[you][Router] != type(uint256).max → TRUE (it's 50)
     *    → Decreases allowance: 50 - 30 = 20
     *    → allowance[you][Router] = 20
     *    → Transfers 30 LP tokens from you to Router
     *
     * 4. Now Router can still spend 20 more LP tokens
     *
     * ============ EXAMPLE 2: Infinite Approval (Gas Optimization) ============
     *
     * Scenario: You trust Router forever, don't want to approve every time
     *
     * type(uint256).max = 2^256 - 1 = 115792089237316195423570985008687907853269984665640564039457584007913129639935
     * (This is the MAXIMUM possible value for uint256 - essentially "unlimited")
     *
     * 1. You own 100 LP tokens
     * 2. You call: approve(RouterAddress, type(uint256).max)  // Infinite approval!
     *    → allowance[you][Router] = 115792089237316195423570985008687907853269984665640564039457584007913129639935
     *
     * 3. Router calls: transferFrom(you, RouterAddress, 30)
     *    → Checks: allowance[you][Router] != type(uint256).max → FALSE (it IS type(uint256).max)
     *    → SKIPS the allowance decrease! ⛽ Saves gas!
     *    → allowance[you][Router] STAYS at type(uint256).max
     *    → Transfers 30 LP tokens from you to Router
     *
     * 4. Router can STILL spend unlimited tokens (allowance is still type(uint256).max)
     *
     * WHY THIS OPTIMIZATION?
     * - Writing to storage costs ~5,000 gas (expensive!)
     * - If allowance is infinite, we skip the storage write
     * - Router can be used forever without re-approving
     * - Common pattern: Many users approve max once, use forever
     *
     * ============ EXAMPLE 3: Insufficient Allowance (Reverts) ============
     *
     * 1. You own 100 LP tokens
     * 2. You call: approve(RouterAddress, 20)
     *    → allowance[you][Router] = 20
     *
     * 3. Router calls: transferFrom(you, RouterAddress, 50)
     *    → Checks: allowance[you][Router] != type(uint256).max → TRUE (it's 20)
     *    → Tries: 20 - 50 = ??? → SafeMath REVERTS! ❌
     *    → Transaction fails: "ds-math-sub-underflow"
     *
     * ============ REAL WORLD FLOW ============
     *
     * Let's say you want to remove liquidity:
     *
     * WITHOUT INFINITE APPROVAL (2 transactions per removal):
     * 1. You: approve(Router, 100 LP)       → Pay gas ⛽
     * 2. Router: transferFrom(you, Router, 100) → Pay gas ⛽
     * 3. Next time you want to remove liquidity:
     *    → You: approve(Router, 50 LP)      → Pay gas AGAIN ⛽
     *    → Router: transferFrom(...)        → Pay gas AGAIN ⛽
     *
     * WITH INFINITE APPROVAL (1 transaction, then free forever):
     * 1. You: approve(Router, type(uint256).max)     → Pay gas ONCE ⛽
     * 2. Router: transferFrom(you, Router, 100) → Pay gas ⛽
     * 3. Next time:
     *    → Router: transferFrom(...)        → Slightly cheaper! (no allowance write)
     * 4. Future times:
     *    → Router: transferFrom(...)        → Still works! No re-approval needed
     *
     * SECURITY NOTE:
     * - Infinite approval is RISKY if you don't trust the contract
     * - If Router has a bug or gets hacked, attacker can spend ALL your tokens
     * - Only do infinite approval for well-audited, trusted contracts
     * - Uniswap Router is trusted (audited + used by millions)
     *
     * ============ IMPORTANT CLARIFICATIONS ============
     *
     * Q1: "Does infinite approval let Router spend until my balance is 0?"
     * A1: YES! Router can spend ALL your tokens until balance = 0
     *     - allowance is "permission to spend"
     *     - balance is "what you actually own"
     *     - Router can spend up to your BALANCE (not allowance number)
     *
     * Q2: "What happens when my balance reaches 0?"
     * A2: transferFrom will REVERT because _transfer checks your balance:
     *
     *     Your balance: 0 LP tokens
     *     Your allowance: still shows type(uint256).max
     *
     *     Router tries: transferFrom(you, router, 10)
     *     → Goes to _transfer(you, router, 10)
     *     → _transfer tries: balanceOf[you] = 0 - 10
     *     → SafeMath.sub REVERTS! ❌ "ds-math-sub-underflow"
     *     → Transaction fails
     *
     * Q3: "Why does allowance still show type(uint256).max even after spending?"
     * A3: Because we NEVER decrease it! That's the whole point of the optimization:
     *
     *     allowance = "permission amount" (always stays type(uint256).max)
     *     balance = "actual tokens you have" (decreases as you spend)
     *
     *     Think of it like this:
     *     - allowance = "You can spend UP TO this much"
     *     - balance = "This is what actually exists to spend"
     *
     *     The REAL limit is ALWAYS your balance, not allowance!
     *
     * ============ STEP-BY-STEP EXAMPLE ============
     *
     * Initial State:
     *   balanceOf[You] = 100 LP
     *   allowance[You][Router] = type(uint256).max
     *
     * Transaction 1: Router.transferFrom(You, Router, 30)
     *   → Check allowance: type(uint256).max ✓
     *   → Skip allowance decrease
     *   → _transfer checks: balanceOf[You] = 100 - 30 = 70 ✓
     *   Result:
     *     balanceOf[You] = 70 LP ← DECREASED
     *     allowance[You][Router] = type(uint256).max ← UNCHANGED
     *
     * Transaction 2: Router.transferFrom(You, Router, 50)
     *   → Check allowance: type(uint256).max ✓
     *   → Skip allowance decrease
     *   → _transfer checks: balanceOf[You] = 70 - 50 = 20 ✓
     *   Result:
     *     balanceOf[You] = 20 LP ← DECREASED
     *     allowance[You][Router] = type(uint256).max ← STILL UNCHANGED
     *
     * Transaction 3: Router.transferFrom(You, Router, 30)
     *   → Check allowance: type(uint256).max ✓ (permission is ok)
     *   → Skip allowance decrease
     *   → _transfer checks: balanceOf[You] = 20 - 30 = ???
     *   → SafeMath.sub REVERTS! ❌ "Can't subtract 30 from 20!"
     *   Result:
     *     Transaction FAILS
     *     balanceOf[You] = 20 LP (unchanged, transaction reverted)
     *     allowance[You][Router] = type(uint256).max (still infinite!)
     *
     * KEY TAKEAWAY:
     * - Allowance is just PERMISSION (can stay infinite forever)
     * - Balance is the REAL LIMIT (what actually exists)
     * - You can't spend more than your balance, regardless of allowance!
     * - _transfer ALWAYS checks balance and reverts if insufficient
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        // Only decrease allowance if it's not infinite approval
        // type(uint256).max in Solidity 0.8.28 = max uint256 = "infinity"
        if (allowance[from][msg.sender] != type(uint256).max) {
            // Normal case: Decrease the allowance by amount being spent
            // Will revert via SafeMath if trying to spend more than approved
            allowance[from][msg.sender] = allowance[from][msg.sender] - value;
        }
        // If allowance IS type(uint256).max, we skip the decrease → stays infinite → saves gas!

        // Execute the transfer (works the same in both cases)
        // IMPORTANT: _transfer will check balanceOf[from] and revert if insufficient!
        // So even with infinite allowance, you can only spend what you actually have.
        _transfer(from, to, value);
        return true;
    }

    // ============ EIP-2612 Permit (Gasless Approval) ============

    /**
     * @notice Approve tokens via signature instead of transaction (GASLESS!)
     * @param owner Address granting approval (signs the message off-chain)
     * @param spender Address being approved to spend tokens
     * @param value Amount approved to spend
     * @param deadline Timestamp when signature expires
     * @param v ECDSA signature component
     * @param r ECDSA signature component
     * @param s ECDSA signature component
     *
     * ⭐ THIS IS THE INNOVATION! ⭐
     *
     * TRADITIONAL FLOW (2 transactions, user needs ETH for gas):
     * 1. User: approve(Router, 100 LP) → costs gas ⛽
     * 2. User: Router.removeLiquidity() → costs gas ⛽
     *
     * PERMIT FLOW (1 transaction, no ETH needed for approval!):
     * 1. User: Signs message off-chain (free, happens in wallet) ✍️
     * 2. Anyone: Calls removeLiquidity() with signature → only 1 gas payment ⛽
     *
     * USE CASE EXAMPLE:
     * - You want to remove liquidity but only have LP tokens (no ETH for gas)
     * - You sign a permit message off-chain with your wallet
     * - A relayer (or the dApp) submits the transaction for you
     * - Your approval happens gaslessly!
     *
     * SECURITY:
     * - Signature includes: owner, spender, value, nonce, deadline
     * - nonce prevents replay attacks (increments after each use)
     * - deadline prevents old signatures from being valid forever
     * - DOMAIN_SEPARATOR prevents cross-chain/cross-contract replay
     */
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        // Check signature hasn't expired
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');

        // Reconstruct the message that was signed
        // EIP-712 format: "\x19\x01" + domainSeparator + structHash
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',                    // EIP-191 header
                DOMAIN_SEPARATOR,              // Unique to this contract + chain
                keccak256(abi.encode(
                    PERMIT_TYPEHASH,           // Standard permit structure
                    owner,                     // Who is granting approval
                    spender,                   // Who is being approved
                    value,                     // How much they can spend
                    nonces[owner]++,           // Current nonce (prevents replay) - increments after use!
                    deadline                   // When this signature expires
                ))
            )
        );

        // Recover the address that signed this message
        address recoveredAddress = ecrecover(digest, v, r, s);

        // Verify the signature is valid and from the claimed owner
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');

        // Approval is granted! 🎉
        _approve(owner, spender, value);
    }
}

/**
 * ============ SUMMARY ============
 *
 * This contract is the FOUNDATION of Uniswap V2's LP tokens. It's inherited by CustomizedUniswapV2Pair.
 *
 * KEY CONCEPTS:
 * 1. LP Tokens = Your receipt for providing liquidity
 *    - You deposit tokens → Get LP tokens
 *    - You burn LP tokens → Get tokens back
 *
 * 2. Standard ERC20 = You can transfer, trade, hold LP tokens like any token
 *
 * 3. EIP-2612 Permit = The INNOVATION that makes UX better
 *    - No need for separate approval transaction
 *    - Can approve via signature (gasless)
 *    - Enables meta-transactions and better UX
 *
 * REAL WORLD EXAMPLE:
 * - You add 1 ETH + 2000 USDC to pool → Receive 44.7213 LP tokens
 * - LP tokens represent your ~0.1% ownership of the pool
 * - Pool earns fees → Your share grows automatically
 * - Later: Burn 44.7213 LP → Get back ~1.003 ETH + 2006 USDC (profit from fees!)
 */
