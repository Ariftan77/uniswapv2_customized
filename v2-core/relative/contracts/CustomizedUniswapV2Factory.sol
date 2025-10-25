// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import './interfaces/ICustomizedUniswapV2Factory.sol';
import './CustomizedUniswapV2Pair.sol';
import './errors/CustomErrors.sol';

/**
 * @title CustomizedUniswapV2Factory
 * @notice The central registry and creator of all trading pairs in the DEX
 *
 * ============ WHAT IS THE FACTORY? ============
 *
 * Think of the Factory as the "main office" of Uniswap:
 * - It creates new trading pairs (ETH/USDC, DAI/USDT, etc.)
 * - It keeps track of all existing pairs
 * - It controls protocol fees
 *
 * ============ KEY RESPONSIBILITIES ============
 *
 * 1. CREATE PAIRS: Deploy new Pair contracts for any two tokens
 * 2. REGISTRY: Track all pairs so users can find them
 * 3. FEE MANAGEMENT: Control where protocol fees go (if enabled)
 *
 * ============ WHY SEPARATE FACTORY & PAIR? ============
 *
 * Design Pattern: Factory creates many instances of Pair
 *
 * Factory (1 contract):
 *   ├─ Creates → Pair for ETH/USDC
 *   ├─ Creates → Pair for DAI/USDT
 *   ├─ Creates → Pair for WBTC/ETH
 *   └─ Creates → Pair for any token combo
 *
 * Benefits:
 * - Permissionless: Anyone can create a pair for any tokens
 * - Consistent: All pairs have same code (deployed from Factory)
 * - Registry: Factory tracks all pairs in one place
 *
 * ============ REAL WORLD ANALOGY ============
 *
 * Factory = McDonald's Corporation HQ
 * Pairs = Individual McDonald's restaurants
 *
 * - HQ decides: franchise rules, fee structure
 * - HQ creates: new restaurant locations
 * - HQ tracks: all restaurant addresses
 * - Each restaurant: operates independently but follows HQ rules
 */
