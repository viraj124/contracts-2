const RentNftResolver = artifacts.require("RentNftResolver");
const RentNft = artifacts.require("RentNft");

module.exports = async (_deployer, _network) => {
  if (_network === "development" || _network === "goerli") {
    const resolver = await RentNftResolver.deployed();
    await _deployer.deploy(RentNft, resolver.address);
  }
};
