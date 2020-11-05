const RentNft = artifacts.require("RentNft");

module.exports = async (_deployer, _network) => {
  if (_network === "development" || _network === "goerli") {
    const networkId = _network === "goerli" ? "5" : "0";
    await _deployer.deploy(RentNft, networkId);
  }
};
