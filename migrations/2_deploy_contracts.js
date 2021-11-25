const SmartysToken = artifacts.require("../contracts/SmartysToken777.sol");
const TransportContract = artifacts.require("../contracs/TransportContract.sol");
const OrderContract = artifacts.require("../contracs/OrderContract.sol");

require('@openzeppelin/test-helpers/configure')({ provider: web3.currentProvider, environment: 'truffle' });

const { singletons } = require('@openzeppelin/test-helpers');


// ** DEPLOY ALL CONTRACTS TO GANACHE OR ONLY DEPLOY TRANSPORT AND ORDER CONTRACT TO RINKEBY **
module.exports = async function(deployer, network, accounts) {
  let tokenAddress;
  try {
    if(network === 'development') {
      await singletons.ERC1820Registry(accounts[0]);
    }

    if (network === 'rinkeby-update') {
      console.log('doing rinkeby update deploy')
    
      tokenAddress = "0xe0D15a857B78E4472876476Bef9DA392EC5Bce23";
    
    } else {
      console.log('doing other deploy')

      await deployer.deploy(SmartysToken);
    
      let stInstance = await SmartysToken.deployed();
      tokenAddress = stInstance.address;
      console.log("deployed smartystoken contract to %s", stInstance.address)
    }

    await deployer.deploy(TransportContract, tokenAddress);
    let tcInstance = await TransportContract.deployed();
    console.log("deployed transport contract to %s", tcInstance.address);

    await deployer.deploy(OrderContract, tokenAddress);
    let ocInstance = await OrderContract.deployed();
    console.log("deployed order contract to %s", ocInstance.address);
  } catch (error) {
    console.log(error);
  }
};
