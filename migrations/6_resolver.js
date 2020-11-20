const Resolver = artifacts.require("Resolver");

module.exports = async (_deployer, _network) => {
  await _deployer.deploy(Resolver);
};
