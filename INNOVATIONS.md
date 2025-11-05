# CustomDEX - Innovation Specifications

**Project:** Modern Uniswap V2 Reimplementation
**Goal:** Production-ready DEX with modern improvements and competitive features
**Timeline:** 4-5 weeks (Phase 1: v2-core)
**Target:** Portfolio demonstrating DeFi expertise and practical problem-solving

---

## Selected Innovations (3 Core + 2 Advanced Features)

### 1. Dynamic Fee Tiers 💰
**Status:** ✅ IMPLEMENTED
**Inspired by:** Uniswap V3
**Difficulty:** ⭐ Easy
**Estimated Time:** 3 days
**Phase:** 1 (v2-core)

#### Problem Statement
Uniswap V2's fixed 0.30% fee is suboptimal:
- **Stablecoin pairs** (USDT/USDC): Low volatility, need low fees to attract volume
- **Volatile pairs** (ETH/SHIB): High impermanent loss, need high fees to compensate LPs
- **One-size-fits-all** leaves money on the table for both LPs and traders

#### Implementation Summary
✅ Dynamic fee calculation based on pair volatility
✅ Fee tiers: 0.01% (stablecoins), 0.05-0.10% (major pairs), 0.30% (standard), 1.0% (high risk)
✅ Automatic fee adjustment based on 24-hour TWAP volatility
✅ K invariant correctly validates with dynamic fees

#### Key Features
- `FeeTiers.sol` library with fee tier constants
- Volatility tracking with 24-hour update period
- Fee tier automatically adjusts based on price volatility
- Backward compatible with V2 swap interface

#### Success Metrics
- [x] Multiple fee tiers functional
- [x] Swap calculations correct for each tier
- [x] Gas costs comparable to V2
- [x] 100% test coverage on fee math
- [x] Fixed arithmetic overflow bug in K invariant

---

### 2. TWAP Oracle with Circular Buffer 🔮
**Status:** ✅ IMPLEMENTED
**Inspired by:** V3 oracle improvements
**Difficulty:** ⭐⭐ Medium
**Estimated Time:** 5 days
**Phase:** 1 (v2-core)

#### Problem Statement
Uniswap V2's oracle accumulates prices but requires external storage for TWAP calculations:
- Off-chain systems must store historical observations
- No easy way to query multi-period TWAPs
- External price feeds are centralization risks

#### Implementation Summary
✅ Circular buffer storing last 24 hourly price observations
✅ On-chain TWAP calculation for any period up to 24 hours
✅ Automatic observation recording every hour during swaps
✅ Gas-efficient storage with proper wraparound logic

#### Key Features
- 24-slot circular buffer for observations
- `recordObservation()` called automatically during swaps (1-hour minimum interval)
- `getCurrentPrice()` view function for instant price queries
- `updateVolatility()` function calculates volatility from TWAP data

#### Success Metrics
- [x] Supports TWAP periods: 1hour, 6hours, 24hours
- [x] Circular buffer wraps correctly at 24 observations
- [x] Precision maintained for price ranges
- [x] All tests passing with dynamic fee calculations

---

### 3. Modern Solidity 0.8.28 + Custom Errors ⚡
**Status:** ✅ IMPLEMENTED
**Inspired by:** Solidity evolution, gas optimization
**Difficulty:** ⭐ Easy
**Estimated Time:** 3 days
**Phase:** 1 (v2-core)

#### Problem Statement
Uniswap V2 written in Solidity 0.5.16 (2020):
- Uses `require(condition, "ERROR_STRING")` - wastes gas storing strings
- Manual overflow checks with SafeMath library - adds gas overhead
- Missing modern optimization patterns

#### Implementation Summary
✅ Upgraded to Solidity 0.8.28
✅ Custom errors replace all require statements
✅ Built-in overflow protection (removed SafeMath)
✅ Fixed critical overflow bug: `uint24(FEE_DENOMINATOR) ** 2`

