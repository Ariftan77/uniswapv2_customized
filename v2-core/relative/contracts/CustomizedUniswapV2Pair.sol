// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import './interfaces/ICustomizedUniswapV2Pair.sol';
import './CustomizedUniswapV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './libraries/FeeTiers.sol';
import './interfaces/IERC20.sol';
import './interfaces/ICustomizedUniswapV2Factory.sol';
import './interfaces/ICustomizedUniswapV2Callee.sol';
import './errors/CustomErrors.sol';

/**
 * @title CustomizedUniswapV2Pair
 * @notice The trading pool contract - This is where the AMM magic happens! 🎩✨
 *
 * ============ WHAT IS A PAIR? ============
 *
 * A Pair is a liquidity pool for TWO tokens (e.g., ETH/USDC)
 * It's like a robot market maker that:
 * - Holds reserves of both tokens
 * - Lets users swap between them
 * - Lets users provide/remove liquidity
 * - Uses the x*y=k formula to price trades
 *
 * ============ KEY CONCEPTS ============
 *
 * 1. RESERVES: How much of each token the pool holds
 *    Example: 100 ETH + 200,000 USDC
 *
 * 2. CONSTANT PRODUCT (x*y=k):
 *    - x = reserve of token0
 *    - y = reserve of token1
 *    - k = x * y (must stay constant during swaps!)
 *    - Example: 100 * 200,000 = 20,000,000 = k
 *
 * 3. LP TOKENS: Your share of the pool
 *    - Add liquidity → Get LP tokens
 *    - Remove liquidity → Burn LP tokens
 *    - Inherits from CustomizedUniswapV2ERC20 for LP token functionality
 *
 * ============ MAIN FUNCTIONS ============
 *
 * - mint(): Add liquidity (deposit tokens, get LP tokens)
 * - burn(): Remove liquidity (burn LP tokens, get tokens back)
 * - swap(): Trade one token for another
 * - sync(): Sync reserves with actual balances
 * - skim(): Remove excess tokens
 *
 * ============ REAL WORLD ANALOGY ============
 *
 * Think of a Pair like a vending machine:
 * - It holds two types of coins (ETH and USDC)
 * - You can exchange one type for another
 * - The exchange rate depends on how many of each it has
 * - More people want ETH → ETH becomes more expensive
 * - The machine always keeps x*y=constant
 */
