/**
 * execute with:
 *  #> npm run test:ganface
 * */
const {contract, accounts} = require("@openzeppelin/test-environment");

const {constants, BN, expectEvent} = require("@openzeppelin/test-helpers");
const {expect} = require("chai");

const UNLIMITED_ALLOWANCE = constants.MAX_UINT256;
const INITBALANCE = "1000";

const GanFaceNft = contract.fromArtifact("GanFaceNft");
const PaymentToken = contract.fromArtifact("PaymentToken");

describe("GanFaceNft", () => {
  const creatorAddress = accounts[0];
  const firstOwnerAddress = accounts[1];

  before(async () => {
    dai = await PaymentToken.new({from: creatorAddress});
    face = await GanFaceNft.new({from: creatorAddress});

    await dai.approve(face.address, UNLIMITED_ALLOWANCE, {
      from: firstOwnerAddress
    });

    dai.transfer(firstOwnerAddress, INITBALANCE, {from: creatorAddress});
  });

  context("MINTING", () => {
    it("mints nft", async () => {
      const fakeTokenURI = "https://fake.ipfs.image.link";

      let receipt = await face.awardGanFace(creatorAddress, fakeTokenURI);

      expectEvent(receipt, "NewFace", {
        owner: creatorAddress,
        tokenId: new BN("1"),
        tokenURI: fakeTokenURI
      });

      receipt = await face.awardGanFace(firstOwnerAddress, fakeTokenURI);
      expectEvent(receipt, "NewFace", {
        owner: firstOwnerAddress,
        tokenId: new BN("2"),
        tokenURI: fakeTokenURI
      });
    });

    it("transfers the nft to the owner", async () => {
      const fakeTokenURI = "https://fake.ipfs.image.link";

      await face.awardGanFace(creatorAddress, fakeTokenURI);
      let owner = await face.ownerOf("1");
      expect(owner).to.eq(creatorAddress);

      await face.awardGanFace(firstOwnerAddress, fakeTokenURI);
      owner = await face.ownerOf("2");
      expect(owner).to.eq(firstOwnerAddress);
    });
  });
});