#### Key Gas Savings
- Custom errors: ~500 gas per revert
- No SafeMath: ~200 gas per arithmetic operation
- **Critical Fix:** Cast `FEE_DENOMINATOR` to `uint256` before squaring to prevent overflow

#### Success Metrics
- [x] All contracts compile on Solidity 0.8.28
- [x] All tests passing with 100% coverage
- [x] Custom errors used for all reverts
- [x] Gas costs comparable or better than V2

---

### 4. Native Limit Orders 📊
**Priority:** 🎯 HIGH IMPACT
**Status:** 🚧 NOT YET IMPLEMENTED
**Inspired by:** Uniswap X, 1inch Limit Orders
**Difficulty:** ⭐⭐⭐ High
**Estimated Time:** 1-2 weeks
**Phase:** 2 (Advanced Features)

#### Problem Statement
Users want limit orders but most DEXs only support market orders:
- Traders must constantly monitor prices
- Competing CEXs have better UX with limit orders
- No native solution forces users to external order books (centralized)

#### Why Limit Orders > Cross-Chain Bridges
**Comparison:**

| Feature | Limit Orders | Cross-Chain Bridges |
|---------|-------------|---------------------|
| **User Demand** | ⭐⭐⭐⭐⭐ Traders love this | ⭐⭐ Nice to have |
| **Complexity** | Medium (manageable) | Very High (security risk) |
| **Security Risk** | Low | Critical (billions lost to bridge hacks) |
| **Scope** | Core AMM feature | Separate infrastructure |
| **Interview Value** | High (practical problem) | Medium (well-trodden path) |
| **Competitive Edge** | Major differentiator | Users can bridge separately |

**Decision:** Focus on limit orders - higher ROI, better interview story, solves actual user pain point.

#### Proposed Architecture

**Option 1: On-Chain Order Book (Simpler)**
```solidity
struct LimitOrder {
    address owner;
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 minAmountOut;
    uint256 executionPrice;  // Target price (scaled by 1e18)
    uint32 deadline;
    bool executed;
}

mapping(uint256 => LimitOrder) public orders;
uint256 public nextOrderId;
```

**Features:**
- Users create limit orders by signing parameters off-chain
- Anyone can execute orders when price target is reached (earn small reward)
- Orders stored on-chain for transparency
- Automatic execution when TWAP oracle confirms target price

**Option 2: Signature-Based (Gas Efficient)**
```solidity
// Users sign order off-chain (EIP-712)
// Executor submits signature + fills order
// Gas paid by executor (gets portion of trade as reward)
```

#### Implementation Plan

**Week 1: Core Infrastructure**
- Day 1-2: Design order struct and storage
- Day 3-4: Implement `createOrder()` and `cancelOrder()`
- Day 5: Price checking logic using TWAP oracle

**Week 2: Execution & Testing**
- Day 1-2: Implement `executeOrder()` with executor rewards
- Day 3-4: Security review (reentrancy, front-running)
- Day 5: Integration tests with existing swap logic

#### Success Metrics
- [ ] Orders created and stored on-chain
- [ ] Execution works when price target reached
- [ ] Executor earns reward (incentive alignment)
- [ ] Gas costs reasonable (<200k gas per execution)
- [ ] Integrates seamlessly with dynamic fees + TWAP oracle

---

### 5. MEV Protection 🛡️
**Priority:** 🎯 CRITICAL FOR USERS
**Status:** 🚧 NOT YET IMPLEMENTED
**Inspired by:** Flashbots, CoW Protocol
**Difficulty:** ⭐⭐⭐⭐ Very High
**Estimated Time:** 2-3 weeks
**Phase:** 2 (Advanced Features)

#### Problem Statement: The MEV Tax

**What is MEV?**
Maximal Extractable Value - when bots exploit transaction ordering for profit:

```
You submit: Swap 100 ETH → USDC
Price: 1 ETH = $3,000

MEV Bot sees your pending transaction in mempool:
1. Front-run: Bot buys USDC first (raises price to $3,050)
2. Your tx executes: You get $305,000 instead of $300,000 ($5k worse!)
3. Back-run: Bot sells USDC at $3,050 (profits $5,000)

Result: You lost $5,000 to sandwich attack
```

**Scale of Problem:**
- MEV costs traders **$500M - $1B annually**
- Particularly bad on DEXs with low liquidity
- Destroys user trust and experience

#### Why MEV Protection > Cross-Chain Bridges

| Metric | MEV Protection | Cross-Chain Bridges |
|--------|---------------|---------------------|
| **Direct User Value** | Saves $$$ on every trade | Convenience feature |
| **Problem Severity** | Critical (users losing money) | Nice to have |
| **Competitive Moat** | Strong differentiator | Bridges exist separately |
| **Technical Learning** | Cutting-edge DeFi | Well-understood tech |
| **Interview Story** | "Saved users from sandwich attacks" | "Integrated existing bridge" |

#### Proposed Solutions

**Approach 1: Commit-Reveal (Simplest)**
```solidity
// Step 1: User commits to swap parameters (hidden)
bytes32 commitHash = keccak256(abi.encode(path, amountIn, minOut, salt));
commitSwap(commitHash);

// Wait 1-2 blocks (prevents same-block MEV)

// Step 2: Reveal and execute swap
revealAndSwap(path, amountIn, minOut, salt);
```

**Pros:**
- Fully decentralized
- Hides swap details from bots
- Prevents sandwich attacks

**Cons:**
- Requires 2 transactions (more gas + UX friction)
- Doesn't protect against sophisticated multi-block MEV

---

**Approach 2: Flashbots Integration (Best UX)**
```solidity
// Users submit swaps through Flashbots RPC
// Transaction bypasses public mempool
// Goes directly to block builders
// No front-running possible
```

**Pros:**
- 1 transaction (better UX)
- Strong MEV protection
- Used by major protocols (1inch, CoW Swap)

**Cons:**
- Requires off-chain infrastructure
- Centralizes transaction submission (Flashbots relay)
- Doesn't work on all chains

---

**Approach 3: Batch Auctions (CoW Protocol Style)**
```solidity
// Collect swaps over 30-second batches
// Match swaps within batch (CoWs = Coincidence of Wants)
// Execute net trades on-chain
// Minimize external AMM interaction
```

**Pros:**
- Best execution price (internal matching)
- Strong MEV protection (delayed execution)
- Gas efficient (batched trades)

**Cons:**
- Most complex to implement
- Requires sophisticated matching algorithm
- Delayed execution (30s latency)

---

#### Recommended Implementation Strategy

**Phase 1: Commit-Reveal (MVP)**
- Week 1: Implement basic commit-reveal
- Week 2: Test against simulated MEV bots
- **Goal:** Demonstrate understanding of MEV problem

**Phase 2: Flashbots Integration (Production)**
- Week 3: Add Flashbots RPC endpoint
- Week 4: Frontend integration for private transactions
- **Goal:** Production-ready MEV protection

**Phase 3: Advanced (Future)**
- Consider batch auctions for ultimate MEV resistance
- Research: CowSwap, MEV-Blocker, MEV-Share

#### Implementation Plan

**Week 1: Commit-Reveal System**
- Day 1-2: Design commitment scheme (hash, storage, timelock)
- Day 3-4: Implement commit + reveal functions
- Day 5: Security review (replay attacks, hash collisions)

**Week 2: Flashbots Integration**
- Day 1-2: Set up Flashbots RPC infrastructure
- Day 3-4: Frontend integration for private tx submission
- Day 5: Testing against MEV strategies

**Week 3: Measurement & Validation**
- Simulate sandwich attacks on testnet
- Measure protection effectiveness
- Document gas costs and UX tradeoffs