contract CustomizedUniswapV2Factory is ICustomizedUniswapV2Factory {

    // ============ State Variables ============

    /**
     * @notice Address that receives protocol fees (if enabled)
     * @dev If feeTo == address(0), protocol fees are OFF (all fees go to LPs)
     *      If feeTo != address(0), protocol takes 1/6th of LP fees
     *
     * EXAMPLE:
     * - Swap generates 0.30% fee
     * - If feeTo is OFF: 100% goes to liquidity providers
     * - If feeTo is ON: 83.3% to LPs, 16.7% to protocol (feeTo address)
     */
    address public feeTo;

    /**
     * @notice Address that can change feeTo (governance/admin)
     * @dev This is typically a multisig or governance contract
     *      Only feeToSetter can change fee settings (centralized power!)
     */
    address public feeToSetter;

    /**
     * @notice Mapping to find pair address by token addresses
     * @dev getPair[tokenA][tokenB] returns the pair address
     *
     * USAGE:
     * address pairAddress = getPair[USDC][WETH];
     *
     * IMPORTANT: Works both ways!
     * getPair[tokenA][tokenB] == getPair[tokenB][tokenA]
     * (Same pair regardless of token order)
     */
    mapping(address => mapping(address => address)) public getPair;

    /**
     * @notice Array of all pair addresses created by this factory
     * @dev Used to enumerate all pairs
     *
     * USAGE:
     * - allPairs[0] = first pair created
     * - allPairs.length = total number of pairs
     */
    address[] public allPairs;

    // ============ Constructor ============

    /**
     * @notice Deploy the Factory contract
     * @param _feeToSetter Address that will control fee settings
     *
     * DEPLOYMENT:
     * - Called once when Factory is deployed
     * - Sets who has power to enable/disable protocol fees
     * - Usually set to a multisig or governance contract
     *
     * EXAMPLE:
     * Factory factory = new Factory(0x123...); // 0x123 is governance
     */
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    // ============ View Functions ============

    /**
     * @notice Get total number of pairs created
     * @return Total number of pairs
     *
     * USE CASE: Iterate through all pairs
     * for (uint i = 0; i < factory.allPairsLength(); i++) {
     *     address pair = factory.allPairs(i);
     * }
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    // ============ Pair Creation ============

    /**
     * @notice Create a new trading pair for two tokens
     * @param tokenA Address of first token
     * @param tokenB Address of second token
     * @return pair Address of the newly created pair contract
     *
     * ============ WHAT THIS DOES ============
     *
     * Creates a new liquidity pool where users can:
     * - Add liquidity (deposit both tokens, get LP tokens)
     * - Swap between tokens (trade tokenA for tokenB or vice versa)
     * - Remove liquidity (burn LP tokens, get tokens back)
     *
     * ============ EXAMPLE ============
     *
     * factory.createPair(USDC, WETH);
     * → Creates: USDC/WETH pool
     * → Returns: 0xABC... (pair contract address)
     * → Now users can trade USDC ↔ WETH in this pool
     *
     * ============ KEY INNOVATION: CREATE2 ============
     *
     * Uses CREATE2 opcode instead of CREATE:
     * - CREATE: Address depends on deployer's nonce (unpredictable)
     * - CREATE2: Address depends on code + salt (PREDICTABLE!)
     *
     * Benefits of CREATE2:
     * 1. Deterministic addresses: Can calculate pair address off-chain
     * 2. Same pair address across all chains (if same salt)
     * 3. Routers can compute addresses without querying Factory
     *
     * Address = hash(0xFF, factoryAddress, salt, bytecodeHash)
     * salt = hash(token0, token1)
     *
     * ============ STEP-BY-STEP FLOW ============
     */
    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // STEP 1: Validate inputs

        // require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        if (tokenA == tokenB) revert IdenticalAddresses(tokenA);
        // Can't create USDC/USDC pair - makes no sense!

        // STEP 2: Sort tokens by address (lower address first)
        // WHY? Ensures USDC/WETH and WETH/USDC create the SAME pair
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // Example: If WETH < USDC by address, token0 = WETH, token1 = USDC

        // STEP 3: Ensure not zero address
        // require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        if (token0 == address(0)) revert ZeroAddress();
        // If tokenA or tokenB is 0x0, sorted token0 will be 0x0

        // STEP 4: Check pair doesn't already exist
        // require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS');
        if (getPair[token0][token1] != address(0)) revert PairExists(token0, token1, getPair[token0][token1]);
        // Only need to check one direction because we set both below

        // STEP 5: Get Pair contract bytecode
        bytes memory bytecode = type(CustomizedUniswapV2Pair).creationCode;
        // This is the compiled bytecode of the Pair contract

        // STEP 6: Create salt for CREATE2 (makes address deterministic)
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        // salt = hash(WETH, USDC) - unique for each token pair

        // STEP 7: Deploy Pair contract using CREATE2
        assembly {
            // CREATE2 params: value, offset, size, salt
            // value = 0 (no ETH sent)
            // offset = bytecode start (skip 32 bytes length prefix)
            // size = bytecode length
            // salt = our calculated salt
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        // Result: New Pair contract deployed at deterministic address!

        // STEP 8: Initialize the pair with token addresses
        ICustomizedUniswapV2Pair(pair).initialize(token0, token1);
        // Pair now knows which two tokens it manages

        // STEP 9: Register pair in both directions
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // IMPORTANT: works both ways!
        // Now: getPair[WETH][USDC] == getPair[USDC][WETH] == 0xABC...

        // STEP 10: Add to array of all pairs
        allPairs.push(pair);
        // allPairs = [pair1, pair2, pair3, ..., newPair]

        // STEP 11: Emit event for indexers/frontends
        emit PairCreated(token0, token1, pair, allPairs.length);
        // Frontends listen for this to update their pair lists
    }

    // ============ Fee Management (Admin Functions) ============

    /**
     * @notice Set the address that receives protocol fees
     * @param _feeTo Address to receive fees (or 0x0 to disable)
     *
     * ⚠️ ADMIN ONLY: Only feeToSetter can call this
     *
     * ============ HOW PROTOCOL FEES WORK ============
     *
     * Every swap charges 0.30% fee:
     * - If feeTo == 0x0: 100% of fees go to liquidity providers
     * - If feeTo != 0x0: 83.3% to LPs, 16.7% to protocol (feeTo address)
     *
     * EXAMPLE 1: Fees OFF (feeTo = 0x0)
     * - User swaps 1000 USDC → pays 3 USDC fee
     * - All 3 USDC stays in pool → benefits LPs
     *
     * EXAMPLE 2: Fees ON (feeTo = 0x123...)
     * - User swaps 1000 USDC → pays 3 USDC fee
     * - 2.5 USDC to LPs (83.3%)
     * - 0.5 USDC to protocol (16.7% via LP token minting)
     *
     * WHY 1/6th (16.7%)?
     * Math: If LPs get 5/6, protocol gets 1/6
     * This is implemented in Pair._mintFee() function
     *
     * USE CASE:
     * - Governance: setFeeTo(treasuryAddress) // Enable fees
     * - Governance: setFeeTo(0x0) // Disable fees (give all to LPs)
     */
    function setFeeTo(address _feeTo) external {
        // require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        if (msg.sender != feeToSetter) revert Forbidden(msg.sender, feeToSetter);
        feeTo = _feeTo;
    }

    /**
     * @notice Transfer fee control to a new address
     * @param _feeToSetter New address that will control fees
     *
     * ⚠️ ADMIN ONLY: Only current feeToSetter can call this
     *
     * CRITICAL FUNCTION: This transfers governance power!
     *
     * EXAMPLE:
     * - Current feeToSetter: 0xMultisig1
     * - Call: setFeeToSetter(0xMultisig2)
     * - New feeToSetter: 0xMultisig2
     * - 0xMultisig1 loses power, 0xMultisig2 gains it
     *
     * USE CASE:
     * - Upgrade governance contract
     * - Transfer to DAO
     * - Update multisig signers
     *
     * ⚠️ BE CAREFUL: If you set to wrong address, you lose control forever!
     * (No way to recover if you lose access to feeToSetter address)
     */
    function setFeeToSetter(address _feeToSetter) external {
        // require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        if (msg.sender != feeToSetter) revert Forbidden(msg.sender, feeToSetter);

        feeToSetter = _feeToSetter;
    }
}

/**
 * ============ FACTORY SUMMARY ============
 *
 * The Factory is the "command center" of Uniswap V2:
 *
 * KEY FUNCTIONS:
 * 1. createPair() - Deploy new trading pools (permissionless!)
 * 2. getPair() - Find existing pool for any token pair
 * 3. setFeeTo() - Control protocol fee distribution (admin only)
 *
 * DESIGN HIGHLIGHTS:
 * - Uses CREATE2 for deterministic addresses
 * - Anyone can create pairs (permissionless)
 * - Centralized fee control (feeToSetter has power)
 * - Efficient registry (both mapping + array)
 *
 * REAL WORLD FLOW:
 * 1. Someone: factory.createPair(TokenA, TokenB)
 * 2. Factory: Deploys Pair contract at predictable address
 * 3. Users: Can now add liquidity and swap in that Pair
 * 4. Frontend: Queries factory.getPair(TokenA, TokenB) to find it
 * 5. Governance: Can enable protocol fees via setFeeTo()
 *
 * CENTRALIZATION RISK:
 * - feeToSetter has unilateral power to:
 *   - Enable/disable protocol fees
 *   - Change fee recipient
 *   - Transfer governance to new address
 * - Mitigation: Make feeToSetter a multisig or DAO
 */
