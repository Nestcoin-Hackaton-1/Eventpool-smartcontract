require("@nomiclabs/hardhat-waffle");
require("dotenv").config();
require("@nomiclabs/hardhat-etherscan")


const {ETHERSCAN_API_KEY, PRIVATE_API_KEY_URL, RINKEBY_PRIVATE_KEY} = process.env;

module.exports = {
  solidity: "0.8.4",
  networks: {
    rinkeby: {
      url: PRIVATE_API_KEY_URL,
      accounts: [RINKEBY_PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY
  }
};
