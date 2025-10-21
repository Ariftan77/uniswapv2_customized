// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import '../CustomizedUniswapV2ERC20.sol';

contract ERC20 is CustomizedUniswapV2ERC20 {
    constructor(uint256 _totalSupply) {
        _mint(msg.sender, _totalSupply);
    }
}
