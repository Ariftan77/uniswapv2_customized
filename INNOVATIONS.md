# CustomDEX - Innovation Specifications

**Project:** Modern Uniswap V2 Reimplementation
**Goal:** Production-ready DEX with V3-inspired improvements and modern Solidity patterns
**Timeline:** 4-5 weeks (Phase 1: v2-core)
**Target:** Employer portfolio demonstrating DeFi expertise

---

## Selected Innovations (5 Features)

### 1. Multiple Fee Tiers 💰
**Inspired by:** Uniswap V3
**Difficulty:** ⭐ Easy
**Estimated Time:** 3 days
**Phase:** 1 (v2-core)

#### Problem Statement
Uniswap V2's fixed 0.30% fee is suboptimal:
- **Stablecoin pairs** (USDT/USDC): Low volatility, need low fees to attract volume
- **Volatile pairs** (ETH/SHIB): High impermanent loss, need high fees to compensate LPs
- **One-size-fits-all** leaves money on the table for both LPs and traders

#### Solution
Allow pool creators to select from multiple fee tiers:
- **0.05% (500):** Stablecoin pairs, correlated assets
- **0.30% (3000):** Standard pairs (V2 default)
- **1.00% (10000):** Exotic/volatile pairs

#### Implementation Plan
```solidity
// Factory.sol changes
mapping(address => mapping(address => mapping(uint24 => address))) public getPair;
mapping(uint24 => bool) public allowedFees; // 500, 3000, 10000

constructor() {
    allowedFees[500] = true;
    allowedFees[3000] = true;
    allowedFees[10000] = true;
}

function createPair(address tokenA, address tokenB, uint24 fee)
    external
    returns (address pair)
{
    require(allowedFees[fee], "CustomDEX: INVALID_FEE");
    // ... rest of pair creation logic
}
```

```solidity
// Pair.sol changes
uint24 public immutable fee; // Set during initialization

function swap(...) {
    // Use fee instead of hardcoded 997/1000
    uint amountInWithFee = amountIn.mul(10000 - fee);
    uint numerator = amountInWithFee.mul(reserveOut);
    uint denominator = reserveIn.mul(10000).add(amountInWithFee);
    amountOut = numerator / denominator;
}
```

#### Success Metrics
- [ ] 3 different fee tier pools can be created
- [ ] Swap calculations correct for each tier
- [ ] Gas costs comparable to V2
- [ ] 100% test coverage on fee math

#### Interview Pitch
"Uniswap V2's fixed fee model is inefficient. By implementing V3's fee tier system, I enabled LPs to optimize returns based on pair characteristics. A USDT/USDC pool with 0.05% fee captures more volume than 0.30%, while exotic pairs with 1% fee better compensate for impermanent loss risk."

---

### 2. Modern Solidity 0.8.x + Custom Errors ⚡
**Inspired by:** Solidity evolution, V4 patterns
**Difficulty:** ⭐ Easy
**Estimated Time:** 5 days
**Phase:** 1 (v2-core)

#### Problem Statement
Uniswap V2 written in Solidity 0.5.16 (2020):
- Uses `require(condition, "ERROR_STRING")` - wastes gas storing strings
- Manual overflow checks with SafeMath library - adds gas overhead
- Missing modern optimization patterns

Solidity 0.8.x improvements:
- Built-in overflow protection (can use `unchecked{}` for trusted math)
- Custom errors save ~500 gas per revert
- Better optimizer, smaller bytecode

#### Solution
Upgrade entire codebase to Solidity ^0.8.20 with strategic optimizations:

**Custom Errors:**
```solidity
// Old V2 way (expensive):
require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');

// Modern way (cheap):
error Expired();
if (deadline < block.timestamp) revert Expired();
```

**Strategic Unchecked Math:**
```solidity
// Safe to use unchecked (we verify k invariant after):
function swap(...) {
    unchecked {
        uint amountInWithFee = amountIn * 997; // Can't overflow with reasonable token amounts
        uint numerator = amountInWithFee * reserveOut;
        // ...
    }
    require(balance0 * balance1 >= uint(reserve0) * reserve1, 'K'); // Final safety check
}
```

**Remove SafeMath:**
```solidity
// Old:
using SafeMath for uint;
totalSupply = totalSupply.add(value);

// New:
totalSupply = totalSupply + value; // Built-in overflow check
```

