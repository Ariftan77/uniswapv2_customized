// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import './interfaces/ICustomizedUniswapV2Pair.sol';
import './CustomizedUniswapV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/ICustomizedUniswapV2Factory.sol';
import './interfaces/ICustomizedUniswapV2Callee.sol';

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
        require(unlocked == 1, 'UniswapV2: LOCKED');
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
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, 'UniswapV2: OVERFLOW');
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
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
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
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
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
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint256 balance0;
        uint256 balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) ICustomizedUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
        require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * 1000**2, 'UniswapV2: K');
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
}
