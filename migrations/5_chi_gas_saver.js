const ChiGasSaver = artifacts.require("ChiGasSaver");

module.exports = async (_deployer, _network) => {
  await _deployer.deploy(ChiGasSaver);
};
