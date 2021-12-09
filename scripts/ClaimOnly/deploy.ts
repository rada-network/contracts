// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// @ts-ignore
import { ethers, upgrades } from "hardhat";
import { utils } from "ethers";

async function main() {

    const contractFactory = await ethers.getContractFactory("WhitelistPools");

    let contract = await upgrades.deployProxy(contractFactory, [
            process.env.BUSD_ADDRESS
        ],
        { unsafeAllowCustomTypes: true }
    );
    contract = await contract.deployed();
    const contractAddress = contract.address;

    console.log('LaunchPad Contract: ', contractAddress);
       
    //await token.mint(launchPadAddress, utils.parseEther("1000000"));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
