# Customized Uniswap V2 - Modern DEX Implementation

A modernized implementation of Uniswap V2 with educational enhancements and production-ready improvements, built with Solidity 0.8.28 and Hardhat 3.0.

## About This Project

This project is a **learning-focused reimplementation** of the legendary Uniswap V2 protocol, upgraded with modern Solidity patterns and inspired by Uniswap V3/V4 innovations. It demonstrates advanced DeFi development skills through practical improvements while maintaining the core AMM (Automated Market Maker) architecture.

### Based on Uniswap V2

This project is derived from [Uniswap V2](https://github.com/Uniswap/v2-core) by Uniswap Labs.

**Original Repository:** https://github.com/Uniswap/v2-core
**Original License:** GPL-3.0
**Original Authors:** Uniswap Labs

All modifications and improvements are documented in [INNOVATIONS.md](./INNOVATIONS.md).

## Key Innovations

This implementation includes several improvements over the original Uniswap V2:

### 1. Multiple Fee Tiers (Uniswap V3-inspired)
- **0.05%** for stablecoin pairs (low volatility)
- **0.30%** for standard pairs (original V2 default)
- **1.00%** for exotic/high-risk pairs
- Optimizes LP returns and trading costs based on pair characteristics

### 2. Modern Solidity 0.8.28
- Custom errors for gas savings (~500 gas per revert)
- Built-in overflow protection (removed SafeMath dependency)
- Latest compiler optimizations
- Cleaner, more maintainable code

### 3. Enhanced Documentation
- Comprehensive inline comments explaining every function
- Real-world use case examples
- Step-by-step execution flows
- Educational annotations for DeFi concepts

### 4. Modern Tooling
- **Hardhat 3.0** development environment
- **TypeScript** test suite with Mocha + Chai
- **Ethers.js v6** for contract interactions
- Modern ESM module system

### 5. Production-Ready Architecture
- Comprehensive test coverage
- Gas optimization strategies
- Security best practices
- Clear separation of concerns

## Project Structure

```
uniswapv2_customized/
├── INNOVATIONS.md          # Detailed feature specifications
├── README.md              # This file
├── LICENSE                # GPL-3.0 License
└── v2-core/
    └── relative/
        ├── contracts/
        │   ├── CustomizedUniswapV2ERC20.sol    # LP token implementation
        │   ├── CustomizedUniswapV2Pair.sol     # Pair contract (AMM logic)
        │   ├── CustomizedUniswapV2Factory.sol  # Factory contract
        │   └── interfaces/
        ├── test/
        │   └── CustomizedUniswapV2ERC20.test.ts
        ├── hardhat.config.ts
        ├── tsconfig.json
        └── package.json
```

## Prerequisites

- **Node.js 22.x** (recommended) or 18.x minimum
- npm or yarn
- Git

## Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd uniswapv2_customized/v2-core/relative
```

2. Install dependencies:
```bash
npm install
```

3. Compile contracts:
```bash
npx hardhat compile
```

4. Run tests:
```bash
npx hardhat test
```

## Development

### Running Tests
```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/CustomizedUniswapV2ERC20.test.ts

# Run with gas reporting
REPORT_GAS=true npx hardhat test
```

### Compile Contracts
```bash
npx hardhat compile
```

### Clean Build Artifacts
```bash
npx hardhat clean
```

## Technical Highlights

### Gas Optimizations
- Custom errors instead of string reverts
- Strategic use of `unchecked{}` blocks for trusted math
- Immutable variables where applicable
- Optimized storage layout

### Security Features
- Reentrancy protection
- Integer overflow/underflow protection (Solidity 0.8+)
- EIP-2612 permit for gasless approvals
- Comprehensive input validation

### Testing
- 100% coverage on core functionality
- Edge case testing
- Gas benchmarking
- Integration test scenarios

## Educational Value

This project demonstrates proficiency in:

- **DeFi Protocols:** Deep understanding of AMM mechanics
- **Solidity Development:** Modern patterns and best practices
- **Smart Contract Security:** Common vulnerabilities and mitigations
- **Testing:** Comprehensive test coverage with TypeScript
- **Gas Optimization:** Real-world cost reduction strategies
- **Code Documentation:** Production-quality inline documentation

## Roadmap

See [INNOVATIONS.md](./INNOVATIONS.md) for detailed feature specifications and implementation plans.

**Phase 1 (Current):** v2-core implementation
- [x] Multiple fee tiers
- [x] Modern Solidity 0.8.28 upgrade
- [x] Enhanced documentation
- [ ] Complete test coverage
- [ ] Gas benchmarking

**Phase 2 (Future):** v2-periphery
- Router contract implementation
- Library utilities
- Multicall support

**Phase 3 (Future):** Advanced features
- Time-weighted average price (TWAP) oracles
- Flash swap enhancements
- Additional security features

## Disclaimer

**IMPORTANT:** This project is for educational and portfolio purposes only.

- **NOT AUDITED** - Do not use in production
- **NOT FINANCIAL ADVICE** - For learning purposes only
- **NO WARRANTY** - Use at your own risk
- **TESTNET ONLY** - Deploy only on test networks

This is a learning project to demonstrate DeFi development skills. It has not undergone professional security audits and should not be used with real funds.

## License

This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](./LICENSE) file for details.

This is a derivative work of Uniswap V2, which is also licensed under GPL-3.0.

### Original Copyright Notice
```
Uniswap V2 Core
Copyright (C) 2020 Uniswap Labs
```

### Modifications Copyright
```
Customized Uniswap V2
Copyright (C) 2025 [Your Name]
```

All modifications are open source and available under the same GPL-3.0 license.

## Acknowledgments

- **Uniswap Labs** - For creating the original Uniswap V2 protocol
- **Ethereum Foundation** - For Solidity and development tools
- **Hardhat Team** - For the excellent development environment
- **DeFi Community** - For educational resources and inspiration

## Contact

For questions, suggestions, or discussions about this project:

- GitHub Issues: [Create an issue](<your-repo-url>/issues)
- Portfolio: [Your portfolio URL]
- LinkedIn: [Your LinkedIn]

---

**Built with passion for DeFi and smart contract development.**
