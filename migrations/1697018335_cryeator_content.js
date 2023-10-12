const CryeatorPackage = artifacts.require("CryeatorPackage");

module.exports = function (deployer) {
  deployer.deploy(CryeatorPackage);
};
