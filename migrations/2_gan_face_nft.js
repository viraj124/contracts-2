const GanFaceNft = artifacts.require("GanFaceNft");

module.exports = function (_deployer, _network) {
  if (
    _network === "development" ||
    _network === "goerli" ||
    _network === "avalanche"
  ) {
    // Use deployer to state migration tasks.
    _deployer.deploy(GanFaceNft);
  }
};
