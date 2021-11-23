import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-etherscan";
import {task} from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import { config } from "dotenv";

config({ path: process.argv.includes('mainnet') ? '.env.mainnet' : '.env'});

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
            accounts: {mnemonic: mnemonic}
        },
        mainnet: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            gasPrice: 20000000000,
            accounts: {mnemonic: mnemonic}
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
    }
};