contract CustomizedUniswapV2Pair is ICustomizedUniswapV2Pair, CustomizedUniswapV2ERC20 {
    using UQ112x112 for uint224;  // Fixed-point math for price oracle
    using FeeTiers for address;

    // ============ Constants ============

    /**
     * @notice Minimum liquidity locked forever on first mint
     * @dev 1000 wei of LP tokens sent to address(0) on first liquidity provision
     *
     * WHY LOCK LIQUIDITY?
     * - Prevents division by zero attacks
     * - Ensures pool can never be completely drained
     * - Small cost (~$0.001) for first LP, benefits everyone after
     *
     * EXAMPLE:
     * First person adds 1 ETH + 2000 USDC:
     * - Calculate: sqrt(1e18 * 2000e18) = ~1.414e21 LP tokens
     * - Lock 1000 wei to address(0) (burned forever)
     * - Give 1.414e21 - 1000 to the provider
     */
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    /**
     * @notice Function selector for ERC20 transfer
     * @dev Used in _safeTransfer to call token.transfer()
     *      Precomputed to save gas (don't recalculate every time)
     */
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    // ============ Immutable State (Set Once) ============

    /**
     * @notice Address of the factory that created this pair
     * @dev Set in constructor, never changes
     */
    address public factory;

    /**
     * @notice Address of first token (lower address)
     * @dev Set in initialize(), never changes
     *      Factory ensures token0 < token1 by address
     */
    address public token0;

    /**
     * @notice Address of second token (higher address)
     * @dev Set in initialize(), never changes
     */
    address public token1;

    // ============ Reserves (CRITICAL STATE!) ============

    /**
     * @notice Reserve of token0 in the pool
     * @dev uint112 to pack into single storage slot with reserve1 and blockTimestampLast
     *      Max value: 2^112 - 1 ≈ 5.2e33 (more than enough for any token)
     *
     * STORAGE OPTIMIZATION:
     * These three variables fit in ONE 256-bit slot:
     * - reserve0: 112 bits
     * - reserve1: 112 bits
     * - blockTimestampLast: 32 bits
     * Total: 256 bits = 1 slot ⛽ Saves gas!
     */
    uint112 private reserve0;

    /**
     * @notice Reserve of token1 in the pool
     * @dev See reserve0 comment for details
     */
    uint112 private reserve1;

    /**
     * @notice Last block timestamp when reserves were updated
     * @dev Used for price oracle (TWAP - Time Weighted Average Price)
     *      uint32 is safe until year 2106 (Unix timestamp overflow)
     */
    uint32  private blockTimestampLast;

    // ============ Price Oracle State ============

    /**
     * @notice Cumulative price of token0 (in terms of token1)
     * @dev Used to calculate Time-Weighted Average Price (TWAP)
     *      Accumulates: (reserve1/reserve0) * timeElapsed
     *
     * EXAMPLE:
     * Block 100: price = 2000 USDC/ETH, time = 12s
     * → price0CumulativeLast += 2000 * 12 = 24,000
     *
     * To get average price between block A and B:
     * avgPrice = (price0Cumulative[B] - price0Cumulative[A]) / (time[B] - time[A])
     */
    uint256 public price0CumulativeLast;

    /**
     * @notice Cumulative price of token1 (in terms of token0)
     * @dev Inverse of price0CumulativeLast
     */
    uint256 public price1CumulativeLast;

    /**
     * @notice Product of reserves after last liquidity event (k = reserve0 * reserve1)
     * @dev Used to calculate protocol fees
     *      Only updated when liquidity is added/removed, not on swaps
     */
    uint256 public kLast;

    // ============ Reentrancy Protection ============

    /**
     * @notice Reentrancy guard state
     * @dev Simple reentrancy protection (cheaper than OpenZeppelin's)
     *      unlocked = 1: Not in a protected function
     *      unlocked = 0: Currently executing a protected function
     */
    uint8 private unlocked = 1;

    /// @notice Current fee tier for this pair (in basis points)
    uint24 public feeTier;

    /// @notice Volatility score (0-100, updated periodically)
    uint8 public volatility;

    /// @notice Last time volatility was updated
    uint32 public lastVolatilityUpdate;

    // ============ TWAP Oracle State ============

    /**
     * @notice Observation structure for TWAP oracle
     * @dev Stores price data at specific points in time
     */
    struct Observation {
        uint32 timestamp;              // When this observation was recorded
        uint256 price0Cumulative;      // Cumulative price of token0 at this time
        uint256 price1Cumulative;      // Cumulative price of token1 at this time
    }

    /**
     * @notice Circular buffer of observations (ring buffer)
     * @dev Fixed size array that wraps around when full
     *      Size = 24 observations (1 per hour for 24 hours)
     */
    Observation[24] public observations;

    /**
     * @notice Current index in the observations array
     * @dev Wraps around: 0 → 1 → 2 → ... → 23 → 0 → 1 ...
     */
    uint8 public observationIndex;

    /**
     * @notice Number of observations recorded so far
     * @dev Maxes out at 24, then stays at 24
     */
    uint8 public observationCount;

    /**
     * @notice Reentrancy guard modifier
     * @dev Prevents reentrancy attacks where a malicious contract
     *      calls back into the Pair during execution
     *
     * EXAMPLE OF PREVENTED ATTACK:
     * 1. Attacker calls swap()
     * 2. During swap, malicious token calls back to swap() again
     * 3. Second swap() call hits "require(unlocked == 1)"
     * 4. Reverts! Attack prevented! ✅
     *
     * HOW IT WORKS:
     * 1. Check unlocked == 1 (not currently locked)
     * 2. Set unlocked = 0 (lock)
     * 3. Execute function body (_)
     * 4. Set unlocked = 1 (unlock)
     */
    modifier lock() {
        if (unlocked != 1) revert Locked();
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert InsufficientBalance(address(this), 0, value);
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        if (msg.sender != factory) revert Forbidden(msg.sender, factory); // sufficient check
        token0 = _token0;
        token1 = _token1;

        // Initialize fee tier based on token types
        volatility = 30; // Start with medium volatility
        feeTier = FeeTiers.getFeeTier(_token0, _token1, volatility);        
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        if (balance0 > type(uint112).max) revert BalanceOverflow(balance0);
        if (balance1 > type(uint112).max) revert BalanceOverflow(balance1);
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);

        // Record observation for TWAP oracle (if enough time has passed)
        _maybeRecordObservation();
    }

    /**
     * @notice Record a new observation for TWAP oracle
     * @dev Called automatically by _update if 1 hour has passed
     *
     * ============ HOW IT WORKS ============
     *
     * Uses a circular buffer (ring buffer):
     * - Array of 24 observations (1 per hour for 24 hours)
     * - When full, overwrites oldest observation
     * - Always keeps last 24 hours of data
     *
     * ============ CIRCULAR BUFFER EXAMPLE ============
     *
     * Initial state (empty):
     * [_, _, _, ...] index=0, count=0
     *
     * After 3 recordings:
     * [A, B, C, _, ...] index=3, count=3
     *
     * After 24 recordings (full):
     * [A, B, C, ..., X] index=0, count=24 (wraps around!)
     *
     * After 25 recordings:
     * [NEW, B, C, ..., X] index=1, count=24 (overwrote A!)
     *
     * ============ WHY 1 HOUR INTERVALS? ============
     *
     * - Too frequent: Wastes gas, storage bloat
     * - Too infrequent: Not enough data points
     * - 1 hour: Good balance (24 observations = 24h history)
     */
    function _maybeRecordObservation() private {
        uint32 currentTime = uint32(block.timestamp);

        // Only record if 1 hour has passed since last observation
        // First check: has any observation been recorded?
        if (observationCount > 0) {
            // Get the most recent observation
            uint8 lastIndex = observationIndex == 0 ? 23 : observationIndex - 1;
            uint32 lastTimestamp = observations[lastIndex].timestamp;

            // If less than 1 hour has passed, don't record
            if (currentTime < lastTimestamp + 1 hours) {
                return;
            }
        }

        // Record new observation
        observations[observationIndex] = Observation({
            timestamp: currentTime,
            price0Cumulative: price0CumulativeLast,
            price1Cumulative: price1CumulativeLast
        });

        // Increment index (wraps around at 24)
        observationIndex = (observationIndex + 1) % 24;

        // Increment count (maxes at 24)
        if (observationCount < 24) {
            observationCount++;
        }

        emit ObservationRecorded(currentTime, price0CumulativeLast, price1CumulativeLast);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = ICustomizedUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }
        if (liquidity == 0) revert InsufficientLiquidityMinted(liquidity);
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity * balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity * balance1 / _totalSupply; // using balances ensures pro-rata distribution
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned(liquidity);
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientOutputAmount(0, 1);
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        if (amount0Out >= _reserve0 || amount1Out >= _reserve1) revert InsufficientLiquidity(uint256(_reserve0) + uint256(_reserve1), amount0Out + amount1Out);

        uint256 balance0;
        uint256 balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        if (to == _token0 || to == _token1) revert InvalidRecipient(to);
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) ICustomizedUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        if (amount0In == 0 && amount1In == 0) revert InsufficientInputAmount();
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        // uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        // uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
        // uint256 k0 = uint256(_reserve0) * _reserve1 * 1000**2;
        // uint256 k1 = balance0Adjusted * balance1Adjusted;
        // if (k1 < k0) revert KInvariantViolation(k0, k1);
        
        // Calculate fees based on dynamic fee tier
        uint256 balance0Adjusted = balance0 * FeeTiers.FEE_DENOMINATOR - amount0In * feeTier;
        uint256 balance1Adjusted = balance1 * FeeTiers.FEE_DENOMINATOR - amount1In * feeTier;

        // K invariant check with dynamic fees
        uint256 k0 = uint256(_reserve0) * uint256(_reserve1) * (uint256(FeeTiers.FEE_DENOMINATOR) ** 2);
        uint256 k1 = balance0Adjusted * balance1Adjusted;

        if (k1 < k0) revert KInvariantViolation(k0, k1);
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    // ============ Volatility Oracle ============

    /**
     * @notice Update volatility score based on price changes
     * @dev Called periodically to adjust fee tier based on market volatility
     *
     * ============ HOW IT WORKS ============
     *
     * 1. Calculate current price from reserves
     * 2. Compare with price 24h ago (from cumulative price oracle)
     * 3. Calculate price change percentage
     * 4. Update volatility score (0-100)
     * 5. Update fee tier if volatility changed significantly
     *
     * ============ VOLATILITY SCORING ============
     *
     * - 0-10: Very stable (stablecoins, major pairs)
     * - 11-30: Low volatility (established tokens)
     * - 31-50: Medium volatility (standard pairs)
     * - 51-80: High volatility (newer/smaller tokens)
     * - 81-100: Extreme volatility (meme coins, new launches)
     *
     * ============ EXAMPLE ============
     *
     * USDT/USDC pair:
     * - Price change: 0.01% over 24h
     * - Volatility: 5 (very stable)
     * - Fee tier: 0.01%
     *
     * SHITCOIN/ETH pair:
     * - Price change: 60% over 24h
     * - Volatility: 85 (extreme)
     * - Fee tier: 1.0%
     *
     * ============ WHO CAN CALL? ============
     *
     * Anyone! This is a public function.
     * - Incentive: Updated fees benefit all users
     * - Could add small reward for caller in future
     * - Keeper bots will likely call this automatically
     */
    function updateVolatility() external {
        // Only update once per 24 hours (prevents spam)
        if (block.timestamp < lastVolatilityUpdate + 24 hours) {
            return; // Silently return if too soon
        }

        // Get current reserves
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();

        // Don't update if reserves are empty (no liquidity yet)
        if (_reserve0 == 0 || _reserve1 == 0) {
            return;
        }

        // Calculate current price (reserve1 per reserve0, scaled by 1e18)
        // Example: If reserve0 = 100 ETH, reserve1 = 200,000 USDC
        // Then price = 2000 USDC per ETH
        uint256 currentPrice = (uint256(_reserve1) * 1e18) / uint256(_reserve0);

        // Get price from 24 hours ago using cumulative price oracle
        // The price oracle accumulates: price * timeElapsed
        // To get average price over last 24h:
        // avgPrice = (currentCumulative - oldCumulative) / timeElapsed
        uint256 price24hAgo = _getPriceFromOracle(24 hours);

        // If we don't have 24h of history yet, use current price
        if (price24hAgo == 0) {
            price24hAgo = currentPrice;
        }

        // Calculate absolute price change percentage
        // Example: price went from 2000 to 2200
        // priceChange = |2200 - 2000| / 2000 * 100 = 10%
        uint256 priceChange;
        if (currentPrice > price24hAgo) {
            priceChange = ((currentPrice - price24hAgo) * 100) / price24hAgo;
        } else {
            priceChange = ((price24hAgo - currentPrice) * 100) / price24hAgo;
        }

        // Update volatility score based on price change
        uint8 newVolatility;
        if (priceChange > 50) {
            newVolatility = 80; // Very volatile (50%+ change)
        } else if (priceChange > 20) {
            newVolatility = 50; // Moderately volatile (20-50% change)
        } else if (priceChange > 10) {
            newVolatility = 30; // Slightly volatile (10-20% change)
        } else if (priceChange > 5) {
            newVolatility = 15; // Low volatility (5-10% change)
        } else {
            newVolatility = 5;  // Very stable (<5% change)
        }

        // Only update if volatility changed significantly (>5 points)
        // This prevents frequent fee tier changes
        if (newVolatility > volatility + 5 || newVolatility + 5 < volatility) {
            volatility = newVolatility;

            // Recalculate fee tier based on new volatility
            uint24 newFeeTier = FeeTiers.getFeeTier(token0, token1, volatility);

            // Only emit event and update if fee tier actually changed
            if (newFeeTier != feeTier) {
                uint24 oldFeeTier = feeTier;
                feeTier = newFeeTier;
                emit FeeTierUpdated(oldFeeTier, newFeeTier, volatility);
            }
        }

        // Update timestamp
        lastVolatilityUpdate = uint32(block.timestamp);
    }

    /**
     * @notice Get historical price from cumulative price oracle
     * @param secondsAgo How many seconds ago to get price for
     * @return price Price at that time (scaled by 1e18)
     *
     * ============ HOW CUMULATIVE PRICE WORKS ============
     *
     * The pair contract accumulates: price * timeElapsed
     * - Every block, it adds: currentPrice * secondsSinceLastUpdate
     * - This creates a "cumulative sum" of prices over time
     *
     * To get average price between time A and B:
     * avgPrice = (cumulative[B] - cumulative[A]) / (time[B] - time[A])
     *
     * ============ EXAMPLE ============
     *
     * Block 1 (time=0): price=2000, cumulative=0
     * Block 2 (time=12s): price=2000, cumulative=0+(2000*12)=24,000
     * Block 3 (time=24s): price=2100, cumulative=24,000+(2100*12)=49,200
     *
     * Average price from block 1 to 3:
     * avgPrice = (49,200 - 0) / (24 - 0) = 2,050
     */
    function _getPriceFromOracle(uint256 secondsAgo) internal view returns (uint256 price) {
        // If no observations yet, return current spot price
        if (observationCount == 0) {
            (uint112 _reserve0, uint112 _reserve1,) = getReserves();
            if (_reserve0 == 0) return 0;
            return (uint256(_reserve1) * 1e18) / uint256(_reserve0);
        }

        // Find the observation closest to the requested time
        uint32 targetTime = uint32(block.timestamp - secondsAgo);

        // Use binary search to find closest observation
        (bool found, , Observation memory oldObs) = _findObservation(targetTime);

        // If we don't have data that old, use oldest available
        if (!found) {
            oldObs = _getOldestObservation();
        }

        // Calculate TWAP from old observation to now
        uint32 timeElapsed = uint32(block.timestamp) - oldObs.timestamp;

        // Avoid division by zero
        if (timeElapsed == 0) {
            (uint112 _reserve0, uint112 _reserve1,) = getReserves();
            if (_reserve0 == 0) return 0;
            return (uint256(_reserve1) * 1e18) / uint256(_reserve0);
        }

        // Calculate TWAP: (cumulativeNow - cumulativeOld) / timeElapsed
        uint256 priceCumulativeDelta = price0CumulativeLast - oldObs.price0Cumulative;
        price = priceCumulativeDelta / timeElapsed;

        return price;
    }

    /**
     * @notice Find observation closest to target time using binary search
     */
    function _findObservation(uint32 targetTime) internal view returns (
        bool found,
        uint8 index,
        Observation memory obs
    ) {
        if (observationCount == 0) {
            return (false, 0, obs);
        }

        uint8 left = 0;
        uint8 right = observationCount - 1;
        uint8 mid;

        while (left <= right) {
            mid = (left + right) / 2;
            uint8 actualIndex = _getObservationIndex(mid);
            uint32 obsTime = observations[actualIndex].timestamp;

            if (obsTime == targetTime) {
                return (true, actualIndex, observations[actualIndex]);
            } else if (obsTime < targetTime) {
                left = mid + 1;
            } else {
                if (mid == 0) break;
                right = mid - 1;
            }
        }

        if (right < observationCount) {
            uint8 closestIndex = _getObservationIndex(right);
            return (true, closestIndex, observations[closestIndex]);
        }

        return (false, 0, obs);
    }

    /**
     * @notice Get observation at logical index (handles circular buffer)
     */
    function _getObservationIndex(uint8 logicalIndex) internal view returns (uint8 actualIndex) {
        if (observationCount < 24) {
            return logicalIndex;
        } else {
            return (observationIndex + logicalIndex) % 24;
        }
    }

    /**
     * @notice Get the oldest observation in the buffer
     */
    function _getOldestObservation() internal view returns (Observation memory obs) {
        if (observationCount < 24) {
            return observations[0];
        } else {
            return observations[observationIndex];
        }
    }

    /**
     * @notice Get current price (for external queries)
     * @return price Current price of token1 per token0 (scaled by 1e18)
     */
    function getCurrentPrice() external view returns (uint256 price) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        if (_reserve0 == 0) return 0;
        return (uint256(_reserve1) * 1e18) / uint256(_reserve0);
    }
}
