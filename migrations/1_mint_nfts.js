const MyTestNFT = artifacts.require("MyTestNFT");

module.exports = function (deployer) {
  deployer.deploy(MyTestNFT);
};
