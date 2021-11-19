// @ts-ignore
import { ethers, upgrades } from "hardhat"
import { constants, Contract, utils } from "ethers"
import { expect, use } from 'chai';
import { solidity } from 'ethereum-waffle';

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

        const launchPadFactory = await ethers.getContractFactory("LaunchPad");
        const paramLaunchpad = {
            _tokenAddress: tokenAddress,
            _bUSDAddress: busdAddress,
            _rirAddress: rirAddress,
            _tokenPrice: utils.parseEther("1"),
            _tokensForSale: utils.parseEther("8000"),
            _startDate: startDate,
            _endDate: endDate,
            _individualMinimumAmount: utils.parseEther("100"),
            _individualMaximumAmount: utils.parseEther("5000")
        };

        launchPadContract = await upgrades.deployProxy(launchPadFactory, [
            paramLaunchpad._tokenAddress,
            paramLaunchpad._bUSDAddress,
            paramLaunchpad._rirAddress,
            paramLaunchpad._tokenPrice,
            paramLaunchpad._tokensForSale,
            paramLaunchpad._startDate,
            paramLaunchpad._endDate,
            paramLaunchpad._individualMinimumAmount,
            paramLaunchpad._individualMaximumAmount,
        ],
            { unsafeAllowCustomTypes: true }
        );
        launchPadContract = await launchPadContract.deployed();
        const launchPadAddress = launchPadContract.address;
        // console.log('LaunchPad Contract: ', launchPadAddress);

        // Mint token of project to launchPad
        await tokenContract.mint(launchPadAddress, utils.parseEther("1000000"));
        const launchPadTokenAmount = await tokenContract.balanceOf(launchPadAddress);
        expect(utils.formatEther(launchPadTokenAmount)).to.equal("1000000.0");
    });

    // describe("Test Buyer - Permission", () => {

    //     it('Buyer Has Permission Buy Token', async function () {
    //         await rirContract.mint(owner.address, utils.parseEther("1000"))
    //         const amountOwner = await rirContract.balanceOf(owner.address);
    //         expect(utils.formatEther(amountOwner)).to.equal("1000.0");
    //         const canBuy = await launchPadContract.isBuyerHasRIR(owner.address)
    //         expect(canBuy).to.equal(true);
    //     });

    //     it('Buyer Has Not Permission Buy Token', async function () {
    //         const amountOwner = await rirContract.balanceOf(owner.address);
    //         expect(utils.formatEther(amountOwner)).to.equal("0.0");
    //         const canBuy = await launchPadContract.isBuyerHasRIR(owner.address)
    //         expect(canBuy).to.equal(false);
    //     });

    // });

    describe("White List", () => {

        it('White List Import is OK', async function () {
            await launchPadContract.connect(owner).importWhitelist(
                [owner.address, addr1.address, addr2.address, addr3.address],
                [utils.parseEther("1000"), utils.parseEther("2000"), utils.parseEther("3000"), utils.parseEther("2000")],
                [true, true, false, true]
            );
            let orderOwner = await launchPadContract.getBuyerInWhitelist(owner.address);
            expect(utils.formatEther(orderOwner.amountRIR)).to.equal("10.0");
            expect(utils.formatEther(orderOwner.amountBUSD)).to.equal("1000.0");
            expect(utils.formatEther(orderOwner.amountToken)).to.equal("1000.0");

            const orderAddr1 = await launchPadContract.getBuyerInWhitelist(addr1.address);
            expect(utils.formatEther(orderAddr1.amountRIR)).to.equal("20.0");
            expect(utils.formatEther(orderAddr1.amountBUSD)).to.equal("2000.0");
            expect(utils.formatEther(orderAddr1.amountToken)).to.equal("2000.0");

            const orderAddr2 = await launchPadContract.getBuyerInWhitelist(addr2.address);
            expect(utils.formatEther(orderAddr2.amountRIR)).to.equal("0.0");
            expect(utils.formatEther(orderAddr2.amountBUSD)).to.equal("3000.0");
            expect(utils.formatEther(orderAddr2.amountToken)).to.equal("3000.0");

            let count = await launchPadContract.whitelistCount();
            expect(count).to.equal(4);

            let buyerWhitelists = await launchPadContract.getBuyerWhitelists();
            expect(buyerWhitelists.length).to.equal(4);

            const whitelist = launchPadContract.connect(owner).importWhitelist(
                [addr4.address],
                [utils.parseEther("1000")],
                [true]
            );

            await expect(whitelist).to.revertedWith("Whitelist need empty");
            count = await launchPadContract.whitelistCount();
            expect(count).to.equal(4);


            await launchPadContract.connect(owner).deleteAllWhitelist();
            count = await launchPadContract.whitelistCount();
            expect(count).to.equal(0);
            buyerWhitelists = await launchPadContract.getBuyerWhitelists();
            expect(buyerWhitelists.length).to.equal(0);

        });

        it('White List Cannot Import', async function () {
            const whitelist = launchPadContract.connect(owner).importWhitelist(
                [owner.address, addr1.address, addr1.address, addr2.address],
                [utils.parseEther("1000"), utils.parseEther("2000"), utils.parseEther("3000"), utils.parseEther("2000")],
                [true, true, false, true]
            );
            await expect(whitelist).to.revertedWith("Address Buyer already exist");

            expect(await launchPadContract.whitelistCount()).to.equal(0);
        });

        it('Delete White List When WhiteList Is Empty', async function () {
            let buyerWhitelists = await launchPadContract.getBuyerWhitelists();
            expect(buyerWhitelists.length).to.equal(0);
            await expect(launchPadContract.connect(owner).deleteAllWhitelist()).to.reverted;
        })

        it('Verify White List', async function () {
            await expect(launchPadContract.connect(owner).verifyWhitelist()).to.reverted;

            await launchPadContract.connect(owner).importWhitelist(
                [owner.address, addr1.address, addr2.address, addr3.address],
                [utils.parseEther("1000"), utils.parseEther("2000"), utils.parseEther("2000"), utils.parseEther("2000")],
                [true, true, false, true]
            );

            const verifyWhiteList = await launchPadContract.connect(owner).verifyWhitelist();
            const isVerify = await launchPadContract.connect(owner).isVerifyWhitelist();
            expect(isVerify).to.true;
            
        })
        

    });

    // describe("Create Subscription", () => {

    //     it('Buyer - Has RIR', async function () {
    //         await rirContract.mint(addr1.address, utils.parseEther("10"));
    //         let addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
    //         expect(utils.formatEther(addr1_RIRAmount)).to.equal("10.0");

    //         await bUSDContract.mint(addr1.address, utils.parseEther("1000"));
    //         let addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
    //         expect(utils.formatEther(addr1_BusdAmount)).to.equal("1000.0");

    //         let addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);
    //         expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");

    //         await rirContract.connect(addr1).approve(launchPadContract.address, constants.MaxUint256);
    //         await bUSDContract.connect(addr1).approve(launchPadContract.address, constants.MaxUint256);
    //         await launchPadContract.connect(addr1).createSubscription(utils.parseEther("100"), true);

    //         let orderBuyer = await launchPadContract.connect(addr1).getSubscriber(addr1.address);
    //         expect(utils.formatEther(orderBuyer[0])).to.equal("1.0", "Order RIR amount - Address 1");
    //         expect(utils.formatEther(orderBuyer[1])).to.equal("100.0", "Order Busd amount - Address 1");
    //         expect(utils.formatEther(orderBuyer[2])).to.equal("0.0", "Order Token amount - Address 1");
    //         addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
    //         addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
    //         addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);

    //         expect(utils.formatEther(addr1_BusdAmount)).to.equal("900.0");
    //         expect(utils.formatEther(addr1_RIRAmount)).to.equal("9.0");
    //         expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");

    //         await expect(launchPadContract.connect(addr1).createSubscription(utils.parseEther("100"), true)).to.revertedWith("You was subscribe");

    //         addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
    //         addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
    //         addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);
    //         expect(utils.formatEther(addr1_BusdAmount)).to.equal("900.0");
    //         expect(utils.formatEther(addr1_RIRAmount)).to.equal("9.0");
    //         expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");

    //         expect(utils.formatEther(await launchPadContract.subscriptionCount())).to.equal("1.0", "Count Order Buyer")

    //         // Address 2 - Order
    //         await rirContract.mint(addr2.address, utils.parseEther("20"));
    //         let addr2_RIRAmount = await rirContract.balanceOf(addr2.address);
    //         expect(utils.formatEther(addr2_RIRAmount)).to.equal("20.0");

    //         await bUSDContract.mint(addr2.address, utils.parseEther("1000"));
    //         let addr2_BusdAmount = await bUSDContract.balanceOf(addr2.address);
    //         expect(utils.formatEther(addr2_BusdAmount)).to.equal("1000.0");

    //         await rirContract.connect(addr2).approve(launchPadContract.address, constants.MaxUint256);
    //         await bUSDContract.connect(addr2).approve(launchPadContract.address, constants.MaxUint256);
    //         await launchPadContract.connect(addr2).createSubscription(utils.parseEther("200"), true);

    //         let orderBuyerAddr2 = await launchPadContract.connect(addr2).getSubscriber(addr2.address);
    //         expect(utils.formatEther(orderBuyerAddr2[0])).to.equal("2.0", "Order RIR amount - Address 2");
    //         expect(utils.formatEther(orderBuyerAddr2[1])).to.equal("200.0", "Order Busd amount - Address 2");
    //         expect(utils.formatEther(orderBuyerAddr2[2])).to.equal("0.0", "Order Token amount - Address 2");
    //         addr2_BusdAmount = await bUSDContract.balanceOf(addr2.address);
    //         addr2_RIRAmount = await rirContract.balanceOf(addr2.address);

    //         expect(utils.formatEther(addr2_BusdAmount)).to.equal("800.0");
    //         expect(utils.formatEther(addr2_RIRAmount)).to.equal("18.0");

    //         expect(utils.formatEther(await launchPadContract.subscriptionCount())).to.equal("2.0", "Count Order Buyer");

    //         // Address 3 - Order
    //         await rirContract.mint(addr3.address, utils.parseEther("5"));
    //         let addr3_RIRAmount = await rirContract.balanceOf(addr3.address);
    //         expect(utils.formatEther(addr3_RIRAmount)).to.equal("5.0");

    //         await bUSDContract.mint(addr3.address, utils.parseEther("2000"));
    //         let addr3_BusdAmount = await bUSDContract.balanceOf(addr3.address);
    //         expect(utils.formatEther(addr3_BusdAmount)).to.equal("2000.0");

    //         await rirContract.connect(addr3).approve(launchPadContract.address, constants.MaxUint256);
    //         await bUSDContract.connect(addr3).approve(launchPadContract.address, constants.MaxUint256);
    //         await launchPadContract.connect(addr3).createSubscription(utils.parseEther("300"), false);

    //         let orderBuyerAddr3 = await launchPadContract.connect(addr3).getSubscriber(addr3.address);
    //         expect(utils.formatEther(orderBuyerAddr3[0])).to.equal("0.0", "Order RIR amount - Address 3");
    //         expect(utils.formatEther(orderBuyerAddr3[1])).to.equal("300.0", "Order Busd amount - Address 3");
    //         expect(utils.formatEther(orderBuyerAddr3[2])).to.equal("0.0", "Order Token amount - Address 3");
    //         addr3_BusdAmount = await bUSDContract.balanceOf(addr3.address);
    //         addr3_RIRAmount = await rirContract.balanceOf(addr3.address);

    //         expect(utils.formatEther(addr3_BusdAmount)).to.equal("1700.0");
    //         expect(utils.formatEther(addr3_RIRAmount)).to.equal("5.0");

    //         expect(utils.formatEther(await launchPadContract.subscriptionCount())).to.equal("3.0", "Count Order Buyer");

    //         let launchPad_BusdAmount = await bUSDContract.balanceOf(launchPadContract.address);
    //         let launchPad_RIRAmount = await rirContract.balanceOf(launchPadContract.address);
    //         expect(utils.formatEther((launchPad_BusdAmount))).to.equal("600.0");
    //         expect(utils.formatEther((launchPad_RIRAmount))).to.equal("3.0");
    //     });

    //     it('Sync Order', async function () {
    //         await rirContract.mint(addr1.address, utils.parseEther("10"));
    //         let addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
    //         expect(utils.formatEther(addr1_RIRAmount)).to.equal("10.0");

    //         await bUSDContract.mint(addr1.address, utils.parseEther("1000"));
    //         let addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
    //         expect(utils.formatEther(addr1_BusdAmount)).to.equal("1000.0");

    //         let addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);
    //         expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");

    //         await rirContract.connect(addr1).approve(launchPadContract.address, constants.MaxUint256);
    //         await bUSDContract.connect(addr1).approve(launchPadContract.address, constants.MaxUint256);
    //         await launchPadContract.connect(addr1).createSubscription(utils.parseEther("100"), true);
    //         addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
    //         expect(utils.formatEther(addr1_RIRAmount)).to.equal("9.0");

    //         await rirContract.mint(owner.address, utils.parseEther("10"));
    //         let owner_RIRAmount = await rirContract.balanceOf(owner.address);
    //         expect(utils.formatEther(owner_RIRAmount)).to.equal("10.0");

    //         await bUSDContract.mint(owner.address, utils.parseEther("1000"));
    //         let owner_BusdAmount = await bUSDContract.balanceOf(owner.address);
    //         expect(utils.formatEther(owner_BusdAmount)).to.equal("1000.0");

    //         let owner_tokenAmount = await tokenContract.balanceOf(owner.address);
    //         expect(utils.formatEther(owner_tokenAmount)).to.equal("0.0");

    //         await rirContract.connect(owner).approve(launchPadContract.address, constants.MaxUint256);
    //         await bUSDContract.connect(owner).approve(launchPadContract.address, constants.MaxUint256);
    //         await launchPadContract.connect(owner).createSubscription(utils.parseEther("400"), true);

    //         await launchPadContract.importWhitelist(
    //             [owner.address],
    //             [utils.parseEther("100")],
    //             [true]
    //         );

    //         await launchPadContract.sync();

    //         let winnerAddr1 = await launchPadContract.wins(addr1.address);
    //         expect(utils.formatEther(winnerAddr1[0])).to.equal("1.0", "Order RIR amount - Address 1");
    //         expect(utils.formatEther(winnerAddr1[1])).to.equal("100.0", "Order Busd amount - Address 1");
    //         expect(utils.formatEther(winnerAddr1[2])).to.equal("0.0", "Order Token amount - Address 1");

    //         let winnerOwner = await launchPadContract.wins(owner.address);
    //         expect(utils.formatEther(winnerOwner[0])).to.equal("3.0", "Order RIR amount - Address Owner");
    //         expect(utils.formatEther(winnerOwner[1])).to.equal("300.0", "Order Busd amount - Address Owner");
    //         expect(utils.formatEther(winnerOwner[2])).to.equal("100.0", "Order Token amount - Address Owner");

    //         let winnersList = await launchPadContract.getWinners();
    //         expect(winnersList.length).to.equal(2);

    //         await launchPadContract.fund();
    //         await launchPadContract.connect(addr1).claimToken();
    //         addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
    //         addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
    //         addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);
    //         expect(utils.formatEther(addr1_RIRAmount)).to.equal("10.0");
    //         expect(utils.formatEther(addr1_BusdAmount)).to.equal("1000.0");
    //         expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");

    //         await launchPadContract.connect(owner).claimToken();
    //         owner_RIRAmount = await rirContract.balanceOf(owner.address);
    //         owner_BusdAmount = await bUSDContract.balanceOf(owner.address);
    //         owner_tokenAmount = await tokenContract.balanceOf(owner.address);
    //         expect(utils.formatEther(owner_RIRAmount)).to.equal("9.0");
    //         expect(utils.formatEther(owner_BusdAmount)).to.equal("900.0");
    //         expect(utils.formatEther(owner_tokenAmount)).to.equal("100.0");
    //     });
    // })


});
