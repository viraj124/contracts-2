/**
 * execute with:
 *  #> npm run test ./test/rentnft-unit-integration.js
 * */
const {accounts, contract} = require("@openzeppelin/test-environment");
const {
  expectRevert,
  BN,
  ether,
  constants
} = require("@openzeppelin/test-helpers");
const {expect} = require("chai");

const RentNftResolver = contract.fromArtifact("RentNftResolver");
const RentNft = contract.fromArtifact("RentNft");
const GanFaceNft = contract.fromArtifact("GanFaceNft");
const PaymentToken = contract.fromArtifact("PaymentToken");

const NILADDR = constants.ZERO_ADDRESS;
const INITBALANCE = "1000";
const UNLIMITED_ALLOWANCE =
  "10000000000000000000000000000000000000000000000000000";

let dai;
let rent;
let face;

const BORROW_PRICE = "1";
const MAX_DURATION = "5";
const NFT_PRICE = "11";

describe("RentNft", () => {
  const creatorAddress = accounts[0];
  const firstOwnerAddress = accounts[1];
  const secondOwnerAddress = accounts[2];
  // const externalAddress = accounts[3];
  const unprivilegedAddress = accounts[4];
  /* create named accounts for contract roles */

  before(async () => {
    dai = await PaymentToken.new({from: creatorAddress});
    resolver = await RentNftResolver.new(
      2,
      dai.address,
      NILADDR,
      NILADDR,
      NILADDR,
      NILADDR
    );
    rent = await RentNft.new(resolver.address, {from: creatorAddress});
    face = await GanFaceNft.new({from: creatorAddress});

    // approvals for NFT and DAI handling by the rent contract
    await face.setApprovalForAll(rent.address, true, {from: firstOwnerAddress});
    await face.setApprovalForAll(rent.address, true, {
      from: secondOwnerAddress
    });
    await face.setApprovalForAll(rent.address, true, {from: creatorAddress});
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

    const tokenId = "1";
    await face.approve(rent.address, tokenId, {from: firstOwnerAddress});
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

  it("should rent one NFT", async () => {
    let daiBalanceRent = await dai.balanceOf(rent.address);
    expect(daiBalanceRent).to.be.bignumber.eq("0");
    let daiBalanceFOA = await dai.balanceOf(firstOwnerAddress);
    expect(daiBalanceFOA).to.be.bignumber.eq(INITBALANCE);
    let daiBalanceUA = await dai.balanceOf(unprivilegedAddress);
    expect(daiBalanceUA).to.be.bignumber.eq(INITBALANCE);

    // unprivilidged account now rents the NFT
    const rentDuration = "2"; // 2 days
    const receipt = await rent.rentOne(
      unprivilegedAddress,
      face.address,
      "1",
      rentDuration,
      {
        from: unprivilegedAddress
      }
    );

    const nft = await rent.nfts(face.address, "1");

    expect(nft.lender).to.eq(firstOwnerAddress);
    expect(nft.borrower).to.eq(unprivilegedAddress);
    expect(nft.maxDuration).to.be.bignumber.eq(MAX_DURATION);
    expect(nft.actualDuration).to.be.bignumber.eq(rentDuration);
    expect(nft.borrowPrice).to.be.bignumber.eq(BORROW_PRICE);
    expect(nft.nftPrice).to.be.bignumber.eq(NFT_PRICE);

    daiBalanceRent = await dai.balanceOf(rent.address);
    expect(daiBalanceRent).to.be.bignumber.eq(NFT_PRICE);
    daiBalanceFOA = await dai.balanceOf(firstOwnerAddress);
    // initial 1000 + 1 DAI * 2 days = 1002 DAI
    expect(daiBalanceFOA).to.be.bignumber.eq("1002");
    // - (1 DAI * 2 days) - 11 DAI (collateral) = 998 - 11 = 987
    daiBalanceUA = await dai.balanceOf(unprivilegedAddress);
    expect(daiBalanceUA).to.be.bignumber.eq("987");
  });

  it("should lend multiple NFT", async () => {
    const fakeTokenURI = "https://fake.ipfs.image.link";
    await face.awardGanFace(secondOwnerAddress, fakeTokenURI);
    await face.awardGanFace(secondOwnerAddress, `${fakeTokenURI}.new.face`);
    await rent.lendMultiple(
      [face.address, face.address],
      ["2", "3"], // tokenIds
      ["5", "10"], // maxDuration
      ["1", "2"], // daily borrow price
      ["10", "11"], // collateral
      {from: secondOwnerAddress}
    );
    const nft2 = await rent.nfts(face.address, "2");
    const nft3 = await rent.nfts(face.address, "3");

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
});
