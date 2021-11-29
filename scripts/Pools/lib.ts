import { ethers, upgrades, hardhatArguments } from "hardhat";
import { utils } from "ethers";

export async function deployContract(pool: string) {
    //contractType: string, deployData: any, commonData: any
    const { contractType, deploy } = require(`./${pool}/info`);
    const network = hardhatArguments.network;
    const commonData = require("./common")[network || 'testnet']

    deploy.startDate = Math.floor((Date.now() + 0 * 60 * 60 * 1000) / 1000);
    deploy.endDate = Math.floor((Date.now() + 7 * 24 * 60 * 60 * 1000) / 1000);

    const contractFactory = await ethers.getContractFactory(contractType);

    // const startDate = Math.floor((Date.now() + 0 * 60 * 60 * 1000) / 1000);
    // const endDate = Math.floor((Date.now() + 7 * 24 * 60 * 60 * 1000) / 1000);

    let launchPadContract = await upgrades.deployProxy(contractFactory, [
        // paramLaunchpad._tokenAddress,
        commonData.busdAddress,
        commonData.rirAddress,
        utils.parseEther(deploy.price),
        utils.parseEther(deploy.raise),
        deploy.startDate,
        deploy.endDate,
        utils.parseEther(deploy.minAmountBusd),
        utils.parseEther(deploy.maxAmountBusd),
        utils.parseEther(deploy.tokenFee)
    ],
        { unsafeAllowCustomTypes: true }
    );
    launchPadContract = await launchPadContract.deployed();
    const launchPadAddress = launchPadContract.address;

    return launchPadAddress;
}

export async function upgradeContract(pool: string) {
    const { contractType, upgrade } = require(`./${pool}/info`);
    const network = hardhatArguments.network;

    const proxyAddress = upgrade.address[network || 'testnet'];
    const contractFactory = await ethers.getContractFactory(contractType);
    const token = await upgrades.upgradeProxy(proxyAddress, contractFactory);
    return token.address;
}