#### Implementation Plan
1. **Day 1-2:** Upgrade compiler version, fix breaking changes
2. **Day 3:** Define all custom errors, replace require strings
3. **Day 4:** Identify safe `unchecked{}` blocks, benchmark gas savings
4. **Day 5:** Full test suite, gas comparison report

#### Success Metrics
- [ ] All contracts compile on Solidity ^0.8.20
- [ ] All tests passing (100% coverage maintained)
- [ ] Gas costs reduced by 15-20% on average
- [ ] Custom errors used for all reverts

#### Gas Savings Estimate
Per transaction type:
- Swap: ~500 gas saved (custom errors)
- Add liquidity: ~800 gas saved (unchecked math + custom errors)
- Remove liquidity: ~600 gas saved

#### Interview Pitch
"V2 was written before Solidity 0.8.x. By upgrading to modern Solidity and using custom errors, I reduced gas costs by 15-20% while maintaining the same security guarantees. I strategically used unchecked math in proven-safe contexts and let the compiler handle overflow protection everywhere else."

---

### 3. Enhanced Events & Analytics 📊
**Inspired by:** V4's focus on composability, DeFi analytics needs
**Difficulty:** ⭐ Easy
**Estimated Time:** 2 days
**Phase:** 1 (v2-core)

#### Problem Statement
Uniswap V2 has minimal events:
```solidity
event Swap(address indexed sender, uint amount0In, uint amount1In,
           uint amount0Out, uint amount1Out, address indexed to);
```

**Missing critical data:**
- What was the price after swap?
- What was the price impact?
- Who is the liquidity provider (for LP tracking)?
- What are the new reserves?

This makes off-chain analytics painful:
- Need to query reserves separately
- Can't track LP performance easily
- Hard to build real-time dashboards

#### Solution
Emit comprehensive events with rich data and proper indexing:

**Enhanced Swap Event:**
```solidity
event SwapExecuted(
    address indexed sender,
    address indexed to,
    uint amount0In,
    uint amount1In,
    uint amount0Out,
    uint amount1Out,
    uint newReserve0,    // NEW: track reserves in event
    uint newReserve1,    // NEW: easier for analytics
    uint price0,         // NEW: reserve1/reserve0 (scaled)
    uint price1          // NEW: reserve0/reserve1 (scaled)
);
```

**Enhanced Mint Event (LP Tracking):**
```solidity
event LiquidityAdded(
    address indexed sender,
    address indexed to,         // The actual LP who receives tokens
    uint amount0,
    uint amount1,
    uint liquidity,
    uint timestamp,              // NEW: track when LP entered
    uint totalLiquidity,         // NEW: LP's share of pool
    uint reserve0AfterMint,      // NEW: pool state after
    uint reserve1AfterMint       // NEW: pool state after
);
```

**Enhanced Burn Event:**
```solidity
event LiquidityRemoved(
    address indexed sender,
    address indexed to,
    uint amount0,
    uint amount1,
    uint liquidity,
    uint timestamp,              // NEW: track when LP exited
    uint reserve0AfterBurn,      // NEW: pool state after
    uint reserve1AfterBurn       // NEW: pool state after
);
```

**New: Fee Collection Tracking:**
```solidity
event FeesAccumulated(
    uint fees0,                  // NEW: track fees collected
    uint fees1,                  // NEW: since last event
    uint cumulativeFees0,        // NEW: total fees ever
    uint cumulativeFees1,        // NEW: total fees ever
    uint timestamp
);
```

#### Implementation Plan
1. **Day 1:** Define all enhanced events, add to interfaces
2. **Day 2:** Emit events in all functions, write test cases to verify event data

#### Use Cases Enabled
**For Frontend Developers:**
```javascript
// Easy to build "Current Price" widget
pair.on('SwapExecuted', (sender, to, ...args) => {
    const { price0, price1 } = args;
    updatePriceDisplay(price0);
});
```

**For LP Dashboards:**
```javascript
// Track LP performance without complex queries
pair.on('LiquidityAdded', (sender, to, ...args) => {
    const { timestamp, totalLiquidity } = args;
    recordLPEntry(to, timestamp, totalLiquidity);
});

pair.on('FeesAccumulated', (...args) => {
    const { cumulativeFees0, cumulativeFees1 } = args;
    calculateLPReturns(cumulativeFees0, cumulativeFees1);
});
```

