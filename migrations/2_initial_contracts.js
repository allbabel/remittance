const Owned = artifacts.require("Owned");
const Running = artifacts.require("Running");
const Remittance = artifacts.require("Remittance");

module.exports = function(deployer) {
  deployer.deploy(Owned);
  deployer.deploy(Running);
  deployer.deploy(Remittance);
};
