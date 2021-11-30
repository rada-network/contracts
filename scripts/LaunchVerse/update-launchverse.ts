// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// @ts-ignore
import {ethers, upgrades} from "hardhat";

async function main() {
    const LaunchVerseContract = await ethers.getContractFactory("LaunchVerse");
    console.log("Deploying upgrade token...");
    const ProxyContract = await upgrades.upgradeProxy("0x206B561B1dCe5F7245648d402766d2DA1F4275c9", LaunchVerseContract);
    // const token = await upgrades.upgradeProxy("0xF73DCe0c40314d12296228f51fD65f184274bBEd", RIRContract);
    console.log("Token deployed to:", ProxyContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