**For Analytics:**
- Real-time volume tracking (no need to query reserves)
- LP profitability analysis (entry time + fees)
- Price impact monitoring (before/after prices)

#### Success Metrics
- [ ] All state-changing functions emit comprehensive events
- [ ] Events include indexed parameters for filtering
- [ ] Test coverage includes event emission verification
- [ ] Documentation with example queries

#### Interview Pitch
"V2's minimal events make building analytics dashboards unnecessarily complex. I designed comprehensive events that include price data, reserve states, and timestamps, enabling real-time LP tracking and portfolio analytics without complex subgraph queries. This improves developer experience and makes the DEX more composable."

---

### 4. Improved TWAP Oracle 🔮
**Inspired by:** V3 oracle improvements, gas optimization research
**Difficulty:** ⭐⭐ Medium
**Estimated Time:** 7 days
**Phase:** 1 (v2-core)

#### Problem Statement
Uniswap V2's oracle works but has inefficiencies:

**Current V2 Approach:**
```solidity
uint public price0CumulativeLast;
uint public price1CumulativeLast;
uint32 public blockTimestampLast;

function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
    uint32 blockTimestamp = uint32(block.timestamp % 2**32);
    uint32 timeElapsed = blockTimestamp - blockTimestampLast;
    if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
        // Accumulate price * time
        price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
        price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
    }
    blockTimestampLast = blockTimestamp;
}
```

**Problems:**
1. **Storage Waste:** 3 separate storage slots (expensive SSTORE operations)
2. **Precision Loss:** UQ112x112 format limits precision
3. **Gas Cost:** Every swap updates oracle (even if not needed)
4. **No Flexibility:** Can't have multiple TWAP periods

#### Solution
**Packed Storage for Gas Savings:**
```solidity
// OLD: 3 storage slots (20,000 gas for cold access)
uint public price0CumulativeLast;
uint public price1CumulativeLast;
uint32 public blockTimestampLast;

// NEW: 2 storage slots (13,000 gas for cold access)
struct OracleData {
    uint128 price0Cumulative;  // Sufficient for most use cases
    uint128 price1Cumulative;
    uint32 blockTimestamp;
    uint96 reserved;           // Future expansion
}
OracleData public oracleData; // Single storage slot access pattern
```

**Better Precision with UQ128x128:**
```solidity
// V2 uses UQ112x112 (112 bits integer, 112 bits fraction)
// We use UQ128x128 for better precision on large price differences

library UQ128x128 {
    uint224 constant Q128 = 2**128;

    function encode(uint128 y) internal pure returns (uint256 z) {
        z = uint256(y) * Q128;
    }

    function uqdiv(uint256 x, uint128 y) internal pure returns (uint256 z) {
        z = x / uint256(y);
    }
}
```

**Optimized Update Logic:**
```solidity
function _update(uint balance0, uint balance1) private {
    uint32 blockTimestamp = uint32(block.timestamp);
    uint32 timeElapsed;

    unchecked {
        timeElapsed = blockTimestamp - oracleData.blockTimestamp;
    }

    if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
        unchecked {
            // Safe: price * timeElapsed can't realistically overflow uint128
            oracleData.price0Cumulative += uint128(
                (uint256(reserve1) << 128) / reserve0 * timeElapsed
            );
            oracleData.price1Cumulative += uint128(
                (uint256(reserve0) << 128) / reserve1 * timeElapsed
            );
        }
    }

    oracleData.blockTimestamp = blockTimestamp;
    emit OracleUpdated(oracleData.price0Cumulative, oracleData.price1Cumulative, blockTimestamp);
}
```

**New: Multi-Period TWAP Helper:**
```solidity
// V2 only stores cumulative, users calculate TWAP externally
// We add a helper for common use cases

struct TWAPObservation {
    uint32 timestamp;
    uint128 price0Cumulative;
    uint128 price1Cumulative;
}

// Store last N observations for flexible TWAP periods
TWAPObservation[8] public observations; // Circular buffer
uint8 public observationIndex;

function observe(uint32[] calldata secondsAgos)
    external
    view
    returns (uint128[] memory price0Cumulatives, uint128[] memory price1Cumulatives)
{
    // Return cumulative prices at requested timestamps
    // Enables: 10-min TWAP, 1-hour TWAP, etc. without external storage
}
```

#### Implementation Plan

