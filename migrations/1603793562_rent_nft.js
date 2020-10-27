const RentNft = artifacts.require("RentNft");

module.exports = function(_deployer) {
  // for development, let's pass network id: 5 - goerli
  _deployer.deploy(RentNft, "5");
};
