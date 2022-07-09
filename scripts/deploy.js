// Import ethers from Hardhat package
const { ethers } = require("hardhat");

async function main() {

  // We get the contract to deploy
  const EventPool = await ethers.getContractFactory("EventPool");


  const eventpool = await EventPool.deploy();

  // here we deploy the contract
  await eventpool.deployed();
  // print the address of the deployed contract
  console.log("Eventpool deployed to:", eventpool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
