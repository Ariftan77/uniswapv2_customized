import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("CustomizedUniswapV2ERC20", function () {
  let token: any;
  let owner: any;
  let user1: any;
  let user2: any;

  const TOTAL_SUPPLY = ethers.parseEther("10000");

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy ERC20 test token
    const Token = await ethers.getContractFactory("ERC20");
    token = await Token.deploy(TOTAL_SUPPLY);
  });

  describe("Token Metadata", function () {
    it("Should have correct name", async function () {
      expect(await token.name()).to.equal("Uniswap V2");
    });

    it("Should have correct symbol", async function () {
      expect(await token.symbol()).to.equal("UNI-V2");
    });

    it("Should have 18 decimals", async function () {
      expect(await token.decimals()).to.equal(18);
    });

    it("Should have correct total supply", async function () {
      expect(await token.totalSupply()).to.equal(TOTAL_SUPPLY);
    });

    it("Should mint initial supply to deployer", async function () {
      expect(await token.balanceOf(await owner.getAddress())).to.equal(TOTAL_SUPPLY);
    });
  });

  describe("Transfer", function () {
    it("Should transfer tokens between accounts", async function () {
      const transferAmount = ethers.parseEther("100");

      await token.transfer(await user1.getAddress(), transferAmount);

      expect(await token.balanceOf(await user1.getAddress())).to.equal(transferAmount);
      expect(await token.balanceOf(await owner.getAddress())).to.equal(TOTAL_SUPPLY - transferAmount);
    });

    it("Should emit Transfer event", async function () {
      const transferAmount = ethers.parseEther("100");

      await expect(token.transfer(await user1.getAddress(), transferAmount))
        .to.emit(token, "Transfer")
        .withArgs(await owner.getAddress(), await user1.getAddress(), transferAmount);
    });

    it("Should revert if sender doesn't have enough tokens", async function () {
      const transferAmount = ethers.parseEther("100");

      await expect(
        token.connect(user1).transfer(await user2.getAddress(), transferAmount)
      ).to.be.revertedWithPanic(0x11); // Arithmetic underflow in Solidity 0.8+
    });

    it("Should handle zero amount transfers", async function () {
      await expect(token.transfer(await user1.getAddress(), 0))
        .to.emit(token, "Transfer")
        .withArgs(await owner.getAddress(), await user1.getAddress(), 0);
    });
  });

  describe("Approve", function () {
    it("Should approve tokens for spender", async function () {
      const approvalAmount = ethers.parseEther("500");

      await token.approve(await user1.getAddress(), approvalAmount);

      expect(await token.allowance(await owner.getAddress(), await user1.getAddress()))
        .to.equal(approvalAmount);
    });

    it("Should emit Approval event", async function () {
      const approvalAmount = ethers.parseEther("500");

      await expect(token.approve(await user1.getAddress(), approvalAmount))
        .to.emit(token, "Approval")
        .withArgs(await owner.getAddress(), await user1.getAddress(), approvalAmount);
    });

    it("Should update approval on multiple approves", async function () {
      await token.approve(await user1.getAddress(), ethers.parseEther("100"));
      await token.approve(await user1.getAddress(), ethers.parseEther("200"));

      expect(await token.allowance(await owner.getAddress(), await user1.getAddress()))
        .to.equal(ethers.parseEther("200"));
    });

    it("Should approve zero amount", async function () {
      await token.approve(await user1.getAddress(), ethers.parseEther("100"));
      await token.approve(await user1.getAddress(), 0);

      expect(await token.allowance(await owner.getAddress(), await user1.getAddress()))
        .to.equal(0);
    });
  });

  describe("TransferFrom", function () {
    const approvalAmount = ethers.parseEther("500");
    const transferAmount = ethers.parseEther("200");

    beforeEach(async function () {
      await token.approve(await user1.getAddress(), approvalAmount);
    });

    it("Should transfer tokens using allowance", async function () {
      await token.connect(user1).transferFrom(
        await owner.getAddress(),
        await user2.getAddress(),
        transferAmount
      );

      expect(await token.balanceOf(await user2.getAddress())).to.equal(transferAmount);
      expect(await token.balanceOf(await owner.getAddress())).to.equal(TOTAL_SUPPLY - transferAmount);
    });

    it("Should decrease allowance after transfer", async function () {
      await token.connect(user1).transferFrom(
        await owner.getAddress(),
        await user2.getAddress(),
        transferAmount
      );

      expect(await token.allowance(await owner.getAddress(), await user1.getAddress()))
        .to.equal(approvalAmount - transferAmount);
    });

    it("Should emit Transfer event", async function () {
      await expect(
        token.connect(user1).transferFrom(
          await owner.getAddress(),
          await user2.getAddress(),
          transferAmount
        )
      ).to.emit(token, "Transfer")
        .withArgs(await owner.getAddress(), await user2.getAddress(), transferAmount);
    });

    it("Should revert if allowance is insufficient", async function () {
      const tooMuchAmount = ethers.parseEther("600");

      await expect(
        token.connect(user1).transferFrom(
          await owner.getAddress(),
          await user2.getAddress(),
          tooMuchAmount
        )
      ).to.be.revertedWithPanic(0x11); // Arithmetic underflow in Solidity 0.8+
    });

    it("Should not decrease allowance if allowance is max uint256", async function () {
      const maxAllowance = ethers.MaxUint256;
      await token.approve(await user1.getAddress(), maxAllowance);

      await token.connect(user1).transferFrom(
        await owner.getAddress(),
        await user2.getAddress(),
        transferAmount
      );

      expect(await token.allowance(await owner.getAddress(), await user1.getAddress()))
        .to.equal(maxAllowance);
    });

    it("Should revert if balance is insufficient", async function () {
      // Transfer most tokens away
      await token.transfer(await user2.getAddress(), TOTAL_SUPPLY - ethers.parseEther("100"));

      await expect(
        token.connect(user1).transferFrom(
          await owner.getAddress(),
          await user2.getAddress(),
          approvalAmount
        )
      ).to.be.revertedWithPanic(0x11);
    });
  });

  describe("Permit (EIP-2612)", function () {
    it("Should have correct DOMAIN_SEPARATOR", async function () {
      const domainSeparator = await token.DOMAIN_SEPARATOR();
      expect(domainSeparator).to.not.equal(ethers.ZeroHash);
    });

    it("Should have correct PERMIT_TYPEHASH", async function () {
      const expectedHash = ethers.keccak256(
        ethers.toUtf8Bytes("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
      );
      expect(await token.PERMIT_TYPEHASH()).to.equal(expectedHash);
    });

    it("Should have zero nonce initially", async function () {
      expect(await token.nonces(await owner.getAddress())).to.equal(0);
    });

    it("Should approve via permit signature", async function () {
      const value = ethers.parseEther("100");
      const nonce = await token.nonces(await owner.getAddress());
      const deadline = ethers.MaxUint256;

      const domain = {
        name: await token.name(),
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: await token.getAddress()
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" }
        ]
      };

      const message = {
        owner: await owner.getAddress(),
        spender: await user1.getAddress(),
        value: value,
        nonce: nonce,
        deadline: deadline
      };

      const signature = await owner.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await token.permit(
        await owner.getAddress(),
        await user1.getAddress(),
        value,
        deadline,
        v,
        r,
        s
      );

      expect(await token.allowance(await owner.getAddress(), await user1.getAddress()))
        .to.equal(value);
      expect(await token.nonces(await owner.getAddress())).to.equal(1);
    });

    it("Should increment nonce after permit", async function () {
      const value = ethers.parseEther("100");
      const nonce = await token.nonces(await owner.getAddress());
      const deadline = ethers.MaxUint256;

      const domain = {
        name: await token.name(),
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: await token.getAddress()
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" }
        ]
      };

      const message = {
        owner: await owner.getAddress(),
        spender: await user1.getAddress(),
        value: value,
        nonce: nonce,
        deadline: deadline
      };

      const signature = await owner.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      const nonceBefore = await token.nonces(await owner.getAddress());

      await token.permit(
        await owner.getAddress(),
        await user1.getAddress(),
        value,
        deadline,
        v,
        r,
        s
      );

      expect(await token.nonces(await owner.getAddress())).to.equal(nonceBefore + 1n);
    });

    it("Should revert if deadline has passed", async function () {
      const value = ethers.parseEther("100");
      const nonce = await token.nonces(await owner.getAddress());
      const deadline = Math.floor(Date.now() / 1000) - 1000; // Past deadline

      const domain = {
        name: await token.name(),
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: await token.getAddress()
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" }
        ]
      };

      const message = {
        owner: await owner.getAddress(),
        spender: await user1.getAddress(),
        value: value,
        nonce: nonce,
        deadline: deadline
      };

      const signature = await owner.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        token.permit(
          await owner.getAddress(),
          await user1.getAddress(),
          value,
          deadline,
          v,
          r,
          s
        )
      ).to.be.revertedWithCustomError(token, "PermitExpired");
    });

    it("Should revert with invalid signature", async function () {
      const value = ethers.parseEther("100");
      const nonce = await token.nonces(await owner.getAddress());
      const deadline = ethers.MaxUint256;

      // Sign with user1 but claim it's from owner
      const domain = {
        name: await token.name(),
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: await token.getAddress()
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" }
        ]
      };

      const message = {
        owner: await owner.getAddress(),
        spender: await user2.getAddress(),
        value: value,
        nonce: nonce,
        deadline: deadline
      };

      const signature = await user1.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        token.permit(
          await owner.getAddress(),
          await user2.getAddress(),
          value,
          deadline,
          v,
          r,
          s
        )
      ).to.be.revertedWithCustomError(token, "InvalidSignature");
    });

    it("Should revert with wrong nonce", async function () {
      const value = ethers.parseEther("100");
      const wrongNonce = 5n; // Wrong nonce
      const deadline = ethers.MaxUint256;

      const domain = {
        name: await token.name(),
        version: "1",
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: await token.getAddress()
      };

      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" }
        ]
      };

      const message = {
        owner: await owner.getAddress(),
        spender: await user1.getAddress(),
        value: value,
        nonce: wrongNonce,
        deadline: deadline
      };

      const signature = await owner.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);

      await expect(
        token.permit(
          await owner.getAddress(),
          await user1.getAddress(),
          value,
          deadline,
          v,
          r,
          s
        )
      ).to.be.revertedWithCustomError(token, "InvalidSignature");
    });
  });

  describe("Balance Updates", function () {
    it("Should correctly update balances on multiple transfers", async function () {
      const amount1 = ethers.parseEther("100");
      const amount2 = ethers.parseEther("200");
      const amount3 = ethers.parseEther("50");

      await token.transfer(await user1.getAddress(), amount1);
      await token.transfer(await user2.getAddress(), amount2);
      await token.connect(user1).transfer(await user2.getAddress(), amount3);

      expect(await token.balanceOf(await owner.getAddress()))
        .to.equal(TOTAL_SUPPLY - amount1 - amount2);
      expect(await token.balanceOf(await user1.getAddress()))
        .to.equal(amount1 - amount3);
      expect(await token.balanceOf(await user2.getAddress()))
        .to.equal(amount2 + amount3);
    });
  });
});
