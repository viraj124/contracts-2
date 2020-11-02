const PaymentToken = artifacts.require("PaymentToken");
const RentNftResolver = artifacts.require("RentNftResolver");
const NILADDR = "0x0000000000000000000000000000000000000000";

module.exports = async (_deployer, _network) => {
  if (_network === "goerli") {
    const pmtToken = await PaymentToken.deployed();
    await _deployer.deploy(
      RentNftResolver,
      "0",
      pmtToken.address,
      NILADDR,
      NILADDR,
      NILADDR,
      NILADDR
    );
  } else if (_network === "development") {
    await _deployer.deploy(
      RentNftResolver,
      "5",
      NILADDR,
      NILADDR,
      NILADDR,
      NILADDR,
      NILADDR
    );
  }
};