**Day 1-2: Design & Refactor**
- Design packed storage layout
- Implement UQ128x128 library
- Refactor _update() function

**Day 3-4: Multi-Period TWAP**
- Implement circular buffer for observations
- Write observe() view function
- Add tests for various TWAP periods

**Day 5-6: Testing**
- Unit tests: precision, overflow edge cases
- Fuzz tests: random price updates over time
- Gas benchmarks: compare to V2

**Day 7: Documentation**
- Write oracle usage guide
- Document TWAP calculation examples
- Code comments on design decisions

#### Success Metrics
- [ ] Gas cost reduced by 30% for oracle updates
- [ ] Supports TWAP periods: 10min, 30min, 1hour, 24hour
- [ ] Precision maintained for price ranges 0.000001 to 1,000,000
- [ ] Fuzz tests pass 10,000+ random scenarios
- [ ] Documentation with usage examples

#### Gas Savings Estimate
- Oracle update: ~7,000 gas saved (packed storage)
- Per swap: ~2,000 gas saved (optimized math)

#### Interview Pitch
"V2's oracle is functional but inefficient. By using packed storage and UQ128x128 encoding, I reduced oracle update costs by 30% while improving precision. I also added a circular buffer of observations that enables flexible TWAP periods without external storage, making the oracle more composable for other protocols."

---

### 5. LP Position Metadata 👤
**Inspired by:** V3's NFT positions (simplified), DeFi analytics needs
**Difficulty:** ⭐⭐ Medium
**Estimated Time:** 5 days
**Phase:** 1 (v2-core)

#### Problem Statement
Uniswap V2 treats all LP tokens as fungible:
- Can't track WHEN an LP provided liquidity
- Can't track HOW MUCH fees an individual LP earned
- Can't identify "early LPs" vs "late LPs"
- Can't build LP leaderboards or incentive programs

**Example Problem:**
```
Alice adds liquidity on Day 1
Bob adds liquidity on Day 30
Both have 10 LP tokens

Q: Who earned more fees?
A: Unknown in V2 - LP tokens are identical
```

#### Solution
Add on-chain LP position tracking WITHOUT breaking ERC20 fungibility:

**Data Structures:**
```solidity
struct LPPosition {
    uint128 liquidityAmount;      // How many LP tokens
    uint32 depositTimestamp;      // When they deposited
    uint96 fees0Collected;        // Cumulative fees collected
    uint96 fees1Collected;
}

// Track positions per address
mapping(address => LPPosition[]) public positions;

// Track global fee accumulator (for calculating earned fees)
uint public globalFees0PerLiquidity;
uint public globalFees1PerLiquidity;
```

**How It Works:**
```solidity
function mint(address to) external lock returns (uint liquidity) {
    // ... normal V2 mint logic ...

    // NEW: Track LP position
    positions[to].push(LPPosition({
        liquidityAmount: uint128(liquidity),
        depositTimestamp: uint32(block.timestamp),
        fees0Collected: 0,
        fees1Collected: 0
    }));

    emit PositionCreated(to, liquidity, block.timestamp);
}

function burn(address to) external lock returns (uint amount0, uint amount1) {
    uint liquidity = balanceOf[address(this)];

    // NEW: Update position with earned fees before burning
    _updatePositionFees(msg.sender, liquidity);

    // ... normal V2 burn logic ...

    emit PositionClosed(msg.sender, liquidity, amount0, amount1);
}

function _updatePositionFees(address lp, uint liquidity) private {
    // Calculate fees earned since last update
    uint fees0 = (globalFees0PerLiquidity - position.fees0Checkpoint) * liquidity;
    uint fees1 = (globalFees1PerLiquidity - position.fees1Checkpoint) * liquidity;

    position.fees0Collected += fees0;
    position.fees1Collected += fees1;
}
```

**On Every Swap (accumulate fees):**
```solidity
function swap(...) {
    // ... normal swap logic ...

    // NEW: Update global fee accumulator
    uint fees0ThisSwap = amount0In * fee / 10000;
    uint fees1ThisSwap = amount1In * fee / 10000;

    globalFees0PerLiquidity += fees0ThisSwap * 1e18 / totalSupply;
    globalFees1PerLiquidity += fees1ThisSwap * 1e18 / totalSupply;
}
```