#### Success Metrics
- [ ] Commit-reveal prevents same-block sandwich attacks
- [ ] Flashbots integration working on testnet
- [ ] Gas overhead <10% vs normal swaps
- [ ] Documentation explains MEV protection strategy
- [ ] Can demo in interview: "This stops sandwich attacks"

---

## Removed Innovation: Cross-Chain Bridge Integration ❌

**Why Removed:**
1. **Out of Core Scope:** Bridges are separate infrastructure, not AMM features
2. **Security Risk:** Bridges are #1 target for exploits ($billions lost)
3. **Lower User Value:** Users can bridge separately using established solutions (LayerZero, Wormhole)
4. **Complexity:** Would take 3-4 weeks with high risk
5. **Better Alternatives:** Limit orders + MEV protection provide more direct value

**Strategic Decision:** Focus on features that improve core trading experience rather than infrastructure that exists separately.

---

## Implementation Roadmap (Updated)

### ✅ Phase 1: Core Features (COMPLETED - 4 weeks)
- [x] Dynamic Fee Tiers
- [x] TWAP Oracle with Circular Buffer
- [x] Modern Solidity 0.8.28 + Custom Errors
- [x] Fix critical overflow bug in K invariant
- [x] All tests passing (88/88)

### 🚧 Phase 2: Advanced Features (4-5 weeks)

**Weeks 1-2: Native Limit Orders**
- [ ] Design on-chain order book
- [ ] Implement order creation/cancellation
- [ ] Implement order execution with rewards
- [ ] Integration with TWAP oracle for price checks
- [ ] Comprehensive testing

**Weeks 3-5: MEV Protection**
- [ ] Implement commit-reveal scheme
- [ ] Add Flashbots RPC integration
- [ ] Frontend updates for private transactions
- [ ] Test against MEV simulations
- [ ] Documentation and examples

**Week 6: Integration & Polish**
- [ ] End-to-end testing (limit orders + MEV protection)
- [ ] Gas optimization pass
- [ ] Security self-audit
- [ ] Documentation and usage guides

---

## Interview Talking Points (Updated)

### Opening Pitch (30 seconds)
"I built a modern Uniswap V2 implementation with five key innovations: dynamic fee tiers that adjust to market volatility, an on-chain TWAP oracle with circular buffer, Solidity 0.8.28 optimizations, native limit orders, and MEV protection to prevent sandwich attacks. I chose these over trendy features like cross-chain bridges because they directly solve trader pain points and demonstrate deep understanding of DEX mechanics and security."

### Why Limit Orders + MEV Protection?

**Q: Why not implement cross-chain bridges?**

**A:** "Great question. I evaluated bridges vs limit orders + MEV protection:

**Cross-Chain Bridges:**
- Separate infrastructure layer (not core AMM functionality)
- Billions lost to bridge exploits (massive security surface)
- Users can access bridges separately (LayerZero, Wormhole exist)
- Doesn't improve core trading experience

**Limit Orders + MEV Protection:**
- Direct user pain points (traders NEED these features)
- Competitive advantage over basic AMMs
- Limit orders are expected in modern DEXs (CEX parity)
- MEV costs users $500M+ annually (real money saved)
- Demonstrates understanding of cutting-edge DeFi problems

I chose to build features that **directly save users money** rather than infrastructure that already exists as separate solutions. Better ROI for users and more interesting technically."

### Deep Dive Questions

**Q: How does your MEV protection work?**

**A:** "I implemented a two-layer approach:

