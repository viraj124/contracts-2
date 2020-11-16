/**
 * execute with:
 *  #> npm run test:rentnft
 * */
const {accounts, contract} = require("@openzeppelin/test-environment");
const {
  expectRevert,
  BN,
  constants,
  time
} = require("@openzeppelin/test-helpers");
const {expect} = require("chai");

const RentNft = contract.fromArtifact("RentNft");
const GanFaceNft = contract.fromArtifact("GanFaceNft");
const PaymentToken = contract.fromArtifact("PaymentToken");

const NILADDR = constants.ZERO_ADDRESS;
const INITBALANCE = "1000";
const UNLIMITED_ALLOWANCE = constants.MAX_UINT256;

let erc20;
let rent;
let face;

// const LOCAL_CHAIN_ID = "0";
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
    erc20 = await PaymentToken.new({from: creatorAddress});
    rent = await RentNft.new({from: creatorAddress});
    face = await GanFaceNft.new({from: creatorAddress});

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
    await erc20.approve(rent.address, UNLIMITED_ALLOWANCE, {
      from: firstOwnerAddress
    });
    await erc20.approve(rent.address, UNLIMITED_ALLOWANCE, {
      from: secondOwnerAddress
    });
    await erc20.approve(rent.address, UNLIMITED_ALLOWANCE, {
      from: unprivilegedAddress
    });
    await erc20.approve(rent.address, UNLIMITED_ALLOWANCE, {
      from: creatorAddress
    });

    // giving the lenders and borrowers some DAI
    erc20.transfer(firstOwnerAddress, INITBALANCE, {from: creatorAddress});
    erc20.transfer(secondOwnerAddress, INITBALANCE, {from: creatorAddress});
    erc20.transfer(unprivilegedAddress, INITBALANCE, {from: creatorAddress});
  });

  context("LEND", () => {
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
        erc20.address,
        {from: firstOwnerAddress}
      );
      const nftOwner = await face.ownerOf(tokenId);
      expect(nftOwner).to.eq(rent.address);

      const listingCount = await rent.getListingCount();
      const nft1 = await rent.listings(listingCount.sub(new BN("1")));

      expect(nft1.lender).to.eq(firstOwnerAddress);
      expect(nft1.nftAddress).to.eq(face.address);
      expect(nft1.tokenId).to.be.bignumber.eq(tokenId.toString());
      expect(nft1.maxDuration).to.be.bignumber.eq(MAX_DURATION);
      expect(nft1.dailyBorrowPrice).to.be.bignumber.eq(BORROW_PRICE);
      expect(nft1.nftPrice).to.be.bignumber.eq(NFT_PRICE);
      expect(nft1.token).to.eq(erc20.address);
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
        [erc20.address, erc20.address],
        {from: secondOwnerAddress}
      );
      const nft1Owner = await face.ownerOf(tokenId1);
      const nft2Owner = await face.ownerOf(tokenId2);
      expect(nft1Owner).to.eq(rent.address);
      expect(nft2Owner).to.eq(rent.address);

      const listingCount = await rent.getListingCount();
      const nft1 = await rent.listings(listingCount.sub(new BN("2")));
      const nft2 = await rent.listings(listingCount.sub(new BN("1")));

      expect(nft1.lender).to.eq(secondOwnerAddress);
      expect(nft1.nftAddress).to.eq(face.address);
      expect(nft1.tokenId).to.be.bignumber.eq(tokenId1.toString());
      expect(nft1.maxDuration).to.be.bignumber.eq("5");
      expect(nft1.dailyBorrowPrice).to.be.bignumber.eq("1");
      expect(nft1.nftPrice).to.be.bignumber.eq("10");
      expect(nft1.token).to.eq(erc20.address);

      expect(nft2.lender).to.eq(secondOwnerAddress);
      expect(nft2.nftAddress).to.eq(face.address);
      expect(nft2.tokenId).to.be.bignumber.eq(tokenId2.toString());
      expect(nft2.maxDuration).to.be.bignumber.eq("10");
      expect(nft2.dailyBorrowPrice).to.be.bignumber.eq("2");
      expect(nft2.nftPrice).to.be.bignumber.eq("11");
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
        erc20.address,
        {from: firstOwnerAddress}
      );
      // rent
      const listingCount = await rent.getListingCount();
      const listingIndex = listingCount.sub(new BN("1"));
      const rentDuration = "6"; // 6 days. Max is 5 days.
      await expectRevert(
        rent.rentOne(unprivilegedAddress, listingIndex, rentDuration, {
          from: unprivilegedAddress
        }),
        "max duration exceeded"
      );
    });

    it("should allow lender to stop lending", async () => {
      const listingCount = await rent.getListingCount();
      const listingIndex = listingCount.sub(new BN("1"));
      const inilisting = await rent.listings(listingIndex);
      const tokenId = inilisting.tokenId;

      await rent.stopLending(listingIndex, {
        from: firstOwnerAddress
      });

      const listing = await rent.listings(listingIndex);

      const newNftOwner = await face.ownerOf(tokenId);
      expect(newNftOwner).to.eq(firstOwnerAddress);

      expect(listing.lender).to.eq(NILADDR);
      expect(listing.nftAddress).to.eq(NILADDR);
      expect(listing.tokenId).to.be.bignumber.eq("0");
      expect(listing.maxDuration).to.be.bignumber.eq("0");
      expect(listing.dailyBorrowPrice).to.be.bignumber.eq("0");
      expect(listing.nftPrice).to.be.bignumber.eq("0");
      expect(listing.token).to.eq(NILADDR);
    });
  });

  context("BORROW", () => {
    beforeEach(async () => {
      // lend 2 nfts
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
        [erc20.address, erc20.address],
        {from: firstOwnerAddress}
      );
    });

    it("should borrow one NFT", async () => {
      const listingCount = await rent.getListingCount();
      const listingIndex = listingCount.sub(new BN("1"));

      // unprivilidged account now rents the NFT
      const rentDuration = "2"; // 2 days
      await rent.rentOne(unprivilegedAddress, listingIndex, rentDuration, {
        from: unprivilegedAddress
      });

      const rentalCount = await rent.getBorrowCount();
      const rental = await rent.borrows(rentalCount.sub(new BN("1")));
      const listing = await rent.listings(listingIndex);

      expect(listing.isBorrowed).to.be.true;
      expect(rental.borrower).to.eq(unprivilegedAddress);
      expect(rental.listingIndex).to.be.bignumber.eq(listingIndex);
      expect(rental.actualDuration).to.be.bignumber.eq(rentDuration);
    });

    it("should borrow multiple NFTs", async () => {
      const listingCount = await rent.getListingCount();
      const listingIndex1 = listingCount.sub(new BN("2"));
      const listingIndex2 = listingCount.sub(new BN("1"));

      const iniDaiBalanceRent = await erc20.balanceOf(rent.address);
      const iniDaiBalanceFOA = await erc20.balanceOf(firstOwnerAddress);
      const iniDaiBalanceUA = await erc20.balanceOf(unprivilegedAddress);

      // unprivilidged account now rents multiple NFT
      await rent.rentMultiple(
        unprivilegedAddress,
        [listingIndex1, listingIndex2],
        ["2", "4"], // actualDurations
        {
          from: unprivilegedAddress
        }
      );
      const rentalCount = await rent.getBorrowCount();
      const rental1 = await rent.borrows(rentalCount.sub(new BN("2")));
      const listing1 = await rent.listings(listingIndex1);
      expect(listing1.isBorrowed).to.be.true;
      expect(rental1.borrower).to.eq(unprivilegedAddress);
      expect(rental1.listingIndex).to.be.bignumber.eq(listingIndex1);
      expect(rental1.actualDuration).to.be.bignumber.eq(new BN("2"));

      const rental2 = await rent.borrows(rentalCount.sub(new BN("1")));
      const listing2 = await rent.listings(listingIndex2);
      expect(listing2.isBorrowed).to.be.true;
      expect(rental2.borrower).to.eq(unprivilegedAddress);
      expect(rental2.listingIndex).to.be.bignumber.eq(listingIndex2);
      expect(rental2.actualDuration).to.be.bignumber.eq(new BN("4"));

      const finalDaiBalanceRent = await erc20.balanceOf(rent.address);

      // summation of nftPrices (collateral) = 10+11 = 21
      expect(finalDaiBalanceRent.sub(iniDaiBalanceRent)).to.be.bignumber.eq(
        "21"
      );
      const finaDaiBalanceFOA = await erc20.balanceOf(firstOwnerAddress);

      // summation actualDuration * borrowPrice = 2*1 + 4*2 = 2+8 = 10
      expect(finaDaiBalanceFOA.sub(iniDaiBalanceFOA)).to.be.bignumber.eq("10");
      // 10+21 = 31
      const finalDaiBalanceUA = await erc20.balanceOf(unprivilegedAddress);
      expect(iniDaiBalanceUA.sub(finalDaiBalanceUA)).to.be.bignumber.eq("31");
    });
  });

  context("RETURN", () => {
    beforeEach(async () => {
      // lend 2 nfts
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
        [erc20.address, erc20.address],
        {from: firstOwnerAddress}
      );
      // unprivilidged account now borrows the 2 NFTs
      erc20.transfer(unprivilegedAddress, INITBALANCE, {from: creatorAddress});
      const listingCount = await rent.getListingCount();
      const listingIndex1 = listingCount.sub(new BN("2"));
      const listingIndex2 = listingCount.sub(new BN("1"));
      await rent.rentMultiple(
        unprivilegedAddress,
        [listingIndex1, listingIndex2],
        ["2", "4"], // actualDurations
        {
          from: unprivilegedAddress
        }
      );
    });

    it("should allow user to Return One NFT before duration exceeds", async () => {
      const rentalCount = await rent.getBorrowCount();
      const rentalIndex = rentalCount.sub(new BN("1"));
      const iniRental = await rent.borrows(rentalIndex);
      const listingIndex = iniRental.listingIndex;
      await rent.returnNftOne(rentalIndex, {
        from: unprivilegedAddress
      });

      const nftOwner = await face.ownerOf(tokenId);
      // transfer NFT back
      expect(nftOwner).to.eq(rent.address);

      const rental = await rent.borrows(rentalIndex);
      const listing = await rent.listings(listingIndex);
      expect(listing.isBorrowed).to.be.false;
      expect(rental.borrower).to.eq(NILADDR);
      expect(rental.listingIndex).to.be.bignumber.eq("0");
      expect(rental.actualDuration).to.be.bignumber.eq("0");
      expect(rental.borrowedAt).to.be.bignumber.eq("0");
    });

    it("should revert when duration exceeds & user tries to Return NFT", async () => {
      // advance time by 10 days and 1 sec
      await time.increase(10 * 24 * 60 * 60 + 1);

      const rentalCount = await rent.getBorrowCount();
      const rentalIndex = rentalCount.sub(new BN("1"));
      await expectRevert(
        rent.returnNftOne(rentalIndex, {
          from: unprivilegedAddress
        }),
        "duration exceeded"
      );
    });

    it("should allow owner to claim collateral in case of default", async () => {
      // advance time by 10 days and 1 sec
      await time.increase(10 * 24 * 60 * 60 + 1);

      const rentalCount = await rent.getBorrowCount();
      const rentalIndex = rentalCount.sub(new BN("1"));
      await rent.claimCollateral(rentalIndex, {
        from: firstOwnerAddress
      });
    });

    it("should return multiple NFTs", async () => {
      const rentalCount = await rent.getBorrowCount();
      const rentalIndex1 = rentalCount.sub(new BN("2"));
      const rentalIndex2 = rentalCount.sub(new BN("1"));

      const iniTokenBalDai = await erc20.balanceOf(unprivilegedAddress);

      await rent.returnNftMultiple([rentalIndex1, rentalIndex2], {
        from: unprivilegedAddress
      });
      const finalTokenBalDai = await erc20.balanceOf(unprivilegedAddress);

      // summation of nftPrices (collateral) = 10+11 = 21
      expect(finalTokenBalDai.sub(iniTokenBalDai)).to.be.bignumber.eq("21");
    });
  });
});
