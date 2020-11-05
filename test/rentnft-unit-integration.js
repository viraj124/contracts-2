/**
 * execute with:
 *  #> npm run test:rentnft
 * */
const {accounts, contract, web3} = require("@openzeppelin/test-environment");
const {expectRevert, constants, time} = require("@openzeppelin/test-helpers");
const {expect} = require("chai");

const RentNftAddressProvider = contract.fromArtifact("RentNftAddressProvider");
const RentNft = contract.fromArtifact("RentNft");
const GanFaceNft = contract.fromArtifact("GanFaceNft");
const PaymentToken = contract.fromArtifact("PaymentToken");

const NILADDR = constants.ZERO_ADDRESS;
const INITBALANCE = "1000";
const UNLIMITED_ALLOWANCE = constants.MAX_UINT256;

let dai;
let rent;
let face;

const LOCAL_CHAIN_ID = "0";
const BORROW_PRICE = "1";
const MAX_DURATION = "5";
const NFT_PRICE = "11";
let tokenId = 0;

describe("RentNft", () => {
  const creatorAddress = accounts[0];
  const firstOwnerAddress = accounts[1];
  const secondOwnerAddress = accounts[2];
  // const externalAddress = accounts[3];
  const unprivilegedAddress = accounts[4];
  /* create named accounts for contract roles */

  before(async () => {
    dai = await PaymentToken.new({from: creatorAddress});
    resolver = await RentNftAddressProvider.new(LOCAL_CHAIN_ID, {
      from: creatorAddress
    });
    rent = await RentNft.new(resolver.address, {from: creatorAddress});
    face = await GanFaceNft.new({from: creatorAddress});

    await resolver.setDai(dai.address, {from: creatorAddress});

    // approvals for NFT and DAI handling by the rent contract
    await face.setApprovalForAll(rent.address, true, {
      from: firstOwnerAddress
    });
    await face.setApprovalForAll(rent.address, true, {
      from: secondOwnerAddress
    });
    await face.setApprovalForAll(rent.address, true, {
      from: creatorAddress
    });
    await face.setApprovalForAll(rent.address, true, {
      from: unprivilegedAddress
    });
    await dai.approve(rent.address, UNLIMITED_ALLOWANCE, {
      from: firstOwnerAddress
    });
    await dai.approve(rent.address, UNLIMITED_ALLOWANCE, {
      from: secondOwnerAddress
    });
    await dai.approve(rent.address, UNLIMITED_ALLOWANCE, {
      from: unprivilegedAddress
    });
    await dai.approve(rent.address, UNLIMITED_ALLOWANCE, {
      from: creatorAddress
    });

    // giving the lenders and borrowers some DAI
    dai.transfer(firstOwnerAddress, INITBALANCE, {from: creatorAddress});
    dai.transfer(secondOwnerAddress, INITBALANCE, {from: creatorAddress});
    dai.transfer(unprivilegedAddress, INITBALANCE, {from: creatorAddress});
  });

  it("should lend one NFT", async () => {
    const fakeTokenURI = "https://fake.ipfs.image.link";
    await face.awardGanFace(firstOwnerAddress, fakeTokenURI, {
      from: creatorAddress
    });
    tokenId++;
    await rent.lendOne(
      face.address,
      tokenId,
      MAX_DURATION,
      BORROW_PRICE,
      NFT_PRICE,
      {from: firstOwnerAddress}
    );
    const nftOwner = await face.ownerOf(tokenId);
    expect(nftOwner).to.eq(rent.address);
  });

  it("should lend multiple NFT", async () => {
    const fakeTokenURI = "https://fake.ipfs.image.link";
    await face.awardGanFace(secondOwnerAddress, fakeTokenURI);
    await face.awardGanFace(secondOwnerAddress, `${fakeTokenURI}.new.face`);
    const tokenId1 = ++tokenId;
    const tokenId2 = ++tokenId;
    await rent.lendMultiple(
      [face.address, face.address],
      [tokenId1, tokenId2], // tokenIds
      ["5", "10"], // maxDuration
      ["1", "2"], // daily borrow price
      ["10", "11"], // collateral
      {from: secondOwnerAddress}
    );
    const nft2 = await rent.nfts(face.address, tokenId1);
    const nft3 = await rent.nfts(face.address, tokenId2);

    expect(nft2.lender).to.eq(secondOwnerAddress);
    expect(nft2.borrower).to.eq(NILADDR);
    expect(nft2.maxDuration).to.be.bignumber.eq("5");
    expect(nft2.actualDuration).to.be.bignumber.eq("0");
    expect(nft2.borrowPrice).to.be.bignumber.eq("1");
    expect(nft2.nftPrice).to.be.bignumber.eq("10");

    expect(nft3.lender).to.eq(secondOwnerAddress);
    expect(nft3.borrower).to.eq(NILADDR);
    expect(nft3.maxDuration).to.be.bignumber.eq("10");
    expect(nft3.actualDuration).to.be.bignumber.eq("0");
    expect(nft3.borrowPrice).to.be.bignumber.eq("2");
    expect(nft3.nftPrice).to.be.bignumber.eq("11");
  });

  it("should revert when actualDuration is higher than Max when renting out one NFT", async () => {
    // lend
    const fakeTokenURI = "https://fake.ipfs.image.link";
    await face.awardGanFace(firstOwnerAddress, fakeTokenURI, {
      from: creatorAddress
    });
    tokenId++;
    await rent.lendOne(
      face.address,
      tokenId,
      MAX_DURATION,
      BORROW_PRICE,
      NFT_PRICE,
      {from: firstOwnerAddress}
    );
    // rent
    const rentDuration = "6"; // 6 days. Max is 5 days.
    await expectRevert(
      rent.rentOne(unprivilegedAddress, face.address, tokenId, rentDuration, {
        from: unprivilegedAddress
      }),
      "Max Duration exceeded"
    );
  });

  it("should rent one NFT", async () => {
    const iniDaiBalanceRent = await dai.balanceOf(rent.address);
    const iniDaiBalanceFOA = await dai.balanceOf(firstOwnerAddress);
    const iniDaiBalanceUA = await dai.balanceOf(unprivilegedAddress);

    // unprivilidged account now rents the NFT
    const rentDuration = "2"; // 2 days
    await rent.rentOne(
      unprivilegedAddress,
      face.address,
      tokenId,
      rentDuration,
      {
        from: unprivilegedAddress
      }
    );

    const nft = await rent.nfts(face.address, tokenId);

    expect(nft.lender).to.eq(firstOwnerAddress);
    expect(nft.borrower).to.eq(unprivilegedAddress);
    expect(nft.maxDuration).to.be.bignumber.eq(MAX_DURATION);
    expect(nft.actualDuration).to.be.bignumber.eq(rentDuration);
    expect(nft.borrowPrice).to.be.bignumber.eq(BORROW_PRICE);
    expect(nft.nftPrice).to.be.bignumber.eq(NFT_PRICE);

    const finalDaiBalanceRent = await dai.balanceOf(rent.address);
    expect(finalDaiBalanceRent.sub(iniDaiBalanceRent)).to.be.bignumber.eq(
      NFT_PRICE
    );
    const finaDaiBalanceFOA = await dai.balanceOf(firstOwnerAddress);
    // 1 DAI * 2 days = 2 DAI
    expect(finaDaiBalanceFOA.sub(iniDaiBalanceFOA)).to.be.bignumber.eq("2");
    // (1 DAI * 2 days) + 11 DAI (collateral) = 2 + 11 = 13
    const finalDaiBalanceUA = await dai.balanceOf(unprivilegedAddress);
    expect(iniDaiBalanceUA.sub(finalDaiBalanceUA)).to.be.bignumber.eq("13");
  });

  it("should rent multiple NFTs", async () => {
    // lend multiple
    const fakeTokenURI = "https://fake.ipfs.image.link";
    await face.awardGanFace(firstOwnerAddress, fakeTokenURI);
    await face.awardGanFace(firstOwnerAddress, `${fakeTokenURI}.new.face`);
    const tokenId1 = ++tokenId;
    const tokenId2 = ++tokenId;
    await rent.lendMultiple(
      [face.address, face.address],
      [tokenId1, tokenId2], // tokenIds
      ["5", "10"], // maxDuration
      ["1", "2"], // daily borrow price
      ["10", "11"], // collateral
      {from: firstOwnerAddress}
    );

    const iniDaiBalanceRent = await dai.balanceOf(rent.address);
    const iniDaiBalanceFOA = await dai.balanceOf(firstOwnerAddress);
    const iniDaiBalanceUA = await dai.balanceOf(unprivilegedAddress);

    // unprivilidged account now rents multiple NFT
    await rent.rentMultiple(
      unprivilegedAddress,
      [face.address, face.address],
      [tokenId1, tokenId2],
      ["2", "4"], // actualDurations
      {
        from: unprivilegedAddress
      }
    );

    const nft1 = await rent.nfts(face.address, tokenId1);
    expect(nft1.lender).to.eq(firstOwnerAddress);
    expect(nft1.borrower).to.eq(unprivilegedAddress);
    expect(nft1.maxDuration).to.be.bignumber.eq("5");
    expect(nft1.actualDuration).to.be.bignumber.eq("2");
    expect(nft1.borrowPrice).to.be.bignumber.eq("1");
    expect(nft1.nftPrice).to.be.bignumber.eq("10");

    const nft2 = await rent.nfts(face.address, tokenId2);
    expect(nft2.lender).to.eq(firstOwnerAddress);
    expect(nft2.borrower).to.eq(unprivilegedAddress);
    expect(nft2.maxDuration).to.be.bignumber.eq("10");
    expect(nft2.actualDuration).to.be.bignumber.eq("4");
    expect(nft2.borrowPrice).to.be.bignumber.eq("2");
    expect(nft2.nftPrice).to.be.bignumber.eq("11");

    const finalDaiBalanceRent = await dai.balanceOf(rent.address);
    // summation of nftPrices (collateral) = 10+11 = 21
    expect(finalDaiBalanceRent.sub(iniDaiBalanceRent)).to.be.bignumber.eq("21");
    const finaDaiBalanceFOA = await dai.balanceOf(firstOwnerAddress);
    // summation actualDuration * borrowPrice = 2*1 + 4*2 = 2+8 = 10
    expect(finaDaiBalanceFOA.sub(iniDaiBalanceFOA)).to.be.bignumber.eq("10");
    // 10+21 = 31
    const finalDaiBalanceUA = await dai.balanceOf(unprivilegedAddress);
    expect(iniDaiBalanceUA.sub(finalDaiBalanceUA)).to.be.bignumber.eq("31");
  });

  context("RETURN", () => {
    beforeEach(async () => {
      // lend NFT
      const fakeTokenURI = "https://fake.ipfs.image.link";
      await face.awardGanFace(firstOwnerAddress, fakeTokenURI, {
        from: creatorAddress
      });
      tokenId++;
      await rent.lendOne(
        face.address,
        tokenId,
        MAX_DURATION,
        BORROW_PRICE,
        NFT_PRICE,
        {from: firstOwnerAddress}
      );
      // unprivilidged account now rents the NFT
      dai.transfer(unprivilegedAddress, INITBALANCE, {from: creatorAddress});
      const rentDuration = "2"; // 2 days
      await rent.rentOne(
        unprivilegedAddress,
        face.address,
        tokenId,
        rentDuration,
        {
          from: unprivilegedAddress
        }
      );
    });
    it("should allow user to Return One NFT before duration exceeds", async () => {
      const iniTokenBal = await dai.balanceOf(unprivilegedAddress);
      await rent.returnNftOne(face.address, tokenId, {
        from: unprivilegedAddress
      });
      const finalTokenBal = await dai.balanceOf(unprivilegedAddress);
      // transfer DAI back
      expect(finalTokenBal.sub(iniTokenBal)).to.be.bignumber.eq(NFT_PRICE);

      const nftOwner = await face.ownerOf(tokenId);
      // transfer NFT back
      expect(nftOwner).to.eq(rent.address);

      const nft = await rent.nfts(face.address, tokenId);
      expect(nft.borrower).to.eq(NILADDR);
      expect(nft.actualDuration).to.be.bignumber.eq("0");
      expect(nft.borrowedAt).to.be.bignumber.eq("0");
    });
    it("should revert when duration exceeds & user tries to Return NFT", async () => {
      // advance time by 3 days and 1 sec
      await time.increase(3 * 24 * 60 * 60 + 1);

      await expectRevert(
        rent.returnNftOne(face.address, tokenId, {
          from: unprivilegedAddress
        }),
        "duration exceeded"
      );
    });
    it("should allow owner to claim collateral in case of default", async () => {
      // advance time by 3 days and 1 sec
      await time.increase(3 * 24 * 60 * 60 + 1);

      const iniTokenBal = await dai.balanceOf(firstOwnerAddress);
      await rent.claimCollateral(face.address, tokenId, {
        from: firstOwnerAddress
      });
      const finalTokenBal = await dai.balanceOf(firstOwnerAddress);
      // transfer DAI back
      expect(finalTokenBal).to.be.bignumber.gt(iniTokenBal);
    });
  });

  it("should return multiple NFTs", async () => {
    // lend multiple
    const fakeTokenURI = "https://fake.ipfs.image.link";
    await face.awardGanFace(firstOwnerAddress, fakeTokenURI);
    await face.awardGanFace(firstOwnerAddress, `${fakeTokenURI}.new.face`);
    const tokenId1 = ++tokenId;
    const tokenId2 = ++tokenId;
    await rent.lendMultiple(
      [face.address, face.address],
      [tokenId1, tokenId2], // tokenIds
      ["5", "10"], // maxDuration
      ["1", "2"], // daily borrow price
      ["10", "11"], // collateral
      {from: firstOwnerAddress}
    );
    // unprivilidged account now rents multiple NFT
    await rent.rentMultiple(
      unprivilegedAddress,
      [face.address, face.address],
      [tokenId1, tokenId2],
      ["2", "4"], // actualDurations
      {
        from: unprivilegedAddress
      }
    );

    // Return Multiple
    const iniTokenBal = await dai.balanceOf(unprivilegedAddress);
    await rent.returnNftMultiple(
      [face.address, face.address],
      [tokenId1, tokenId2],
      {
        from: unprivilegedAddress
      }
    );
    const finalTokenBal = await dai.balanceOf(unprivilegedAddress);
    // summation of nftPrices (collateral) = 10+11 = 21
    expect(finalTokenBal.sub(iniTokenBal)).to.be.bignumber.eq("21");
  });

  it("should allow lender to stop lending", async () => {
    // lend NFT
    const fakeTokenURI = "https://fake.ipfs.image.link";
    await face.awardGanFace(firstOwnerAddress, fakeTokenURI, {
      from: creatorAddress
    });
    tokenId++;
    await rent.lendOne(
      face.address,
      tokenId,
      MAX_DURATION,
      BORROW_PRICE,
      NFT_PRICE,
      {from: firstOwnerAddress}
    );
    const nftOwner = await face.ownerOf(tokenId);
    expect(nftOwner).to.eq(rent.address);

    await rent.stopLending(face.address, tokenId, {
      from: firstOwnerAddress
    });
    const newNftOwner = await face.ownerOf(tokenId);
    expect(newNftOwner).to.eq(firstOwnerAddress);
  });
});