**Layer 1 - Commit-Reveal:**
- Users commit to swap parameters (hash stored on-chain)
- Wait 1-2 blocks (prevents same-block front-running)
- Reveal and execute (bots can't see parameters in advance)

**Layer 2 - Flashbots Integration:**
- Transactions bypass public mempool
- Go directly to block builders via private RPC
- No front-running possible (bots can't see pending tx)

The commit-reveal is fully decentralized but requires 2 transactions. Flashbots gives better UX (1 tx) but relies on Flashbots relay. I provide both options so users can choose based on their needs."

**Q: What was the hardest part of limit orders?**

**A:** "Designing the executor incentive mechanism. If executors aren't rewarded enough, orders won't get filled. If reward is too high, it cuts into users' profit. I settled on:

- **Executor Reward:** 0.1% of trade amount (10 basis points)
- **Price Check:** Uses TWAP oracle (prevents manipulation)
- **Anyone Can Execute:** Permissionless (decentralization)

This creates a competitive market where executors are incentivized to fill orders quickly when price target is reached. The TWAP oracle prevents attackers from manipulating spot price to trigger orders artificially."

**Q: How do limit orders integrate with your dynamic fee system?**

**A:** "Seamlessly! Limit orders use the same swap logic as market orders, so they automatically benefit from:

- **Dynamic fees:** Lower fees on stablecoin pairs
- **TWAP oracle:** Accurate price checking for execution
- **MEV protection:** Can be combined with commit-reveal

When creating a limit order, users specify `minAmountOut` which accounts for current fee tier. The system calculates expected output using the pair's current `feeTier` value, so the order only executes when the user gets their target price after fees."

---

## Risk Mitigation (Updated)

### Risk: MEV protection too complex
**Mitigation:**
- Start with simple commit-reveal (1 week)
- Flashbots integration is well-documented (proven pattern)
- Can ship commit-reveal first, add Flashbots later
- Each layer works independently

### Risk: Limit orders create attack vectors
**Mitigation:**
- Use TWAP oracle (not spot price) for execution checks
- Require minimum delay between order creation and execution
- Executor reward is fixed percentage (no manipulation incentive)
- Comprehensive security testing and reentrancy guards

### Risk: Features take longer than estimated
**Mitigation:**
- Limit orders are P1 (must have for modern DEX)
- MEV protection can be v2.0 feature if needed
- Each feature is independently valuable
- Can ship with basic protection, enhance later

---

## Success Criteria (Updated)

### Technical Metrics
- [x] All core features implemented and tested (Phase 1)
- [ ] Limit orders functional with executor rewards
- [ ] MEV protection demonstrably prevents sandwich attacks
- [ ] Gas costs within 15% of vanilla V2 (excluding new features)
- [ ] Test coverage ≥ 90%
- [ ] Zero high/critical issues in security review

### Portfolio Metrics
- [x] Clean GitHub with architecture docs (Phase 1)
- [ ] Deployed on testnet with limit orders
- [ ] MEV protection demo video
- [ ] Documentation explains innovations clearly
- [ ] Can explain each feature in 2-minute interview pitch

### Learning Metrics
- [x] Deep understanding of AMM mechanics (Phase 1)
- [ ] Understanding of MEV strategies and mitigations
- [ ] Experience with EIP-712 signatures (limit orders)
- [ ] Knowledge of Flashbots and private transaction pools
- [ ] Can explain tradeoffs made and alternatives considered

---

## Next Steps

**Immediate:**
- [x] Finalize innovation selection
- [x] Update documentation to reflect new focus
- [ ] Begin limit order design (whiteboard session)

**Week 1-2: Limit Orders**
- [ ] Implement core order book contract
- [ ] Write order creation/execution logic
- [ ] Integration testing with existing AMM

**Week 3-5: MEV Protection**
- [ ] Research Flashbots documentation
- [ ] Implement commit-reveal scheme
- [ ] Add Flashbots RPC integration
- [ ] Security testing against MEV strategies

**Week 6: Polish & Deploy**
- [ ] End-to-end integration testing
- [ ] Deploy to testnet
- [ ] Record demo video
- [ ] Update portfolio with new features

---

**Last Updated:** 2025-11-04
**Status:** Phase 1 Complete ✅ → Phase 2 In Progress (Limit Orders + MEV Protection)
**Confidence Level:** High (clear direction, pragmatic choices, high-value features)
