const Faucet = artifacts.require("Faucet");

module.exports = (_deployer, _network) => {
  if (
    _network === "development" ||
    _network === "goerli" ||
    _network === "avalanche"
  ) {
    _deployer.deploy(Faucet);
  }
};
