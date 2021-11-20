// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// @ts-ignore
import {ethers, upgrades} from "hardhat";
import {utils} from "ethers";

async function main() {
    // Token Busd
    const bUSDFactory = await ethers.getContractFactory("ERC20Token");
    let bUSDContract = await bUSDFactory.deploy("BUSD", "BUSD");
    bUSDContract = await bUSDContract.deployed();
    const busdAddress = bUSDContract.address;
    console.log('BUSD: ', busdAddress);

    // Token project
    const tokenContractFactory = await ethers.getContractFactory("ERC20Token");
    let tokenContract = await tokenContractFactory.deploy("TOKEN", "TOKEN");
    tokenContract = await tokenContract.deployed();
    const tokenAddress = tokenContract.address;
    console.log('Token Project: ', tokenAddress);

    // Token RIR
    const rirContractFactory = await ethers.getContractFactory("ERC20Token");
    let rirContract = await rirContractFactory.deploy("RIR", "RIR");
    rirContract = await rirContract.deployed();
    const rirAddress = rirContract.address;
    console.log('RIR Contract: ', rirAddress);

    const startDate = Math.floor((Date.now() + 60 * 60 * 1000) / 1000);
    const endDate = Math.floor((Date.now() + 7 * 24 * 60 * 60 * 1000) / 1000);

    const launchPadFactory = await ethers.getContractFactory("LaunchPad");
    const paramLaunchpad = {
        _tokenAddress: tokenAddress,
        _bUSDAddress: busdAddress,
        _rirAddress: rirAddress,
        _tokenPrice: utils.parseEther("1"),
        _bUSDForSale: utils.parseEther("1000"),
        _startDate: startDate,
        _endDate: endDate,
        _individualMinimumAmountBusd: utils.parseEther("100"),
        _individualMaximumAmountBusd: utils.parseEther("500"),
        _feeTax: 0,
    };

    let launchPadContract = await upgrades.deployProxy(launchPadFactory, [
        paramLaunchpad._tokenAddress,
        paramLaunchpad._bUSDAddress,
        paramLaunchpad._rirAddress,
        paramLaunchpad._tokenPrice,
        paramLaunchpad._bUSDForSale,
        paramLaunchpad._startDate,
        paramLaunchpad._endDate,
        paramLaunchpad._individualMinimumAmountBusd,
        paramLaunchpad._individualMaximumAmountBusd,
        paramLaunchpad._feeTax
    ],
        { unsafeAllowCustomTypes: true }
    );
    launchPadContract = await launchPadContract.deployed();
    const launchPadAddress = launchPadContract.address;
    console.log('LaunchPad Contract: ', launchPadAddress);

    // Send token to launchPad
    await tokenContract.mint(launchPadAddress, utils.parseEther("1000000"));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
