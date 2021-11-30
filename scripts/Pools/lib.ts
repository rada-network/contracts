import { ethers, upgrades, hardhatArguments } from "hardhat";
import { utils } from "ethers";

export async function deployContract(poolpath: string) {
    //contractType: string, deployData: any, commonData: any
    const { contractType, deploy } = require(`${poolpath}/info`);
    const network = hardhatArguments.network;
    const commonData = require("./common")[network || 'testnet']

    const startDate = Math.floor(Date.parse(deploy.startDate) / 1000);
    const endDate = Math.floor(Date.parse(deploy.endDate) / 1000);

    const contractFactory = await ethers.getContractFactory(contractType);

    let launchPadContract = await upgrades.deployProxy(contractFactory, [
        // paramLaunchpad._tokenAddress,
        commonData.busdAddress,
        commonData.rirAddress,
        utils.parseEther(deploy.price),
        utils.parseEther(deploy.raise),
        startDate,
        endDate,
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

export async function upgradeContract(poolpath: string) {
    const { contractType, upgrade } = require(`${poolpath}/info`);
    const network = hardhatArguments.network;

    const proxyAddress = upgrade.address[network || 'testnet'];
    const contractFactory = await ethers.getContractFactory(contractType);
    const token = await upgrades.upgradeProxy(proxyAddress, contractFactory);
    return token.address;
}