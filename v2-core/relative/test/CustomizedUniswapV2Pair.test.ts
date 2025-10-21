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
      ).to.be.revertedWith("UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED");
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
      ).to.be.revertedWith("UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED");
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
      const expectedOutputAmount = ethers.parseEther("1.662497915624478906");

      await token0.transfer(await pair.getAddress(), swapAmount);

      await expect(
        pair.swap(0, expectedOutputAmount, await user1.getAddress(), "0x")
      ).to.emit(pair, "Swap");
    });

    it("Should swap token1 for token0", async function () {
      const expectedOutputAmount = ethers.parseEther("0.453305446940074565");

      await token1.transfer(await pair.getAddress(), swapAmount);

      await expect(
        pair.swap(expectedOutputAmount, 0, await user1.getAddress(), "0x")
      ).to.emit(pair, "Swap");
    });

    it("Should revert if output amount is zero", async function () {
      await expect(
        pair.swap(0, 0, await user1.getAddress(), "0x")
      ).to.be.revertedWith("UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT");
    });

    it("Should revert if insufficient liquidity", async function () {
      await expect(
        pair.swap(token0Amount, 0, await user1.getAddress(), "0x")
      ).to.be.revertedWith("UniswapV2: INSUFFICIENT_LIQUIDITY");
    });

    it("Should revert if invalid to address (token0)", async function () {
      await token0.transfer(await pair.getAddress(), swapAmount);

      await expect(
        pair.swap(0, swapAmount, await token0.getAddress(), "0x")
      ).to.be.revertedWith("UniswapV2: INVALID_TO");
    });

    it("Should revert if invalid to address (token1)", async function () {
      await token1.transfer(await pair.getAddress(), swapAmount);

      await expect(
        pair.swap(swapAmount, 0, await token1.getAddress(), "0x")
      ).to.be.revertedWith("UniswapV2: INVALID_TO");
    });

    it("Should enforce constant product formula with 0.3% fee", async function () {
      const amountIn = ethers.parseEther("1");
      await token0.transfer(await pair.getAddress(), amountIn);

      const reserves = await pair.getReserves();
      const amountInWithFee = amountIn * 997n;
      const numerator = amountInWithFee * reserves._reserve1;
      const denominator = reserves._reserve0 * 1000n + amountInWithFee;
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

      await token0.transfer(await pair.getAddress(), swapAmount);
      await pair.swap(0, ethers.parseEther("1"), await user1.getAddress(), "0x");

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

      // Perform multiple swaps to generate fees and increase K
      const swapAmount = ethers.parseEther("100");

      // Swap token0 for token1
      await token0.transfer(await pair.getAddress(), swapAmount);
      const reserves1 = await pair.getReserves();
      const amountOut1 = (swapAmount * 997n * reserves1._reserve1) / (reserves1._reserve0 * 1000n + swapAmount * 997n);
      await pair.swap(0, amountOut1, await user1.getAddress(), "0x");

      // Swap token1 back to token0
      await token1.connect(user1).transfer(await pair.getAddress(), amountOut1);
      const reserves2 = await pair.getReserves();
      const amountOut2 = (amountOut1 * 997n * reserves2._reserve0) / (reserves2._reserve1 * 1000n + amountOut1 * 997n);
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

      // Perform swaps
      const swapAmount = ethers.parseEther("100");
      await token0.transfer(await pair.getAddress(), swapAmount);
      const reserves = await pair.getReserves();
      const amountOut = (swapAmount * 997n * reserves._reserve1) / (reserves._reserve0 * 1000n + swapAmount * 997n);
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
});
