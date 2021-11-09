// @ts-ignore
import {ethers} from "hardhat"
import {Contract, utils} from "ethers"
import {expect, use} from 'chai';
import {deployContract, MockProvider, solidity} from 'ethereum-waffle';

use(solidity);

describe("LaunchPad", async function () {

    let launchPadContract: Contract;
    let tokenContract: Contract;
    let bUSDContract: Contract;
    let rirContract: Contract;
    let owner: any;
    let addr1: any;
    let addr2: any;

    beforeEach('Setup', async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        // Token Busd
        const bUSDFactory = await ethers.getContractFactory("ERC20Token");
        bUSDContract = await bUSDFactory.deploy("BUSD", "BUSD");
        bUSDContract = await bUSDContract.deployed();
        const busdAddress = bUSDContract.address;
        console.log('BUSD: ', busdAddress);

        // Token project
        const tokenContractFactory = await ethers.getContractFactory("ERC20Token");
        tokenContract = await tokenContractFactory.deploy("TOKEN", "TOKEN");
        tokenContract = await tokenContract.deployed();
        const tokenAddress = tokenContract.address;
        console.log('Token Project: ', tokenAddress);

        // Token RIR
        const rirContractFactory = await ethers.getContractFactory("ERC20Token");
        rirContract = await rirContractFactory.deploy("RIR", "RIR");
        rirContract = await rirContract.deployed();
        const rirAddress = rirContract.address;
        console.log('RIR Contract: ', rirAddress);

        const launchPadFactory = await ethers.getContractFactory("LaunchPad");
        launchPadContract = await launchPadFactory.deploy(tokenAddress, busdAddress, rirAddress, true);
        launchPadContract = await launchPadContract.deployed();
        const launchPadAddress = launchPadContract.address;
        console.log('LaunchPad Contract: ', launchPadAddress);
    });

    it('Buyer Has Permission Buy Token', async function () {
        await rirContract.mint(owner.address, utils.parseEther("1000"))
        const amountOwner = await rirContract.balanceOf(owner.address);
        expect(utils.formatEther(amountOwner)).to.equal("1000.0");
        const canBuy = await launchPadContract.isBuyerHasPermissionBuy(owner.address)
        expect(canBuy).to.equal(true);
    })

    it('Buyer Has Not Permission Buy Token', async function () {
        const amountOwner = await rirContract.balanceOf(owner.address);
        expect(utils.formatEther(amountOwner)).to.equal("0.0");
        await expect(launchPadContract.isBuyerHasPermissionBuy(owner.address))
            .to.be.revertedWith('Buyer dont have permission buy token');
    })

});