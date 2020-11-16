const RentNft = artifacts.require("RentNft");

module.exports = async (_deployer, _network) => {
  await _deployer.deploy(RentNft);
};
