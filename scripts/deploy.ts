import { ethers } from "hardhat";
require("dotenv").config();

async function main() {

  if(!process.env.VRF_SUBSCRIPTION_ID || !process.env.VRF_COORDINATOR || !process.env.VRF_LINK_TOKEN) return;

  const DevTheGathering = await ethers.getContractFactory("DevTheGathering");
  const contract = await DevTheGathering.deploy(process.env.VRF_COORDINATOR, process.env.VRF_LINK_TOKEN, process.env.VRF_SUBSCRIPTION_ID);

  await contract.deployed();

  console.log(`DevTheGathering deployed to ${contract.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
