const Cryeator = artifacts.require("CryeatorToken");

module.exports = function (deployer) {
  deployer.deploy(Cryeator);
};
