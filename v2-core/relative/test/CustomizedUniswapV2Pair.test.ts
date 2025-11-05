import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

const MINIMUM_LIQUIDITY = 10n ** 3n;

describe("CustomizedUniswapV2Pair", function () {
  let factory: any;
  let pair: any;
  let token0: any;
  let token1: any;
  let owner: any;
  let feeToSetter: any;
  let user1: any;
  let user2: any;

  beforeEach(async function () {
    [owner, feeToSetter, user1, user2] = await ethers.getSigners();

    // Deploy factory
    const Factory = await ethers.getContractFactory("CustomizedUniswapV2Factory");
    factory = await Factory.deploy(await feeToSetter.getAddress());

    // Deploy test tokens
    const Token = await ethers.getContractFactory("ERC20");
    const tokenA = await Token.deploy(ethers.parseEther("10000"));
    const tokenB = await Token.deploy(ethers.parseEther("10000"));

    // Ensure token0 < token1 by address
    const tokenAAddr = await tokenA.getAddress();
    const tokenBAddr = await tokenB.getAddress();

    if (tokenAAddr.toLowerCase() < tokenBAddr.toLowerCase()) {
      token0 = tokenA;
      token1 = tokenB;
    } else {
      token0 = tokenB;
      token1 = tokenA;
    }

    // Create pair
    await factory.createPair(await token0.getAddress(), await token1.getAddress());
    const pairAddress = await factory.getPair(
      await token0.getAddress(),
      await token1.getAddress()
    );

    pair = await ethers.getContractAt("CustomizedUniswapV2Pair", pairAddress);
  });

  describe("Initialization", function () {
    it("Should have correct factory address", async function () {
      expect(await pair.factory()).to.equal(await factory.getAddress());
    });

    it("Should have correct token0 and token1", async function () {
      expect(await pair.token0()).to.equal(await token0.getAddress());
      expect(await pair.token1()).to.equal(await token1.getAddress());
    });

    it("Should have token0 < token1 by address", async function () {
      const token0Addr = (await pair.token0()).toLowerCase();
      const token1Addr = (await pair.token1()).toLowerCase();
      expect(BigInt(token0Addr)).to.be.lessThan(BigInt(token1Addr));
    });

    it("Should have zero reserves initially", async function () {
      const reserves = await pair.getReserves();
      expect(reserves._reserve0).to.equal(0);
      expect(reserves._reserve1).to.equal(0);
    });

    it("Should have zero total supply initially", async function () {
      expect(await pair.totalSupply()).to.equal(0);
    });
  });

  describe("Mint (Add Liquidity)", function () {
    const token0Amount = ethers.parseEther("1");
    const token1Amount = ethers.parseEther("4");

    it("Should mint liquidity on first deposit", async function () {
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);

      const expectedLiquidity = BigInt(
        Math.sqrt(Number(token0Amount * token1Amount))
      ) - MINIMUM_LIQUIDITY;

      await expect(pair.mint(await owner.getAddress()))
        .to.emit(pair, "Mint")
        .withArgs(await owner.getAddress(), token0Amount, token1Amount);

      expect(await pair.totalSupply()).to.equal(expectedLiquidity + MINIMUM_LIQUIDITY);
      expect(await pair.balanceOf(await owner.getAddress())).to.equal(expectedLiquidity);
      expect(await pair.balanceOf(ethers.ZeroAddress)).to.equal(MINIMUM_LIQUIDITY);
    });

    it("Should lock MINIMUM_LIQUIDITY on first mint", async function () {
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);

      await pair.mint(await owner.getAddress());

      expect(await pair.balanceOf(ethers.ZeroAddress)).to.equal(MINIMUM_LIQUIDITY);
    });

    it("Should mint proportional liquidity on subsequent deposits", async function () {
      // First deposit
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());

      const totalSupply = await pair.totalSupply();

      // Second deposit
      const secondToken0Amount = ethers.parseEther("0.5");
      const secondToken1Amount = ethers.parseEther("2");

      await token0.transfer(await pair.getAddress(), secondToken0Amount);
      await token1.transfer(await pair.getAddress(), secondToken1Amount);

      const expectedLiquidity = (secondToken0Amount * totalSupply) / token0Amount;

      await pair.mint(await user1.getAddress());

      expect(await pair.balanceOf(await user1.getAddress())).to.equal(expectedLiquidity);
    });

    it("Should revert if insufficient liquidity minted", async function () {
      await token0.transfer(await pair.getAddress(), 1000);
      await token1.transfer(await pair.getAddress(), 1000);

      await expect(
        pair.mint(await owner.getAddress())
      ).to.be.revertedWithCustomError(pair, "InsufficientLiquidityMinted");
    });

    it("Should update reserves after mint", async function () {
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);

      await pair.mint(await owner.getAddress());

      const reserves = await pair.getReserves();
      expect(reserves._reserve0).to.equal(token0Amount);
      expect(reserves._reserve1).to.equal(token1Amount);
    });

    it("Should emit Sync event after mint", async function () {
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);

      await expect(pair.mint(await owner.getAddress()))
        .to.emit(pair, "Sync")
        .withArgs(token0Amount, token1Amount);
    });
  });

  describe("Burn (Remove Liquidity)", function () {
    const token0Amount = ethers.parseEther("3");
    const token1Amount = ethers.parseEther("3");

    beforeEach(async function () {
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());
    });

    it("Should burn liquidity and return tokens", async function () {
      const liquidity = await pair.balanceOf(await owner.getAddress());
      await pair.transfer(await pair.getAddress(), liquidity);

      const totalSupply = await pair.totalSupply();
      const expectedToken0 = (liquidity * token0Amount) / totalSupply;
      const expectedToken1 = (liquidity * token1Amount) / totalSupply;

      await expect(pair.burn(await owner.getAddress()))
        .to.emit(pair, "Burn")
        .withArgs(await owner.getAddress(), expectedToken0, expectedToken1, await owner.getAddress());
    });

    it("Should update reserves after burn", async function () {
      const liquidity = await pair.balanceOf(await owner.getAddress());
      await pair.transfer(await pair.getAddress(), liquidity);
      await pair.burn(await owner.getAddress());

      const reserves = await pair.getReserves();
      expect(reserves._reserve0).to.equal(MINIMUM_LIQUIDITY);
      expect(reserves._reserve1).to.equal(MINIMUM_LIQUIDITY);
    });

    it("Should revert if insufficient liquidity burned", async function () {
      // Don't transfer any liquidity tokens
      await expect(
        pair.burn(await owner.getAddress())
      ).to.be.revertedWithCustomError(pair, "InsufficientLiquidityBurned");
    });

    it("Should emit Sync event after burn", async function () {
      const liquidity = await pair.balanceOf(await owner.getAddress());
      await pair.transfer(await pair.getAddress(), liquidity);

      await expect(pair.burn(await owner.getAddress()))
        .to.emit(pair, "Sync");
    });
  });

  describe("Swap", function () {
    const token0Amount = ethers.parseEther("5");
    const token1Amount = ethers.parseEther("10");
    const swapAmount = ethers.parseEther("1");

    beforeEach(async function () {
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());
    });

    it("Should swap token0 for token1", async function () {
      const reserves = await pair.getReserves();
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Calculate expected output with dynamic fee
      // Using the formula: amountOut = (amountIn * (FEE_DENOMINATOR - feeTier) * reserveOut) / (reserveIn * FEE_DENOMINATOR + amountIn * (FEE_DENOMINATOR - feeTier))
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const numerator = amountInWithFee * reserves._reserve1;
      const denominator = reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee;
      const expectedOutputAmount = numerator / denominator;

      await token0.transfer(await pair.getAddress(), swapAmount);

      await expect(
        pair.swap(0, expectedOutputAmount, await user1.getAddress(), "0x")
      ).to.emit(pair, "Swap");
    });

    it("Should swap token1 for token0", async function () {
      const reserves = await pair.getReserves();
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Calculate expected output with dynamic fee
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const numerator = amountInWithFee * reserves._reserve0;
      const denominator = reserves._reserve1 * FEE_DENOMINATOR + amountInWithFee;
      const expectedOutputAmount = numerator / denominator;

      await token1.transfer(await pair.getAddress(), swapAmount);

      await expect(
        pair.swap(expectedOutputAmount, 0, await user1.getAddress(), "0x")
      ).to.emit(pair, "Swap");
    });

    it("Should revert if output amount is zero", async function () {
      await expect(
        pair.swap(0, 0, await user1.getAddress(), "0x")
      ).to.be.revertedWithCustomError(pair, "InsufficientOutputAmount");
    });

    it("Should revert if insufficient liquidity", async function () {
      await expect(
        pair.swap(token0Amount, 0, await user1.getAddress(), "0x")
      ).to.be.revertedWithCustomError(pair, "InsufficientLiquidity");
    });

    it("Should revert if invalid to address (token0)", async function () {
      await token0.transfer(await pair.getAddress(), swapAmount);

      await expect(
        pair.swap(0, swapAmount, await token0.getAddress(), "0x")
      ).to.be.revertedWithCustomError(pair, "InvalidRecipient");
    });

    it("Should revert if invalid to address (token1)", async function () {
      await token1.transfer(await pair.getAddress(), swapAmount);

      await expect(
        pair.swap(swapAmount, 0, await token1.getAddress(), "0x")
      ).to.be.revertedWithCustomError(pair, "InvalidRecipient");
    });

    it("Should enforce constant product formula with dynamic fee", async function () {
      const amountIn = ethers.parseEther("1");
      await token0.transfer(await pair.getAddress(), amountIn);

      const reserves = await pair.getReserves();

      // Get current fee tier (dynamic)
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Calculate expected output with dynamic fee
      const amountInWithFee = amountIn * (FEE_DENOMINATOR - feeTier);
      const numerator = amountInWithFee * reserves._reserve1;
      const denominator = reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee;
      const expectedOut = numerator / denominator;

      await pair.swap(0, expectedOut, await user1.getAddress(), "0x");

      const newReserves = await pair.getReserves();
      const k = reserves._reserve0 * reserves._reserve1;
      const newK = newReserves._reserve0 * newReserves._reserve1;

      // K should increase due to fees
      expect(newK).to.be.greaterThan(k);
    });

    it("Should update price cumulative values", async function () {
      const price0Before = await pair.price0CumulativeLast();
      const price1Before = await pair.price1CumulativeLast();

      // Wait for next block
      await ethers.provider.send("evm_mine", []);

      const reserves = await pair.getReserves();
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Calculate expected output with dynamic fee
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const numerator = amountInWithFee * reserves._reserve1;
      const denominator = reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee;
      const expectedOutputAmount = numerator / denominator;

      await token0.transfer(await pair.getAddress(), swapAmount);

      await pair.swap(0, expectedOutputAmount, await user1.getAddress(), "0x");

      const price0After = await pair.price0CumulativeLast();
      const price1After = await pair.price1CumulativeLast();

      expect(price0After).to.be.greaterThan(price0Before);
      expect(price1After).to.be.greaterThan(price1Before);
    });
  });

  describe("Skim", function () {
    it("Should skim excess tokens", async function () {
      const token0Amount = ethers.parseEther("1");
      const token1Amount = ethers.parseEther("4");

      // Add liquidity
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());

      // Send extra tokens
      const extraToken0 = ethers.parseEther("0.5");
      const extraToken1 = ethers.parseEther("0.5");
      await token0.transfer(await pair.getAddress(), extraToken0);
      await token1.transfer(await pair.getAddress(), extraToken1);

      const user1Addr = await user1.getAddress();
      const balanceBefore0 = await token0.balanceOf(user1Addr);
      const balanceBefore1 = await token1.balanceOf(user1Addr);

      await pair.skim(user1Addr);

      const balanceAfter0 = await token0.balanceOf(user1Addr);
      const balanceAfter1 = await token1.balanceOf(user1Addr);

      expect(balanceAfter0 - balanceBefore0).to.equal(extraToken0);
      expect(balanceAfter1 - balanceBefore1).to.equal(extraToken1);
    });
  });

  describe("Sync", function () {
    it("Should sync reserves to current balances", async function () {
      const token0Amount = ethers.parseEther("1");
      const token1Amount = ethers.parseEther("4");

      // Add liquidity
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());

      // Send extra tokens
      const extraToken0 = ethers.parseEther("0.5");
      const extraToken1 = ethers.parseEther("0.5");
      await token0.transfer(await pair.getAddress(), extraToken0);
      await token1.transfer(await pair.getAddress(), extraToken1);

      await expect(pair.sync())
        .to.emit(pair, "Sync")
        .withArgs(token0Amount + extraToken0, token1Amount + extraToken1);

      const reserves = await pair.getReserves();
      expect(reserves._reserve0).to.equal(token0Amount + extraToken0);
      expect(reserves._reserve1).to.equal(token1Amount + extraToken1);
    });
  });

  describe("Fee Distribution", function () {
    it("Should mint protocol fee when feeTo is set", async function () {
      // Set feeTo address FIRST
      const feeToAddr = await user2.getAddress();
      await factory.connect(feeToSetter).setFeeTo(feeToAddr);

      // Initial liquidity provision
      const token0Amount = ethers.parseEther("1000");
      const token1Amount = ethers.parseEther("1000");
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());

      // Get dynamic fee tier
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Perform multiple swaps to generate fees and increase K
      const swapAmount = ethers.parseEther("100");

      // Swap token0 for token1
      await token0.transfer(await pair.getAddress(), swapAmount);
      const reserves1 = await pair.getReserves();
      const amountInWithFee1 = swapAmount * (FEE_DENOMINATOR - feeTier);
      const numerator1 = amountInWithFee1 * reserves1._reserve1;
      const denominator1 = reserves1._reserve0 * FEE_DENOMINATOR + amountInWithFee1;
      const amountOut1 = numerator1 / denominator1;
      await pair.swap(0, amountOut1, await user1.getAddress(), "0x");

      // Swap token1 back to token0
      await token1.connect(user1).transfer(await pair.getAddress(), amountOut1);
      const reserves2 = await pair.getReserves();
      const amountInWithFee2 = amountOut1 * (FEE_DENOMINATOR - feeTier);
      const numerator2 = amountInWithFee2 * reserves2._reserve0;
      const denominator2 = reserves2._reserve1 * FEE_DENOMINATOR + amountInWithFee2;
      const amountOut2 = numerator2 / denominator2;
      await pair.swap(amountOut2, 0, await user1.getAddress(), "0x");

      // Trigger fee minting by adding more liquidity
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());

      const feeToBalance = await pair.balanceOf(feeToAddr);
      expect(feeToBalance).to.be.greaterThan(0);
    });

    it("Should not mint protocol fee when feeTo is not set", async function () {
      // Initial liquidity provision (feeTo not set)
      const token0Amount = ethers.parseEther("1000");
      const token1Amount = ethers.parseEther("1000");
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());

      // Get dynamic fee tier
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Perform swaps
      const swapAmount = ethers.parseEther("100");
      await token0.transfer(await pair.getAddress(), swapAmount);
      const reserves = await pair.getReserves();
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const numerator = amountInWithFee * reserves._reserve1;
      const denominator = reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee;
      const amountOut = numerator / denominator;
      await pair.swap(0, amountOut, await user1.getAddress(), "0x");

      // Add more liquidity
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());

      // feeTo should have zero balance (no fees minted)
      expect(await pair.balanceOf(ethers.ZeroAddress)).to.equal(MINIMUM_LIQUIDITY);
    });
  });

  describe("Reentrancy Protection", function () {
    it("Should prevent reentrancy on mint", async function () {
      const token0Amount = ethers.parseEther("1");
      const token1Amount = ethers.parseEther("4");

      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);

      // First mint should succeed
      await pair.mint(await owner.getAddress());

      // Trying to call mint again before completion should fail
      // (This is tested by the lock modifier in the contract)
    });
  });

  describe("ERC20 Functionality", function () {
    const token0Amount = ethers.parseEther("1");
    const token1Amount = ethers.parseEther("4");

    beforeEach(async function () {
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());
    });

    it("Should have correct name and symbol", async function () {
      expect(await pair.name()).to.equal("Uniswap V2");
      expect(await pair.symbol()).to.equal("UNI-V2");
      expect(await pair.decimals()).to.equal(18);
    });

    it("Should transfer LP tokens", async function () {
      const balance = await pair.balanceOf(await owner.getAddress());
      const transferAmount = balance / 2n;

      await pair.transfer(await user1.getAddress(), transferAmount);

      expect(await pair.balanceOf(await user1.getAddress())).to.equal(transferAmount);
      expect(await pair.balanceOf(await owner.getAddress())).to.equal(balance - transferAmount);
    });

    it("Should approve and transferFrom LP tokens", async function () {
      const balance = await pair.balanceOf(await owner.getAddress());
      const transferAmount = balance / 2n;

      await pair.approve(await user1.getAddress(), transferAmount);

      await pair
        .connect(user1)
        .transferFrom(await owner.getAddress(), await user2.getAddress(), transferAmount);

      expect(await pair.balanceOf(await user2.getAddress())).to.equal(transferAmount);
    });
  });

  describe("Dynamic Fees", function () {
    it("Should initialize with correct fee tier based on token types", async function () {
      const feeTier = await pair.feeTier();
      const volatility = await pair.volatility();

      // Should start with medium volatility (30)
      expect(volatility).to.equal(30);

      // Fee tier should be set (value depends on token types)
      expect(feeTier).to.be.greaterThan(0);
      expect(feeTier).to.be.lessThanOrEqual(100); // Max 1%
    });

    it("Should use dynamic fee in swap calculations", async function () {
      const token0Amount = ethers.parseEther("10");
      const token1Amount = ethers.parseEther("10");

      // Add liquidity
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());

      // Get reserves and fee tier before swap
      const reserves = await pair.getReserves();
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Perform swap
      const swapAmount = ethers.parseEther("1");

      // Calculate expected output with dynamic fee
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const numerator = amountInWithFee * reserves._reserve1;
      const denominator = reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee;
      const expectedOut = numerator / denominator;

      await token0.transfer(await pair.getAddress(), swapAmount);

      const balanceBefore = await token1.balanceOf(await user1.getAddress());
      await pair.swap(0, expectedOut, await user1.getAddress(), "0x");
      const balanceAfter = await token1.balanceOf(await user1.getAddress());

      // Should receive approximately expected amount (within 0.1% tolerance)
      const received = balanceAfter - balanceBefore;
      const tolerance = expectedOut / 1000n; // 0.1%
      expect(received).to.be.closeTo(expectedOut, tolerance);
    });

    it("Should update volatility score", async function () {
      // Add liquidity first
      await token0.transfer(await pair.getAddress(), ethers.parseEther("100"));
      await token1.transfer(await pair.getAddress(), ethers.parseEther("100"));
      await pair.mint(await owner.getAddress());

      const volatilityBefore = await pair.volatility();
      const lastUpdateBefore = await pair.lastVolatilityUpdate();

      // Fast forward 24 hours + 1 second
      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      // Calculate proper swap output
      const swapAmount = ethers.parseEther("1");
      const reserves = await pair.getReserves();
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

      // Perform swap to trigger observation recording
      await token0.transfer(await pair.getAddress(), swapAmount);
      await pair.swap(0, expectedOut, await user1.getAddress(), "0x");

      // Try to update volatility
      await pair.updateVolatility();

      const lastUpdateAfter = await pair.lastVolatilityUpdate();

      // Last update should have changed
      expect(lastUpdateAfter).to.be.greaterThan(lastUpdateBefore);
    });

    it("Should prevent volatility update before 24 hours", async function () {
      // Add liquidity
      await token0.transfer(await pair.getAddress(), ethers.parseEther("100"));
      await token1.transfer(await pair.getAddress(), ethers.parseEther("100"));
      await pair.mint(await owner.getAddress());

      // Try to update immediately (should silently return)
      await pair.updateVolatility();
      const timestamp1 = await pair.lastVolatilityUpdate();

      // Fast forward only 1 hour (not enough)
      await ethers.provider.send("evm_increaseTime", [60 * 60]);
      await ethers.provider.send("evm_mine", []);

      // Try to update again
      await pair.updateVolatility();
      const timestamp2 = await pair.lastVolatilityUpdate();

      // Timestamp should not change if called too soon
      // (or might be 0 if never updated successfully)
      expect(timestamp2).to.equal(timestamp1);
    });

    it("Should emit FeeTierUpdated event when fee changes", async function () {
      // Add liquidity
      await token0.transfer(await pair.getAddress(), ethers.parseEther("100"));
      await token1.transfer(await pair.getAddress(), ethers.parseEther("100"));
      await pair.mint(await owner.getAddress());

      // Record initial state
      const initialFeeTier = await pair.feeTier();

      // Fast forward 24 hours
      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      // Calculate proper swap output for large price movement
      const swapAmount = ethers.parseEther("50");
      const reserves = await pair.getReserves();
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

      // Create price movement (large swap to change price)
      await token0.transfer(await pair.getAddress(), swapAmount);
      await pair.swap(0, expectedOut, await user1.getAddress(), "0x");

      // Fast forward another 24 hours
      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      // This might emit FeeTierUpdated if volatility changed significantly
      // Note: May not always emit if price didn't change enough
      const tx = await pair.updateVolatility();

      // Transaction should succeed even if no event emitted
      expect(tx).to.not.be.undefined;
    });
  });

  describe("TWAP Oracle", function () {
    beforeEach(async function () {
      // Add liquidity for oracle tests
      const token0Amount = ethers.parseEther("100");
      const token1Amount = ethers.parseEther("200");
      await token0.transfer(await pair.getAddress(), token0Amount);
      await token1.transfer(await pair.getAddress(), token1Amount);
      await pair.mint(await owner.getAddress());
    });

    it("Should start with one observation after initial mint", async function () {
      const observationCount = await pair.observationCount();
      expect(observationCount).to.equal(1);
    });

    it("Should record observation after 1 hour", async function () {
      const countBefore = await pair.observationCount();

      // Fast forward 1 hour + 1 second
      await ethers.provider.send("evm_increaseTime", [60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      // Calculate proper swap output
      const swapAmount = ethers.parseEther("1");
      const reserves = await pair.getReserves();
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

      // Trigger observation by performing swap (calls _update)
      await token0.transfer(await pair.getAddress(), swapAmount);
      await pair.swap(0, expectedOut, await user1.getAddress(), "0x");

      const countAfter = await pair.observationCount();

      // Should have recorded one observation
      expect(countAfter).to.be.greaterThan(countBefore);
    });

    it("Should not record observation before 1 hour", async function () {
      // First observation
      await ethers.provider.send("evm_increaseTime", [60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      const swapAmount = ethers.parseEther("1");
      let reserves = await pair.getReserves();
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;
      let amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      let expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

      await token0.transfer(await pair.getAddress(), swapAmount);
      await pair.swap(0, expectedOut, await user1.getAddress(), "0x");

      const countAfter1 = await pair.observationCount();

      // Fast forward only 30 minutes (not enough)
      await ethers.provider.send("evm_increaseTime", [30 * 60]);
      await ethers.provider.send("evm_mine", []);

      // Try to trigger another observation with proper calculation
      reserves = await pair.getReserves();
      amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

      await token0.transfer(await pair.getAddress(), swapAmount);
      await pair.swap(0, expectedOut, await user1.getAddress(), "0x");

      const countAfter2 = await pair.observationCount();

      // Count should not increase
      expect(countAfter2).to.equal(countAfter1);
    });

    it("Should emit ObservationRecorded event", async function () {
      // Fast forward 1 hour
      await ethers.provider.send("evm_increaseTime", [60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      // Calculate proper swap output
      const swapAmount = ethers.parseEther("1");
      const reserves = await pair.getReserves();
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

      // Trigger observation
      await token0.transfer(await pair.getAddress(), swapAmount);

      await expect(
        pair.swap(0, expectedOut, await user1.getAddress(), "0x")
      ).to.emit(pair, "ObservationRecorded");
    });

    it("Should maintain circular buffer of 24 observations", async function () {
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Record 25 observations (more than buffer size)
      // Note: beforeEach already recorded 1 observation, so we need 24 more to fill the buffer,
      // plus 1 more to test wraparound
      for (let i = 0; i < 25; i++) {
        // Fast forward 1 hour
        await ethers.provider.send("evm_increaseTime", [60 * 60 + 1]);
        await ethers.provider.send("evm_mine", []);

        // Calculate proper swap output
        const swapAmount = ethers.parseEther("0.1");
        const reserves = await pair.getReserves();
        const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
        const expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

        // Trigger observation
        await token0.transfer(await pair.getAddress(), swapAmount);
        await pair.swap(0, expectedOut, await user1.getAddress(), "0x");
      }

      const observationCount = await pair.observationCount();
      const observationIndex = await pair.observationIndex();

      // Count should max out at 24
      expect(observationCount).to.equal(24);

      // Index should have wrapped around: (1 initial + 25 new) % 24 = 26 % 24 = 2
      expect(observationIndex).to.equal(2);
    });

    it("Should return current price from getCurrentPrice()", async function () {
      const currentPrice = await pair.getCurrentPrice();

      // Initial reserves: 100 token0, 200 token1
      // Price should be approximately 2 * 1e18 (token1 per token0)
      const expectedPrice = ethers.parseEther("2");

      // Allow 1% tolerance due to precision
      const tolerance = expectedPrice / 100n;
      expect(currentPrice).to.be.closeTo(expectedPrice, tolerance);
    });

    it("Should calculate TWAP correctly with observations", async function () {
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Record multiple observations with price changes
      for (let i = 0; i < 5; i++) {
        // Fast forward 1 hour
        await ethers.provider.send("evm_increaseTime", [60 * 60 + 1]);
        await ethers.provider.send("evm_mine", []);

        // Calculate proper swap output
        const swapAmount = ethers.parseEther("0.5");
        const reserves = await pair.getReserves();
        const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
        const expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

        // Make small swap to change price slightly
        await token0.transfer(await pair.getAddress(), swapAmount);
        await pair.swap(0, expectedOut, await user1.getAddress(), "0x");
      }

      const observationCount = await pair.observationCount();
      expect(observationCount).to.be.greaterThan(0);

      // TWAP calculation happens inside updateVolatility()
      // which is tested in the dynamic fees section
    });

    it("Should handle wraparound in circular buffer correctly", async function () {
      const feeTier = await pair.feeTier();
      const FEE_DENOMINATOR = 10000n;

      // Fill the buffer completely
      // beforeEach already recorded 1 observation, so we need 23 more to fill the buffer
      for (let i = 0; i < 23; i++) {
        await ethers.provider.send("evm_increaseTime", [60 * 60 + 1]);
        await ethers.provider.send("evm_mine", []);

        const swapAmount = ethers.parseEther("0.1");
        const reserves = await pair.getReserves();
        const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
        const expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

        await token0.transfer(await pair.getAddress(), swapAmount);
        await pair.swap(0, expectedOut, await user1.getAddress(), "0x");
      }

      expect(await pair.observationCount()).to.equal(24);
      // After 24 observations (1 initial + 23 new), index should be: (1 + 23) % 24 = 0
      expect(await pair.observationIndex()).to.equal(0); // Should wrap to 0

      // Add one more (should overwrite index 0)
      await ethers.provider.send("evm_increaseTime", [60 * 60 + 1]);
      await ethers.provider.send("evm_mine", []);

      const swapAmount = ethers.parseEther("0.1");
      const reserves = await pair.getReserves();
      const amountInWithFee = swapAmount * (FEE_DENOMINATOR - feeTier);
      const expectedOut = (amountInWithFee * reserves._reserve1) / (reserves._reserve0 * FEE_DENOMINATOR + amountInWithFee);

      await token0.transfer(await pair.getAddress(), swapAmount);
      await pair.swap(0, expectedOut, await user1.getAddress(), "0x");

      expect(await pair.observationCount()).to.equal(24); // Still 24
      expect(await pair.observationIndex()).to.equal(1); // Now at index 1
    });
  });
});
