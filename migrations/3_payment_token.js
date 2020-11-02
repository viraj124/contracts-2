const PaymentToken = artifacts.require("PaymentToken");

module.exports = (_deployer, _network) => {
  if (_network === "development" || _network === "goerli") {
    _deployer.deploy(PaymentToken);
  }
};
