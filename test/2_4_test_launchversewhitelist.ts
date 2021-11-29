// @ts-ignore
import { ethers, upgrades } from "hardhat"
import { constants, Contract, utils } from "ethers"
import { expect, use } from 'chai';
import { solidity } from 'ethereum-waffle';

use(solidity);

describe("LaunchVerse Whitelist", async function () {

    let launchPadContract: Contract;
    let tokenContract: Contract;
    let bUSDContract: Contract;
    let rirContract: Contract;
    let owner: any;
    let addr1: any;
    let addr2: any;
    let addr3: any;
    let addr4: any;

    beforeEach('Setup', async function () {
        [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

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

        const startDate = Math.floor(Date.now() / 1000);
        const endDate = Math.floor((Date.now() + 7 * 24 * 60 * 60 * 1000) / 1000);

        const launchPadFactory = await ethers.getContractFactory("LaunchVerseWhitelist");
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
            _tokenFee: 0,
        };

        launchPadContract = await upgrades.deployProxy(launchPadFactory, [
            //paramLaunchpad._tokenAddress,
            paramLaunchpad._bUSDAddress,
            paramLaunchpad._rirAddress,
            paramLaunchpad._tokenPrice,
            paramLaunchpad._bUSDForSale,
            paramLaunchpad._startDate,
            paramLaunchpad._endDate,
            paramLaunchpad._individualMinimumAmountBusd,
            paramLaunchpad._individualMaximumAmountBusd,
            paramLaunchpad._tokenFee
        ],
            { unsafeAllowCustomTypes: true }
        );
        launchPadContract = await launchPadContract.deployed();
        const launchPadAddress = launchPadContract.address;
        // console.log('LaunchPad Contract: ', launchPadAddress);

        // Mint token of project to launchPad
        // await tokenContract.mint(launchPadAddress, utils.parseEther("1000000"));
        // const launchPadTokenAmount = await tokenContract.balanceOf(launchPadAddress);
        // expect(utils.formatEther(launchPadTokenAmount)).to.equal("1000000.0");
    });

    describe("Test Add/Remove/Import Whitelist", () => {

        it('Check inWhitelist', async function () {
            expect(await launchPadContract.inWhitelist(addr1.address)).to.equal(false);
            // add to whitelist
            await launchPadContract.connect(owner).addToWhitelist(addr1.address);
            expect(await launchPadContract.inWhitelist(addr1.address)).to.equal(true);

            // import whitelist
            await launchPadContract.connect(owner).importWhitelist(
                [addr1.address, addr2.address, addr3.address]
            );
            // check exist
            expect(await launchPadContract.inWhitelist(addr1.address)).to.equal(true);
            expect(await launchPadContract.inWhitelist(addr2.address)).to.equal(true);
            expect(await launchPadContract.inWhitelist(addr3.address)).to.equal(true);

            // remove from whitelist
            await launchPadContract.connect(owner).removeFromWhitelist(addr2.address);
            expect(await launchPadContract.inWhitelist(addr1.address)).to.equal(true);
            expect(await launchPadContract.inWhitelist(addr2.address)).to.equal(false);
        });

        it('Check Subscription with whitelist', async function () {
            await rirContract.mint(addr1.address, utils.parseEther("10"));
            let addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
            expect(utils.formatEther(addr1_RIRAmount)).to.equal("10.0");

            await bUSDContract.mint(addr1.address, utils.parseEther("1000"));
            let addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
            expect(utils.formatEther(addr1_BusdAmount)).to.equal("1000.0");

            let addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);
            expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");
            await rirContract.connect(addr1).approve(launchPadContract.address, constants.MaxUint256);
            await bUSDContract.connect(addr1).approve(launchPadContract.address, constants.MaxUint256);

            // whitelist empty, expect revert
            await expect(launchPadContract.connect(addr1).createSubscription(utils.parseEther("100"), utils.parseEther("1"), addr4.address)).to.reverted;

            // import whitelist for addr1, addr3
            await launchPadContract.connect(owner).importWhitelist(
                [addr1.address, addr3.address]
            );

            // make sure addr1 in whitelist
            expect(await launchPadContract.inWhitelist(addr1.address)).to.equal(true);
            
            // allow addr1 join
            await expect(launchPadContract.connect(addr1).createSubscription(utils.parseEther("100"), utils.parseEther("1"), addr4.address)).not.reverted;
            let orderAddr1 = await launchPadContract.connect(addr1).getOrderSubscriber(addr1.address);
            expect(utils.formatEther(orderAddr1.amountRIR)).to.equal("1.0", "Order RIR amount - Address 1"); // amountRIR
            expect(utils.formatEther(orderAddr1.amountBUSD)).to.equal("100.0", "Order Busd amount - Address 1"); // amountBUSD
            expect(orderAddr1.referer).to.equal(addr4.address); // referer
            expect(utils.formatEther(orderAddr1.approvedBUSD)).to.equal("0.0"); // approvedBUSD
            expect(utils.formatEther(orderAddr1.refundedBUSD)).to.equal("0.0"); // refundedBUSD
            expect(utils.formatEther(orderAddr1.claimedToken)).to.equal("0.0"); // claimedToken

            // not allow addr2 join
            await expect(launchPadContract.connect(addr2).createSubscription(utils.parseEther("100"), utils.parseEther("1"), addr4.address)).to.reverted;

        })


    });
});