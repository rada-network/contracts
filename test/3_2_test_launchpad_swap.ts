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
    let addr3: any;

    beforeEach('Setup', async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();

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
        const paramLaunchpad = {
            _tokenAddress: tokenAddress,
            _bUSDAddress: busdAddress,
            _rirAddress: rirAddress,
            _tokenPrice: utils.parseEther("1"),
            _tokensForSale: utils.parseEther("1000000"),
            _individualMinimumAmount: utils.parseEther("100"),
            _individualMaximumAmount: utils.parseEther("1000"),
            _hasWhitelisting: true,
        };
        launchPadContract = await launchPadFactory.deploy(
            paramLaunchpad._tokenAddress,
            paramLaunchpad._bUSDAddress,
            paramLaunchpad._rirAddress,
            paramLaunchpad._tokenPrice,
            paramLaunchpad._tokensForSale,
            paramLaunchpad._individualMinimumAmount,
            paramLaunchpad._individualMaximumAmount,
            paramLaunchpad._hasWhitelisting
        );
        launchPadContract = await launchPadContract.deployed();
        const launchPadAddress = launchPadContract.address;
        // console.log('LaunchPad Contract: ', launchPadAddress);

        // Mint token of project to launchPad
        await tokenContract.mint(launchPadAddress, utils.parseEther("1000000"));
        const launchPadTokenAmount = await tokenContract.balanceOf(launchPadAddress);
        expect(utils.formatEther(launchPadTokenAmount)).to.equal("1000000.0");
    });

    describe("Test Buyer - Permission", () => {

        it('Buyer Has Permission Buy Token', async function () {
            await rirContract.mint(owner.address, utils.parseEther("1000"))
            const amountOwner = await rirContract.balanceOf(owner.address);
            expect(utils.formatEther(amountOwner)).to.equal("1000.0");
            const canBuy = await launchPadContract.isBuyerHasRIR(owner.address)
            expect(canBuy).to.equal(true);
        });

        it('Buyer Has Not Permission Buy Token', async function () {
            const amountOwner = await rirContract.balanceOf(owner.address);
            expect(utils.formatEther(amountOwner)).to.equal("0.0");
            const canBuy = await launchPadContract.isBuyerHasRIR(owner.address)
            expect(canBuy).to.equal(false);
        });

    });

    describe("Import Orders", () => {

        it('Add Import Orders - OK', async function () {
            await launchPadContract.addOrdersImport(
                [owner.address, addr1.address, addr2.address, addr3.address],
                [utils.parseEther("1000"), utils.parseEther("2000"), utils.parseEther("3000"),utils.parseEther("2000")],
                [true, true, false, true]
            );
            const orderOwner = await launchPadContract.getOrderImport(owner.address);
            expect(utils.formatEther(orderOwner.amountRIR)).to.equal("10.0");
            expect(utils.formatEther(orderOwner.amountBUSD)).to.equal("1000.0");
            expect(utils.formatEther(orderOwner.amountToken)).to.equal("1000.0");

            const orderAddr1 = await launchPadContract.getOrderImport(addr1.address);
            expect(utils.formatEther(orderAddr1.amountRIR)).to.equal("20.0");
            expect(utils.formatEther(orderAddr1.amountBUSD)).to.equal("2000.0");
            expect(utils.formatEther(orderAddr1.amountToken)).to.equal("2000.0");

            const orderAddr2 = await launchPadContract.getOrderImport(addr2.address);
            expect(utils.formatEther(orderAddr2.amountRIR)).to.equal("0.0");
            expect(utils.formatEther(orderAddr2.amountBUSD)).to.equal("3000.0");
            expect(utils.formatEther(orderAddr2.amountToken)).to.equal("3000.0");
        });

        it('Add Import Orders - Error', async function () {
            const orderImport = launchPadContract.addOrdersImport(
                [owner.address, addr1.address, addr1.address, addr2.address],
                [utils.parseEther("1000"), utils.parseEther("2000"), utils.parseEther("3000"),utils.parseEther("2000")],
                [true, true, false, true]
            );
            await expect(orderImport).to.revertedWith("Address Buyer already exist");
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
            await bUSDContract.connect(addr1).approve(launchPadContract.address, constants.MaxUint256);
            launchPadContract.connect(addr1).createOrder(utils.parseEther("1"), true);
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
