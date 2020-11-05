const RentNftAddressProvider = artifacts.require("RentNftAddressProvider");

module.exports = async (_deployer, _network) => {
  if (_network === "development" || _network === "goerli") {
    const networkId = _network === "goerli" ? "5" : "0";
    await _deployer.deploy(RentNftAddressProvider, networkId);
  }
};
