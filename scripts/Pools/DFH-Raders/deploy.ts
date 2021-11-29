import { ethers, upgrades, hardhatArguments } from "hardhat";
import { utils } from "ethers";
import { deployContract } from "../lib"

async function main() {
    let launchPadAddress = await deployContract ('DFH-Raders')
    console.log('LaunchPad Contract: ', launchPadAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });