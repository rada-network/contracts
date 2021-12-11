import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-contract-sizer";

import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import { config } from "dotenv";
import { utils } from "ethers";
import { join } from "path/posix";
import * as fs from 'fs';

//require('hardhat-contract-sizer');


let network = 'testnet';
if (process.argv.includes('mainnet')) network = 'mainnet';
if (process.argv.includes('matictest')) network = 'matictest';
if (process.argv.includes('maticmain')) network = 'maticmain';

config({ path: `.env.${network}` });

const mnemonic = process.env.MNEMONIC;
const bscscanApiKey = process.env.BSCSCANAPIKEY;
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

const getDeployedData = () => {
    let deployedData;
    try{
        deployedData = require("./.deploy.json") || {};
    } catch (e) {
        deployedData = {}
    }
    if (deployedData[network] == undefined) deployedData[network] = {}
    return deployedData;
}
const updateDeployedData = (deployedData: object) => {
    fs.writeFileSync(`${__dirname}/.deploy.json`, JSON.stringify(deployedData, null, " "));
}

task("remove", "Remove a deployed contract")
    .addParam("pool", "Pool Name")
    .setAction(async (taskArgs, hre) => {
        // check if task exist, then quit
        const deployedData = getDeployedData()
        if (deployedData[network][taskArgs.pool] != null) {
            delete deployedData[network][taskArgs.pool];
        }
        updateDeployedData(deployedData);
    });


/* Read data from contract */
task("view", "Read data from contract")
    .addParam("pool", "Pool Name")
    .addParam("func", "Function to call")
    .setAction(async (taskArgs, hre) => {
        // check if task exist, then quit
        const deployedData = getDeployedData()
        if (deployedData[network][taskArgs.pool] == null) {
            console.log("Cannot Find contract for this pool");
            return;
        }

        const contractAddress = deployedData[network][taskArgs.pool];        
        const {ethers, upgrades} = hre;
        const deployData = require(`./pools/${taskArgs.pool}.json`)

        const contract = await ethers.getContractAt(deployData.contractType, contractAddress);

        if (taskArgs.func) {
            console.log(`Get data from contract`)
            console.log (utils.formatEther(await contract[taskArgs.func]()))
        }

        updateDeployedData(deployedData);
    });

/* Read data from contract */
task("exec", "Call a task in contract")
    .addParam("pool", "Pool Name")
    .addParam("func", "Function to call")
    .addParam("p1", "Param 1")
    .setAction(async (taskArgs, hre) => {
        // check if task exist, then quit
        const deployedData = getDeployedData()
        if (deployedData[network][taskArgs.pool] == null) {
            console.log("Cannot Find contract for this pool");
            return;
        }

        const contractAddress = deployedData[network][taskArgs.pool];        
        const {ethers, upgrades} = hre;
        const deployData = require(`./pools/${taskArgs.pool}.json`)

        const contract = await ethers.getContractAt(deployData.contractType, contractAddress);

        if (taskArgs.func) {
            console.log(`Get data from contract`)
            console.log (await contract[taskArgs.func](taskArgs.p1))
        }

        updateDeployedData(deployedData);
    });



task("deploy", "Deploy a POOL")
    .addParam("pool", "Pool Name")
    .setAction(async (taskArgs, hre) => {
        // check if task exist, then quit
        let deployedData;
        try{
            deployedData = require("./.deploy.json") || {};
        } catch (e) {
            deployedData = {}
        }
        if (deployedData[network] == undefined) deployedData[network] = {}
        if (deployedData[network][taskArgs.pool] != null) {
            console.log("Please run remove this Pool before deploy new one");
            return;
        }

        // clean before
        //hre.run("clean");

        const {ethers, upgrades} = hre;
        const deployData = require(`./pools/${taskArgs.pool}.json`)

        const startDate = Math.floor(Date.parse(deployData.startDate) / 1000);
        const endDate = Math.floor(Date.parse(deployData.endDate) / 1000);

        const contractFactory = await ethers.getContractFactory(deployData.contractType);

        let launchPadContract = await upgrades.deployProxy(contractFactory, [
            process.env.BUSD_ADDRESS,
            process.env.RIR_ADDRESS,
            utils.parseEther(deployData.price),
            utils.parseEther(deployData.raise),
            startDate,
            endDate,
            utils.parseEther(deployData.minAmountBusd),
            utils.parseEther(deployData.maxAmountBusd),
            utils.parseEther(deployData.tokenFee)
        ],
            { unsafeAllowCustomTypes: true }
        );
        launchPadContract = await launchPadContract.deployed();
        const launchPadAddress = launchPadContract.address;

        console.log('Address: ', launchPadAddress);
        // write to cache
        deployedData[network][taskArgs.pool] = launchPadAddress

        updateDeployedData(deployedData);
    })

task("upgrade", "Upgrade a deployed contract")
    .addParam("pool", "Pool Name")
    .setAction(async (taskArgs, hre) => {
        // check if task exist, then quit
        const deployedData = getDeployedData()
        if (deployedData[network][taskArgs.pool] == null) {
            console.log("Cannot detect contract for this pool");
            return;
        }

        const contractAddress = deployedData[network][taskArgs.pool];

        const {ethers, upgrades} = hre;

        const deployData = require(`./pools/${taskArgs.pool}.json`)

        const contractFactory = await ethers.getContractFactory(deployData.contractType);
        const token = await upgrades.upgradeProxy(contractAddress, contractFactory);
        console.log("Done");
    });


// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    defaultNetwork: "hardhat",
    networks: {
        localhost: {
            url: "http://127.0.0.1:7545",
        },
        hardhat: {},
        testnet: {
            url: "https://data-seed-prebsc-1-s1.binance.org:8545",
            chainId: 97,
            gasPrice: 20000000000,
            accounts: [process.env.PRIVATE_KEY]
            // accounts: { mnemonic: mnemonic }
        },
        mainnet: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            gasPrice: 20000000000,
            accounts: [process.env.PRIVATE_KEY]
            // accounts: { mnemonic: mnemonic }
        },
        maticmain: {
            url: "https://rpc-mainnet.matic.network",
            chainId: 137,
            accounts: [process.env.PRIVATE_KEY]
        },
        matictest: {
            url: "https://rpc-mumbai.maticvigil.com",
            chainId: 80001,
            accounts: [process.env.PRIVATE_KEY]
        }
    },
    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://bscscan.com/
        apiKey: bscscanApiKey
    },
    solidity: {
        version: "0.8.5",
        settings: {
            optimizer: {
                enabled: true
            }
        }
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts"
    },
    mocha: {
        timeout: 2000000
    },
    contractSizer: {
        alphaSort: true,
        disambiguatePaths: false,
        runOnCompile: true,
        strict: true,
    }
};

