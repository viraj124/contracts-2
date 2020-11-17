const PaymentToken = artifacts.require("PaymentToken");
const Faucet = artifacts.require("Faucet");

module.exports = async (_deployer, _network) => {
  if (
    _network === "development" ||
    _network === "goerli" ||
    _network === "avalanche"
  ) {
    await _deployer.deploy(PaymentToken);
    const faucet = await Faucet.deployed();
    const token = await PaymentToken.deployed();
    await token.transfer(faucet.address, "1000000000000000000000000000");
  }
};
