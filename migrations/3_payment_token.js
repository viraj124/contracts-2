const PaymentToken = artifacts.require("PaymentToken");

module.exports = (_deployer, _network) => {
    if (_network === "development") {
        _deployer.deploy(PaymentToken);
    }
};