**New View Functions:**
```solidity
// Get LP's total positions
function getPositions(address lp) external view returns (LPPosition[] memory);

// Get LP's total fees earned
function getFeesEarned(address lp) external view returns (uint fees0, uint fees1);

// Get LP's APR based on position age
function calculateAPR(address lp) external view returns (uint apr);

// Leaderboard: Top LPs by fees earned
function getTopLPs(uint limit) external view returns (address[] memory, uint[] memory);
```

#### Implementation Plan

**Day 1-2: Core Tracking**
- Implement position structs and mappings
- Update mint/burn to track positions
- Add fee accumulator logic

**Day 3: View Functions**
- Implement getPositions()
- Implement getFeesEarned()
- Implement calculateAPR()

**Day 4: Testing**
- Test position tracking with multiple LPs
- Test fee calculation accuracy
- Test edge cases (transfer, multiple deposits)

**Day 5: Gas Optimization & Events**
- Optimize storage layout
- Add events for position changes
- Gas benchmark vs vanilla V2

#### Use Cases Enabled

**1. LP Analytics Dashboard:**
```javascript
// Frontend can now show:
const positions = await pair.getPositions(userAddress);
positions.forEach(pos => {
    console.log(`Deposited: ${pos.depositTimestamp}`);
    console.log(`Earned fees: ${pos.fees0Collected} / ${pos.fees1Collected}`);
    console.log(`APR: ${await pair.calculateAPR(userAddress)}%`);
});
```

**2. LP Incentive Programs:**
```solidity
// Reward early LPs with bonus tokens
function distributeBonus() external {
    address[] memory topLPs = pair.getTopLPs(100);
    for (uint i = 0; i < topLPs.length; i++) {
        uint bonus = calculateBonusForLP(topLPs[i]);
        rewardToken.transfer(topLPs[i], bonus);
    }
}
```

**3. Risk Management:**
```solidity
// Protocol can identify concentrated LP risk
if (singleLPOwnsMoreThan(50%)) {
    emit HighConcentrationRisk();
}
```

#### Success Metrics
- [ ] Position tracking accurate within 0.01% of actual fees
- [ ] Gas overhead <5% compared to vanilla V2
- [ ] Supports unlimited positions per LP
- [ ] View functions efficient for frontend queries
- [ ] Full test coverage including edge cases

#### Gas Cost Analysis
- Mint: +3,000 gas (position creation)
- Burn: +2,000 gas (position update)
- Swap: +1,500 gas (fee accumulator update)
- **Total overhead: ~5% per transaction**

#### Interview Pitch
"V2's fungible LP tokens make position tracking impossible on-chain. I implemented a dual-system that maintains ERC20 compatibility while tracking individual LP positions and fee earnings. This enables LP analytics dashboards, incentive programs, and risk management without breaking composability. The overhead is only ~5% gas cost for significantly improved LP experience."

---

## Implementation Roadmap

### Week 1: Foundation + Quick Wins
**Days 1-3: Multiple Fee Tiers**
- ✅ Update Factory for fee selection
- ✅ Update Pair for dynamic fee calculation
- ✅ Write tests for all 3 fee tiers

**Days 4-5: Modern Solidity Upgrade**
- ✅ Upgrade compiler to 0.8.20
- ✅ Define custom errors
- ✅ Remove SafeMath dependencies

**Days 6-7: Enhanced Events**
- ✅ Design comprehensive events
- ✅ Emit events in all functions
- ✅ Test event emission

**Milestone:** 3 features complete, visible progress

---

### Week 2-3: Medium Complexity Features

**Days 8-14: Improved TWAP Oracle**
- ✅ Implement packed storage (Days 8-9)
- ✅ UQ128x128 library (Day 10)
- ✅ Multi-period TWAP (Days 11-12)
- ✅ Testing & benchmarks (Days 13-14)

**Days 15-19: LP Position Metadata**
- ✅ Core tracking (Days 15-16)
- ✅ View functions (Day 17)
- ✅ Testing (Day 18)
- ✅ Gas optimization (Day 19)

**Milestone:** All 5 features complete

---

### Week 4: Integration & Polish

**Days 20-22: Integration Testing**
- Test all features working together
- Gas benchmarks vs vanilla V2
- Edge case testing

**Days 23-25: Documentation**
- Code comments (NatSpec)
- Architecture documentation
- Usage examples for each feature

**Days 26-28: Security Review**
- Self-audit checklist
- Reentrancy analysis
- Overflow/underflow verification

