var Exchange = artifacts.require("./Exchange.sol");
var Staking = artifacts.require("./Staking.sol");
var LPContract = artifacts.require("./LPContract.sol");
var DESTMasterChef = artifacts.require("./DESTMasterChef.sol");
var IDSMasterChef = artifacts.require("./IDSMasterChef.sol");

module.exports = function(deployer) {
    deployer.then(async () => {
        await deployer.deploy(DESTMasterChef);
        await deployer.deploy(IDSMasterChef);
        await deployer.deploy(LPContract);
        await deployer.deploy(Staking);
        await deployer.deploy(Exchange);

        let dest = await DESTMasterChef.deployed();
        let ids = await IDSMasterChef.deployed();
        let lp = await LPContract.deployed();
        let staking = await Staking.deployed();
        let exchange = await Exchange.deployed();

    });    
}
