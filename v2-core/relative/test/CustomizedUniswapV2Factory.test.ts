import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("CustomizedUniswapV2Factory", function () {
  let factory: any;
  let owner: any;
  let feeToSetter: any;
  let other: any;
  let tokenA: any;
  let tokenB: any;

  beforeEach(async function () {
    [owner, feeToSetter, other] = await ethers.getSigners();

    // Deploy factory
    const Factory = await ethers.getContractFactory("CustomizedUniswapV2Factory");
    factory = await Factory.deploy(await feeToSetter.getAddress());

    // Deploy test tokens
    const Token = await ethers.getContractFactory("ERC20");
    tokenA = await Token.deploy(ethers.parseEther("10000"));
    tokenB = await Token.deploy(ethers.parseEther("10000"));
  });

  describe("Deployment", function () {
    it("Should set the correct feeToSetter", async function () {
      expect(await factory.feeToSetter()).to.equal(await feeToSetter.getAddress());
    });

    it("Should have feeTo as zero address initially", async function () {
      expect(await factory.feeTo()).to.equal(ethers.ZeroAddress);
    });

    it("Should have zero pairs initially", async function () {
      expect(await factory.allPairsLength()).to.equal(0);
    });
  });

  describe("createPair", function () {
    it("Should create a new pair", async function () {
      const tx = await factory.createPair(
        await tokenA.getAddress(),
        await tokenB.getAddress()
      );

      const receipt = await tx.wait();
      const pairAddress = await factory.getPair(
        await tokenA.getAddress(),
        await tokenB.getAddress()
      );

      expect(pairAddress).to.not.equal(ethers.ZeroAddress);
      expect(await factory.allPairsLength()).to.equal(1);
    });

    it("Should emit PairCreated event", async function () {
      const tokenAAddr = await tokenA.getAddress();
      const tokenBAddr = await tokenB.getAddress();

      await expect(factory.createPair(tokenAAddr, tokenBAddr))
        .to.emit(factory, "PairCreated");
    });

    it("Should create same pair address regardless of token order", async function () {
      const tokenAAddr = await tokenA.getAddress();
      const tokenBAddr = await tokenB.getAddress();

      await factory.createPair(tokenAAddr, tokenBAddr);
      const pair1 = await factory.getPair(tokenAAddr, tokenBAddr);
      const pair2 = await factory.getPair(tokenBAddr, tokenAAddr);

      expect(pair1).to.equal(pair2);
    });

    it("Should revert if tokens are identical", async function () {
      const tokenAAddr = await tokenA.getAddress();

      await expect(
        factory.createPair(tokenAAddr, tokenAAddr)
      ).to.be.revertedWith("UniswapV2: IDENTICAL_ADDRESSES");
    });

    it("Should revert if token is zero address", async function () {
      await expect(
        factory.createPair(ethers.ZeroAddress, await tokenA.getAddress())
      ).to.be.revertedWith("UniswapV2: ZERO_ADDRESS");
    });

    it("Should revert if pair already exists", async function () {
      const tokenAAddr = await tokenA.getAddress();
      const tokenBAddr = await tokenB.getAddress();

      await factory.createPair(tokenAAddr, tokenBAddr);

      await expect(
        factory.createPair(tokenAAddr, tokenBAddr)
      ).to.be.revertedWith("UniswapV2: PAIR_EXISTS");
    });

    it("Should revert if pair already exists (reversed order)", async function () {
      const tokenAAddr = await tokenA.getAddress();
      const tokenBAddr = await tokenB.getAddress();

      await factory.createPair(tokenAAddr, tokenBAddr);

      await expect(
        factory.createPair(tokenBAddr, tokenAAddr)
      ).to.be.revertedWith("UniswapV2: PAIR_EXISTS");
    });

    it("Should create multiple different pairs", async function () {
      const Token = await ethers.getContractFactory("ERC20");
      const tokenC = await Token.deploy(ethers.parseEther("10000"));

      await factory.createPair(await tokenA.getAddress(), await tokenB.getAddress());
      await factory.createPair(await tokenA.getAddress(), await tokenC.getAddress());
      await factory.createPair(await tokenB.getAddress(), await tokenC.getAddress());

      expect(await factory.allPairsLength()).to.equal(3);
    });
  });

  describe("setFeeTo", function () {
    it("Should allow feeToSetter to set feeTo", async function () {
      const newFeeTo = await other.getAddress();
      await factory.connect(feeToSetter).setFeeTo(newFeeTo);

      expect(await factory.feeTo()).to.equal(newFeeTo);
    });

    it("Should revert if non-feeToSetter tries to set feeTo", async function () {
      await expect(
        factory.connect(other).setFeeTo(await other.getAddress())
      ).to.be.revertedWith("UniswapV2: FORBIDDEN");
    });
  });

  describe("setFeeToSetter", function () {
    it("Should allow feeToSetter to change feeToSetter", async function () {
      const newFeeToSetter = await other.getAddress();
      await factory.connect(feeToSetter).setFeeToSetter(newFeeToSetter);

      expect(await factory.feeToSetter()).to.equal(newFeeToSetter);
    });

    it("Should revert if non-feeToSetter tries to change feeToSetter", async function () {
      await expect(
        factory.connect(other).setFeeToSetter(await other.getAddress())
      ).to.be.revertedWith("UniswapV2: FORBIDDEN");
    });

    it("Should allow new feeToSetter to set feeTo after transfer", async function () {
      const newFeeToSetter = await other.getAddress();
      await factory.connect(feeToSetter).setFeeToSetter(newFeeToSetter);

      const newFeeTo = await owner.getAddress();
      await factory.connect(other).setFeeTo(newFeeTo);

      expect(await factory.feeTo()).to.equal(newFeeTo);
    });
  });
});
