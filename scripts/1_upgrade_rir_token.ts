// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// @ts-ignore
import {ethers, upgrades} from "hardhat";

async function main() {
    const RIRContract = await ethers.getContractFactory("RIRContract");
    console.log("Deploying upgrade token...");
    const token = await upgrades.upgradeProxy(process.env.RIR_ADDRESS, RIRContract);
    // const token = await upgrades.upgradeProxy("0xF73DCe0c40314d12296228f51fD65f184274bBEd", RIRContract);
    console.log("Token deployed to:", token.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
