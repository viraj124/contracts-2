const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const RentNftResolver = artifacts.require("RentNftResolver");
const RentNft = artifacts.require("RentNft");

module.exports = async (_deployer, _network) => {
  if (_network === "development" || _network === "goerli") {
    const resolver = await RentNftResolver.deployed();
    const instance = await deployProxy(RentNft, resolver.address, { _deployer, unsafeAllowCustomTypes:true });
    console.log('RentNft Deployed:', instance.address);
  }
};
