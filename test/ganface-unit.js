
/**
 * 
 * autogenerated by solidity-visual-auditor
 * 
 * execute with: 
 *  #> truffle test <path/to/this/test.js>
 * 
 * */
const GanFaceNft = artifacts.require("/home/shredder/git/superfluid/contracts/contracts/GanFaceNft.sol");

contract('GanFaceNft', (accounts) => {
    var creatorAddress = accounts[0];
    var firstOwnerAddress = accounts[1];
    // var secondOwnerAddress = accounts[2];
    // var externalAddress = accounts[3];
    // var unprivilegedAddress = accounts[4]
    /* create named accounts for contract roles */

    before(async () => {
        /* before tests */
    })
    
    beforeEach(async () => {
        /* before each context */
    })

    it('mints nft', async () => {
        const ganFace = await GanFaceNft.deployed();
        const fakeTokenURI = "https://fake.ipfs.image.link";

        let receipt = await ganFace.awardGanFace(creatorAddress, fakeTokenURI);

        let faceEvent = receipt.logs[1];

        assert.strictEqual(faceEvent.args[0], creatorAddress, "receiver address not correct");
        assert.strictEqual(faceEvent.args[1].toString(), "1", "total # of nfts not correct");
        // if this was however indexed, this would be hex string
        assert.strictEqual(faceEvent.args[2], fakeTokenURI, "token URI is not correct");

        receipt = await ganFace.awardGanFace(firstOwnerAddress, fakeTokenURI);
        faceEvent = receipt.logs[1];

        assert.strictEqual(faceEvent.args[0], firstOwnerAddress, "receiver address not correct");
        assert.strictEqual(faceEvent.args[1].toString(), "2", "total # of nfts not correct");
        // if this was however indexed, this would be hex string
        assert.strictEqual(faceEvent.args[2], fakeTokenURI, "token URI is not correct");
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
