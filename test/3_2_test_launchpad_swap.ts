// @ts-ignore
import {ethers} from "hardhat"
import {constants, Contract, utils} from "ethers"
import {expect, use} from 'chai';
import {solidity} from 'ethereum-waffle';

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
        // console.log('BUSD: ', busdAddress);

        // Token project
        const tokenContractFactory = await ethers.getContractFactory("ERC20Token");
        tokenContract = await tokenContractFactory.deploy("TOKEN", "TOKEN");
        tokenContract = await tokenContract.deployed();
        const tokenAddress = tokenContract.address;
        // console.log('Token Project: ', tokenAddress);

        // Token RIR
        const rirContractFactory = await ethers.getContractFactory("ERC20Token");
        rirContract = await rirContractFactory.deploy("RIR", "RIR");
        rirContract = await rirContract.deployed();
        const rirAddress = rirContract.address;
        // console.log('RIR Contract: ', rirAddress);

        const launchPadFactory = await ethers.getContractFactory("LaunchPad");
        launchPadContract = await launchPadFactory.deploy(tokenAddress, busdAddress, rirAddress, utils.parseEther("0.01"), true);
        launchPadContract = await launchPadContract.deployed();
        const launchPadAddress = launchPadContract.address;
        // console.log('LaunchPad Contract: ', launchPadAddress);

        // Send token to launchPad
        await tokenContract.mint(launchPadAddress, utils.parseEther("1000000"));
        const launchPadTokenAmount = await tokenContract.balanceOf(launchPadAddress);
        expect(utils.formatEther(launchPadTokenAmount)).to.equal("1000000.0");
    });

    describe("Test Buyer - Permission", () => {

        it('Buyer Has Permission Buy Token', async function () {
            await rirContract.mint(owner.address, utils.parseEther("1000"))
            const amountOwner = await rirContract.balanceOf(owner.address);
            expect(utils.formatEther(amountOwner)).to.equal("1000.0");
            const canBuy = await launchPadContract.isBuyerHasPermissionBuy(owner.address)
            expect(canBuy).to.equal(true);
        });

        it('Buyer Has Not Permission Buy Token', async function () {
            const amountOwner = await rirContract.balanceOf(owner.address);
            expect(utils.formatEther(amountOwner)).to.equal("0.0");
            const canBuy = await launchPadContract.isBuyerHasPermissionBuy(owner.address)
            expect(canBuy).to.equal(false);
        });

    });

    describe("Import Orders", () => {

        it('Add Import Orders', async function () {
            const ordersImport = await launchPadContract.addOrdersImport(
                [owner.address, addr1.address, addr2.address],
                [utils.parseEther("1000"), utils.parseEther("2000"), utils.parseEther("3000")]
            );
            const orderOwner = await launchPadContract.getOrderImport(owner.address);
            expect(utils.formatEther(orderOwner.amountRIR)).to.equal("0.0");
            expect(utils.formatEther(orderOwner.amountBUSD)).to.equal("1000.0");
            expect(utils.formatEther(orderOwner.amountToken)).to.equal("100000.0");
            expect(orderOwner.status).to.equal(0);

            const orderAddr1 = await launchPadContract.getOrderImport(addr1.address);
            expect(utils.formatEther(orderAddr1.amountRIR)).to.equal("0.0");
            expect(utils.formatEther(orderAddr1.amountBUSD)).to.equal("2000.0");
            expect(utils.formatEther(orderAddr1.amountToken)).to.equal("200000.0");
            expect(orderAddr1.status).to.equal(0);
        });

    });

    describe("Create order", () => {

        it('Buyer - Has RIR', async function () {
            await rirContract.mint(addr1.address, utils.parseEther("1"));
            const addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
            expect(utils.formatEther(addr1_RIRAmount)).to.equal("1.0");

            await bUSDContract.mint(addr1.address, utils.parseEther("1000"));
            const addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
            expect(utils.formatEther(addr1_BusdAmount)).to.equal("1000.0");

            await rirContract.connect(addr1).approve(launchPadContract.address, constants.MaxUint256);
            launchPadContract.connect(addr1).createOrder(utils.parseEther("100"));
        });

        // it('Buyer - Dont Has RIR', async function () {
        //     const addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
        //     expect(utils.formatEther(addr1_RIRAmount)).to.equal("0.0");
        //     await bUSDContract.mint(addr1.address, utils.parseEther("2000"));
        //     const addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
        //     expect(utils.formatEther(addr1_BusdAmount)).to.equal("2000.0");
        // });

    })


});
