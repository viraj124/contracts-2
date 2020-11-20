const Resolver = artifacts.require("Resolver");
const RentNft = artifacts.require("RentNft");

module.exports = async (_deployer, _network) => {
  const resolver = await Resolver.deployed();
  await _deployer.deploy(RentNft, resolver.address);
};
