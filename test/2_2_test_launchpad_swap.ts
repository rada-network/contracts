// @ts-ignore
import { ethers, upgrades } from "hardhat"
import { constants, Contract, utils } from "ethers"
import { expect, use } from 'chai';
import { solidity } from 'ethereum-waffle';
import { assert } from "console";

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
            _bUSDForSale: utils.parseEther("1000"),
            _startDate: startDate,
            _endDate: endDate,
            _individualMinimumAmountBusd: utils.parseEther("100"),
            _individualMaximumAmountBusd: utils.parseEther("500"),
            _feeTax: 0,
        };

        launchPadContract = await upgrades.deployProxy(launchPadFactory, [
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
        // console.log('LaunchPad Contract: ', launchPadAddress);

        // Mint token of project to launchPad
        // await tokenContract.mint(launchPadAddress, utils.parseEther("1000000"));
        // const launchPadTokenAmount = await tokenContract.balanceOf(launchPadAddress);
        // expect(utils.formatEther(launchPadTokenAmount)).to.equal("1000000.0");
    });

    describe("Test Buyer Have RIR", () => {

        it('Have RIR', async function () {
            await rirContract.mint(owner.address, utils.parseEther("1000"))
            const amountOwner = await rirContract.balanceOf(owner.address);
            expect(utils.formatEther(amountOwner)).to.equal("1000.0");
            const canBuy = await launchPadContract.isBuyerHasRIR(owner.address)
            expect(canBuy).to.equal(true);
        });

        it('Have Not RIR', async function () {
            const amountOwner = await rirContract.balanceOf(owner.address);
            expect(utils.formatEther(amountOwner)).to.equal("0.0");
            const canBuy = await launchPadContract.isBuyerHasRIR(owner.address)
            expect(canBuy).to.equal(false);
        });

    });

    describe("Create Subscription", () => {

        it('Buyer Subscription', async function () {
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
            await launchPadContract.connect(addr1).createSubscription(utils.parseEther("100"), utils.parseEther("1"), addr4.address);

            let orderAddr1 = await launchPadContract.connect(addr1).getOrderSubscriber(addr1.address);
            expect(utils.formatEther(orderAddr1[0])).to.equal("1.0", "Order RIR amount - Address 1");
            expect(utils.formatEther(orderAddr1[1])).to.equal("100.0", "Order Busd amount - Address 1");
            expect(orderAddr1[2]).to.equal(addr4.address);

            addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
            addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
            addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);

            expect(utils.formatEther(addr1_BusdAmount)).to.equal("900.0");
            expect(utils.formatEther(addr1_RIRAmount)).to.equal("9.0");
            expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");

            await launchPadContract.connect(addr1).createSubscription(utils.parseEther("100"), utils.parseEther("1"), addr4.address);

            orderAddr1 = await launchPadContract.connect(addr1).getOrderSubscriber(addr1.address);
            expect(utils.formatEther(orderAddr1[0])).to.equal("2.0", "Order RIR amount - Address 1");
            expect(utils.formatEther(orderAddr1[1])).to.equal("200.0", "Order Busd amount - Address 1");
            expect(orderAddr1[2]).to.equal(addr4.address);

            addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
            addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
            addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);
            expect(utils.formatEther(addr1_BusdAmount)).to.equal("800.0");
            expect(utils.formatEther(addr1_RIRAmount)).to.equal("8.0");
            expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");

            await expect(launchPadContract.connect(addr1).createSubscription(utils.parseEther("200"), utils.parseEther("5"), addr4.address)).to.revertedWith('Amount is not valid');

            await launchPadContract.connect(addr1).createSubscription(utils.parseEther("300"), utils.parseEther("0"), addr4.address);

            orderAddr1 = await launchPadContract.connect(addr1).getOrderSubscriber(addr1.address);
            expect(utils.formatEther(orderAddr1[0])).to.equal("2.0", "Order RIR amount - Address 1");
            expect(utils.formatEther(orderAddr1[1])).to.equal("500.0", "Order Busd amount - Address 1");
            expect(orderAddr1[2]).to.equal(addr4.address);

            addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
            addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
            addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);
            expect(utils.formatEther(addr1_BusdAmount)).to.equal("500.0");
            expect(utils.formatEther(addr1_RIRAmount)).to.equal("8.0");
            expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");

            // Test order max
            await expect(launchPadContract.connect(addr1).createSubscription(utils.parseEther("300"), utils.parseEther("5"), addr4.address)).to.revertedWith('Amount is overcome maximum');

            expect(utils.formatUnits(await launchPadContract.subscriptionCount(), 0)).to.equal('1', "Count Order Sub")

            // Address 2 - Order
            await rirContract.mint(addr2.address, utils.parseEther("20"));
            let addr2_RIRAmount = await rirContract.balanceOf(addr2.address);
            expect(utils.formatEther(addr2_RIRAmount)).to.equal("20.0");

            await bUSDContract.mint(addr2.address, utils.parseEther("1000"));
            let addr2_BusdAmount = await bUSDContract.balanceOf(addr2.address);
            expect(utils.formatEther(addr2_BusdAmount)).to.equal("1000.0");

            await rirContract.connect(addr2).approve(launchPadContract.address, constants.MaxUint256);
            await bUSDContract.connect(addr2).approve(launchPadContract.address, constants.MaxUint256);
            await expect(launchPadContract.connect(addr2).createSubscription(utils.parseEther("200"), utils.parseEther("5"), addr4.address)).to.reverted;
            expect(utils.formatUnits(await launchPadContract.subscriptionCount(), 0)).to.equal('1', "Count Order Sub")

            await launchPadContract.connect(addr2).createSubscription(utils.parseEther("200"), utils.parseEther("2"), addr4.address);
            let orderBuyerAddr2 = await launchPadContract.connect(addr2).getOrderSubscriber(addr2.address);
            expect(utils.formatEther(orderBuyerAddr2[0])).to.equal("2.0", "Order RIR amount - Address 2");
            expect(utils.formatEther(orderBuyerAddr2[1])).to.equal("200.0", "Order Busd amount - Address 2");
            expect(orderBuyerAddr2[2]).to.equal(addr4.address);
            addr2_BusdAmount = await bUSDContract.balanceOf(addr2.address);
            addr2_RIRAmount = await rirContract.balanceOf(addr2.address);

            expect(utils.formatEther(addr2_BusdAmount)).to.equal("800.0");
            expect(utils.formatEther(addr2_RIRAmount)).to.equal("18.0");

            expect(utils.formatUnits(await launchPadContract.subscriptionCount(), 0)).to.equal('2', "Count Order Sub")

            // Address 3 - Order
            await rirContract.mint(addr3.address, utils.parseEther("5"));
            let addr3_RIRAmount = await rirContract.balanceOf(addr3.address);
            expect(utils.formatEther(addr3_RIRAmount)).to.equal("5.0");

            await bUSDContract.mint(addr3.address, utils.parseEther("2000"));
            let addr3_BusdAmount = await bUSDContract.balanceOf(addr3.address);
            expect(utils.formatEther(addr3_BusdAmount)).to.equal("2000.0");

            await rirContract.connect(addr3).approve(launchPadContract.address, constants.MaxUint256);
            await bUSDContract.connect(addr3).approve(launchPadContract.address, constants.MaxUint256);
            await expect(launchPadContract.connect(addr3).createSubscription(utils.parseEther("50"), utils.parseEther("1"), addr4.address)).to.revertedWith("Amount is overcome minimum");

            expect(utils.formatUnits(await launchPadContract.subscriptionCount(), 0)).to.equal('2', "Count Order Sub")

            describe("Import Winners", () => {

                it('Buyer is not subscriber', async () => {
                    const importWinners = launchPadContract.connect(owner).importWinners(
                        [addr1.address, addr3.address, addr4.address],
                        [utils.parseEther("500"), utils.parseEther("200"), utils.parseEther("200")]
                    );
                    await expect(importWinners).to.revertedWith("Buyer is not subscriber");
                })

                describe("Import is OK", () => {
                    it('Import is OK', async function () {

                        await launchPadContract.connect(owner).importWinners(
                            [addr1.address, addr2.address],
                            [utils.parseEther("500"), utils.parseEther("200")],
                        );

                        const orderAddr1 = await launchPadContract.getOrderWinner(addr1.address);
                        expect(utils.formatEther(orderAddr1.amountRIR)).to.equal("0.0");
                        expect(utils.formatEther(orderAddr1.amountBUSD)).to.equal("500.0");

                        const orderAddr2 = await launchPadContract.getOrderWinner(addr2.address);
                        expect(utils.formatEther(orderAddr2.amountRIR)).to.equal("0.0");
                        expect(utils.formatEther(orderAddr2.amountBUSD)).to.equal("200.0");

                        let count = await launchPadContract.winCount();
                        expect(count).to.equal(2);

                        let winners = await launchPadContract.getWinners();
                        expect(winners.length).to.equal(2);

                        const importWinners = launchPadContract.connect(owner).importWinners(
                            [addr4.address],
                            [utils.parseEther("10")]
                        );

                        await expect(importWinners).to.revertedWith("Wins need empty");
                        count = await launchPadContract.winCount();
                        expect(count).to.equal(2);

                        describe("Imported", () => {
                            it('ReImport', async function () {
                                await launchPadContract.connect(owner).setEmptyWins();
                                count = await launchPadContract.winCount();
                                expect(count).to.equal(0);
                                winners = await launchPadContract.getWinners();
                                expect(winners.length).to.equal(0);

                                await launchPadContract.connect(owner).importWinners(
                                    [addr1.address, addr2.address],
                                    [utils.parseEther("500"), utils.parseEther("200")]
                                );

                            })
                        })


                        describe("Commit Winners", () => {
                            it('Commit', async function () {
                                await launchPadContract.connect(owner).commitWinners();

                                describe("Deposit Token", async () => {
                                    it('Deposit Success', async () => {
                                        let owner_tokenAmount = await tokenContract.balanceOf(owner.address);
                                        expect(utils.formatEther(owner_tokenAmount)).to.equal("0.0");
                                        await tokenContract.mint(owner.address, utils.parseEther("1000000"));
                                        owner_tokenAmount = await tokenContract.balanceOf(owner.address);
                                        expect(utils.formatEther(owner_tokenAmount)).to.equal("1000000.0");
                                        let launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("0.0");

                                        await tokenContract.approve(launchPadContract.address, constants.MaxUint256);
                                        await launchPadContract.deposit(utils.parseEther("1000"));
                                        launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("1000.0");

                                        let tokenDeposit = await launchPadContract.depositTokens(0);
                                        expect(utils.formatEther(tokenDeposit)).to.equal("1000.0");

                                        await launchPadContract.deposit(utils.parseEther("2000"));
                                        tokenDeposit = await launchPadContract.depositTokens(1);
                                        expect(utils.formatEther(tokenDeposit)).to.equal("2000.0");
                                        launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("3000.0");

                                    })
                                })
                            })
                        })


                    });
                });
                it('Cannot Import', async function () {
                    const importWinners = launchPadContract.connect(owner).importWinners(
                        [addr1.address, addr1.address, addr2.address],
                        [utils.parseEther("100"), utils.parseEther("100"), utils.parseEther("200")]
                    );
                    await expect(importWinners).to.revertedWith("Buyer already exists in the list");

                    expect(await launchPadContract.winCount()).to.equal(0);
                });

                it('Set Empty Winners When Winners List Is Empty', async function () {
                    let buyerWhitelists = await launchPadContract.getWinners();
                    expect(buyerWhitelists.length).to.equal(0);
                    await expect(launchPadContract.connect(owner).setEmptyWins()).to.reverted;
                })

            });
        });

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

        //         await launchPadContract.importWinners(
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
    })

});
