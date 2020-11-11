const RentNftAddressProvider = artifacts.require("RentNftAddressProvider");
const PaymentToken = artifacts.require("PaymentToken");

module.exports = async (_deployer, _network) => {
  if (_network === "development" || _network === "goerli") {
    const networkId = _network === "goerli" ? "5" : "0";
    await _deployer.deploy(RentNftAddressProvider, networkId);
    const resolver = await RentNftAddressProvider.deployed();

    const token = await PaymentToken.deployed();
    await resolver.setDai(token.address);
  }
};
