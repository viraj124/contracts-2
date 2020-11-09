const {contract, accounts} = require("@openzeppelin/test-environment");

const {constants} = require("@openzeppelin/test-helpers");
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
      const ganFace = await GanFaceNft.deployed();
      const fakeTokenURI = "https://fake.ipfs.image.link";

      let receipt = await ganFace.awardGanFace(creatorAddress, fakeTokenURI);

      let faceEvent = receipt.logs[1];

      assert.strictEqual(
        faceEvent.args[0],
        creatorAddress,
        "receiver address not correct"
      );
      assert.strictEqual(
        faceEvent.args[1].toString(),
        "1",
        "total # of nfts not correct"
      );
      // if this was however indexed, this would be hex string
      assert.strictEqual(
        faceEvent.args[2],
        fakeTokenURI,
        "token URI is not correct"
      );

      receipt = await ganFace.awardGanFace(firstOwnerAddress, fakeTokenURI);
      faceEvent = receipt.logs[1];

      assert.strictEqual(
        faceEvent.args[0],
        firstOwnerAddress,
        "receiver address not correct"
      );
      assert.strictEqual(
        faceEvent.args[1].toString(),
        "2",
        "total # of nfts not correct"
      );
      // if this was however indexed, this would be hex string
      assert.strictEqual(
        faceEvent.args[2],
        fakeTokenURI,
        "token URI is not correct"
      );
    });

    it("transfers the nft to the owner", async () => {
      const ganFace = await GanFaceNft.deployed();
      const fakeTokenURI = "https://fake.ipfs.image.link";

      await ganFace.awardGanFace(creatorAddress, fakeTokenURI);
      let owner = await ganFace.ownerOf("1");
      assert.strictEqual(owner, creatorAddress, "owner is incorrect");

      await ganFace.awardGanFace(firstOwnerAddress, fakeTokenURI);
      owner = await ganFace.ownerOf("2");
      assert.strictEqual(owner, firstOwnerAddress, "owner is incorrect");
    });
  });
});
