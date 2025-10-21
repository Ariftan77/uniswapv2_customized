// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title ICustomizedUniswapV2Factory
 * @notice Interface for the Factory contract that creates and manages trading pairs
 * @dev Upgraded to Solidity 0.8.28 for better security and gas optimization
 */
interface ICustomizedUniswapV2Factory {
    /// @notice Emitted when a new pair is created
    /// @param token0 Address of the first token (lower address)
    /// @param token1 Address of the second token (higher address)
    /// @param pair Address of the newly created pair contract
    /// @param pairCount Total number of pairs created
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 pairCount);

    /// @notice Returns the address that receives protocol fees
    /// @return Address of the fee recipient (address(0) if fees are disabled)
    function feeTo() external view returns (address);

    /// @notice Returns the address that can change feeTo
    /// @return Address of the governance/admin
    function feeToSetter() external view returns (address);

    /// @notice Get the pair address for two tokens
    /// @param tokenA Address of first token
    /// @param tokenB Address of second token
    /// @return pair Address of the pair (address(0) if doesn't exist)
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    /// @notice Get pair address by index
    /// @param index Index in the allPairs array
    /// @return pair Address of the pair at that index
    function allPairs(uint256 index) external view returns (address pair);

    /// @notice Get total number of pairs created
    /// @return Total number of pairs
    function allPairsLength() external view returns (uint256);

    /// @notice Create a new trading pair for two tokens
    /// @param tokenA Address of first token
    /// @param tokenB Address of second token
    /// @return pair Address of the newly created pair
    function createPair(address tokenA, address tokenB) external returns (address pair);

    /// @notice Set the fee recipient address
    /// @param feeTo New fee recipient address
    function setFeeTo(address feeTo) external;

    /// @notice Transfer governance to a new address
    /// @param feeToSetter New governance address
    function setFeeToSetter(address feeToSetter) external;
}
