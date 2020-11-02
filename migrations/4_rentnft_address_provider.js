const PaymentToken = artifacts.require("PaymentToken");
const RentNftAddressProvider = artifacts.require("RentNftAddressProvider");

module.exports = async (_deployer, _network) => {
  const networkId = _network === "goerli" ? "5" : "0";
  const pmtToken = await PaymentToken.deployed();
  const addrProvider = await _deployer.deploy(
    RentNftAddressProvider,
    networkId
  );
  await addrProvider.setDai(pmtToken.address);
};
