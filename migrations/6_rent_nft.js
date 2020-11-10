const RentNftAddressProvier = artifacts.require("RentNftAddressProvider");
const RentNft = artifacts.require("RentNft");

module.exports = async (_deployer, _network) => {
  const resolver = await RentNftAddressProvier.deployed();
  await _deployer.deploy(RentNft, resolver.address);
};
