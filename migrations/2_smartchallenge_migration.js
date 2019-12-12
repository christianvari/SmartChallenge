const SmartChallenge = artifacts.require("SmartChallenge");

module.exports = function(deployer) {
    deployer.deploy(SmartChallenge);
};