**Milestone:** Phase 1 (v2-core) complete and production-ready

---

## Success Criteria

### Technical Metrics
- [ ] All contracts compile without warnings
- [ ] Test coverage ≥ 90%
- [ ] Gas costs within 10% of V2 (excluding new features)
- [ ] Zero high/critical severity issues in self-audit
- [ ] All innovations working as specified

### Portfolio Metrics
- [ ] Clean GitHub README with architecture diagrams
- [ ] This INNOVATIONS.md clearly explains decisions
- [ ] Deployed on testnet with verified contracts
- [ ] Can explain each feature in 2-minute interview

### Learning Metrics
- [ ] Understand every line of code written
- [ ] Can explain tradeoffs made
- [ ] Can answer "why not do X instead?" questions
- [ ] Ready for Phase 2 (periphery contracts)

---

## Interview Talking Points

### Opening Pitch (30 seconds)
"I reimplemented Uniswap V2 from scratch with five modern improvements: V3's flexible fee tiers, Solidity 0.8.x gas optimizations, comprehensive analytics events, an improved TWAP oracle, and LP position tracking. The goal was to demonstrate I can build production DeFi while understanding the tradeoffs between V2's simplicity and V3's complexity."

### Deep Dive Questions You Should Prepare For

**Q: Why V2 instead of V3?**
A: "V2's constant product formula is elegant and battle-tested. 90% of DEX use cases don't need concentrated liquidity. By focusing on V2's simplicity and adding targeted improvements, I built something that's actually auditable and maintainable while learning the fundamentals of AMM design."

**Q: What was the hardest feature?**
A: "The improved TWAP oracle. I had to understand storage layout optimization, fixed-point arithmetic precision tradeoffs, and design a circular buffer for multi-period TWAPs. The challenge was maintaining V2's security guarantees while optimizing gas costs."

**Q: How did you decide which features to implement?**
A: "I studied V3 and V4 but filtered ideas through a 'production readiness' lens. Multiple fee tiers had clear value and low complexity. I skipped concentrated liquidity because the complexity-to-benefit ratio didn't make sense for a learning project. Every feature I added had to improve on V2 without compromising its core strengths."

**Q: What would you do differently?**
A: "I'd consider MEV protection, but I realized sandwich attack mitigation requires understanding game theory and mempool dynamics beyond my current level. I made the pragmatic choice to ship 5 working features instead of 3 working + 1 broken. I'd tackle MEV in a future iteration after studying Flashbots and real MEV bot behavior."

**Q: What did you learn?**
A: "The importance of tradeoffs. V3's concentrated liquidity improves capital efficiency but adds huge complexity. V4's hooks enable customization but create attack surface. V2's simplicity is actually a feature, not a limitation. Production DeFi is about shipping secure code, not cramming in every innovation."

---

## Risk Mitigation

### Risk: Features take longer than estimated
**Mitigation:** Each feature is independently valuable. If Week 3 runs long, ship 4 features instead of 5.

### Risk: Calculation errors (you mentioned 10x errors)
**Mitigation:**
- Write tests BEFORE implementation (TDD approach)
- Use Foundry fuzzing to catch edge cases
- I'll review all math-heavy code

### Risk: Scope creep ("let me add just one more thing...")
**Mitigation:** This document is the contract. No new features until Phase 1 complete.

### Risk: Getting stuck on oracle/LP metadata
**Mitigation:**
- Ask for help after 4 hours stuck (not 2 days)
- We'll pair-program on complex parts
- Simplify if needed (e.g., drop circular buffer, keep basic TWAP)

---

## Next Steps (After Phase 0)

**Immediate (Today):**
- [x] Finalize innovations (this document)
- [ ] Create research/phase0-summary.md (learnings from V2/V3/V4)
- [ ] Set up development environment (Hardhat + Foundry)

**Tomorrow:**
- [ ] Start Phase 1: Implement Multiple Fee Tiers
- [ ] Write first failing test
- [ ] Get first test passing

**This Week:**
- [ ] Complete first 3 features (Fee Tiers, Solidity Upgrade, Events)
- [ ] Feel momentum, see progress

---

**Last Updated:** 2025-10-06
**Status:** Phase 0 Complete ✅ → Ready for Phase 1
**Confidence Level:** High (realistic scope, clear plan, learning-focused)
