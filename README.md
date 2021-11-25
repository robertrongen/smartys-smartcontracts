# smartys-smartcontracts
Note: This repo is for demonstrating the Smartys smart contracts and has not been tested yet for any other purpose yet.
## Installation
* run `npm install` to install web3, openzeppelin and truffle libraries
In order to use the truffle-config.js file:
* create .infura file containint infura project ID for using Infura Web3 api
* create .secret file containing mnemonics for creating a specific token owner account 
* create .etherscan file etherscan key 
## Use in Smartys
Deployed contracts on Rinkeby testnet used by [Smartys](https://smartys.2bsmart.eu/):
* [Smartys token](https://rinkeby.etherscan.io/token/0xe0d15a857b78e4472876476bef9da392ec5bce23?a=0xa2da9f1522f346cef858d23c2be740568313435e#code)
* [Order contract](https://rinkeby.etherscan.io/address/0xe513670d42f6b1CBa88D2c28Fd0a9ff4C3397055#code)
* [Transport contract](https://rinkeby.etherscan.io/address/0x19BEf719F472CbA8b4eAA829682A89Fd6d794089#code) 
## Design
### High level process design
* ![High level process design](https://github.com/robertrongen/smartys-smartcontracts/blob/main/images/smartys_high_level.png)
* ### Detailed process design
* ![Detailed design](https://github.com/robertrongen/smartys-smartcontracts/blob/main/images/smartys_v2_detailed.png)
* ### ERC777token transfer
* ![ERC777token transfer](https://github.com/robertrongen/smartys-smartcontracts/blob/main/images/erc777_token_transfer.png)
* ### Smartys Roadmap
* ![Roadmap](https://github.com/robertrongen/smartys-smartcontracts/blob/main/images/smartys_roadmap_2022.png)
