// @ts-ignore
import { ethers, upgrades } from "hardhat"
import { constants, Contract, utils, BigNumberish, BigNumber } from "ethers"
import { expect, use, util } from 'chai';
import { solidity } from 'ethereum-waffle';
import { Address } from "cluster";
import exp from "constants";

use(solidity);

describe("LaunchVerse", async function () {

    let launchPadContract: Contract;
    let tokenContract: Contract;
    let bUSDContract: Contract;
    let rirContract: Contract;
    let owner: any;
    let addr1: any;
    let addr2: any;
    let addr3: any;
    let addr4: any;

    const TOKEN_FEE = 0;

    const parseEther = (num: number) => utils.parseEther(num.toFixed(18))
    const formatEther = (num: number) => utils.formatEther(parseEther(num))

    let tokenAddress: String;

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
        tokenAddress = tokenContract.address;
        // console.log('Token Project: ', tokenAddress);

        // Token RIR
        const rirContractFactory = await ethers.getContractFactory("ERC20Token");
        rirContract = await rirContractFactory.deploy("RIR", "RIR");
        rirContract = await rirContract.deployed();
        const rirAddress = rirContract.address;
        // console.log('RIR Contract: ', rirAddress);

        const startDate = Math.floor((Date.now() - 24 * 60 * 60 * 1000) / 1000);
        const endDate = Math.floor((Date.now() + 7 * 24 * 60 * 60 * 1000) / 1000);

        const launchPadFactory = await ethers.getContractFactory("LaunchVerse");

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
            _tokenFee: parseEther(TOKEN_FEE)
        };

        launchPadContract = await upgrades.deployProxy(launchPadFactory, [
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

        // 

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
            expect(utils.formatEther(orderAddr1.amountRIR)).to.equal("1.0", "Order RIR amount - Address 1"); // amountRIR
            expect(utils.formatEther(orderAddr1.amountBUSD)).to.equal("100.0", "Order Busd amount - Address 1"); // amountBUSD
            expect(orderAddr1.referer).to.equal(addr4.address); // referer
            expect(utils.formatEther(orderAddr1.approvedBUSD)).to.equal("0.0"); // approvedBUSD
            expect(utils.formatEther(orderAddr1.refundedBUSD)).to.equal("0.0"); // refundedBUSD
            expect(utils.formatEther(orderAddr1.claimedToken)).to.equal("0.0"); // claimedToken


            addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
            addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
            addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);

            expect(utils.formatEther(addr1_BusdAmount)).to.equal("900.0");
            expect(utils.formatEther(addr1_RIRAmount)).to.equal("9.0");
            expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");
            console.log('create sub 2');
            await launchPadContract.connect(addr1).createSubscription(utils.parseEther("100"), utils.parseEther("1"), addr3.address);

            orderAddr1 = await launchPadContract.connect(addr1).getOrderSubscriber(addr1.address);
            expect(utils.formatEther(orderAddr1[0])).to.equal("2.0", "Order RIR amount - Address 1");
            expect(utils.formatEther(orderAddr1[1])).to.equal("200.0", "Order Busd amount - Address 1");
            expect(orderAddr1[2]).to.equal(addr4.address); // not change referer

            addr1_BusdAmount = await bUSDContract.balanceOf(addr1.address);
            addr1_RIRAmount = await rirContract.balanceOf(addr1.address);
            addr1_tokenAmount = await tokenContract.balanceOf(addr1.address);
            expect(utils.formatEther(addr1_BusdAmount)).to.equal("800.0");
            expect(utils.formatEther(addr1_RIRAmount)).to.equal("8.0");
            expect(utils.formatEther(addr1_tokenAmount)).to.equal("0.0");

            // push more RIR than require (RIR * 100 > BUSD)
            await expect(launchPadContract.connect(addr1).createSubscription(utils.parseEther("200"), utils.parseEther("5"), addr4.address)).to.revertedWith('Amount is not valid');
            console.log('create sub 3');
            await launchPadContract.connect(addr1).createSubscription(utils.parseEther("300"), utils.parseEther("0"), addr3.address);

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
            // revert - more RIR than require
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

                        // addr1: 500$ 2RIR
                        const orderAddr1 = await launchPadContract.getOrderSubscriber(addr1.address);
                        expect(utils.formatEther(orderAddr1.amountRIR)).to.equal("2.0");
                        expect(utils.formatEther(orderAddr1.amountBUSD)).to.equal("500.0");
                        expect(utils.formatEther(orderAddr1.approvedBUSD)).to.equal("500.0");
                        expect(utils.formatEther(orderAddr1.refundedBUSD)).to.equal("0.0");
                        expect(utils.formatEther(orderAddr1.claimedToken)).to.equal("0.0");

                        // addr2: 200$ 2RIR
                        const orderAddr2 = await launchPadContract.getOrderSubscriber(addr2.address);
                        expect(utils.formatEther(orderAddr2.amountRIR)).to.equal("2.0");
                        expect(utils.formatEther(orderAddr2.amountBUSD)).to.equal("200.0");
                        expect(utils.formatEther(orderAddr2.approvedBUSD)).to.equal("200.0");
                        expect(utils.formatEther(orderAddr2.refundedBUSD)).to.equal("0.0");
                        expect(utils.formatEther(orderAddr2.claimedToken)).to.equal("0.0");

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

                                // import with over
                                await expect(launchPadContract.connect(owner).importWinners(
                                    [addr1.address, addr2.address],
                                    [utils.parseEther("600"), utils.parseEther("200")]
                                )).to.reverted;

                                // not fullfill
                                await expect(launchPadContract.connect(owner).importWinners(
                                    [addr1.address, addr2.address],
                                    [utils.parseEther("400"), utils.parseEther("200")]
                                )).to.reverted;
                            })
                        })


                        describe("Commit Winners", () => {
                            it('Commit', async function () {
                                // commit without import
                                console.log('try to commit to empty winer list')
                                await expect(launchPadContract.connect(owner).commitWinners()).to.reverted;
                                // import
                                await launchPadContract.connect(owner).importWinners(
                                    [addr1.address, addr2.address],
                                    [utils.parseEther("500"), utils.parseEther("200")]
                                );
                                await launchPadContract.connect(owner).commitWinners();


                                describe("Deposit Token", async () => {
                                    it('Deposit Success', async () => {
                                        // total sale token: 1000/1 = 1000
                                        let totalTokenForSale = await launchPadContract.getTotalTokenForSale();
                                        expect(utils.formatEther(totalTokenForSale)).to.equal("1000.0");

                                        let owner_tokenAmount = await tokenContract.balanceOf(owner.address);
                                        expect(utils.formatEther(owner_tokenAmount)).to.equal("0.0");
                                        await tokenContract.mint(owner.address, utils.parseEther("1000000"));
                                        owner_tokenAmount = await tokenContract.balanceOf(owner.address);
                                        expect(utils.formatEther(owner_tokenAmount)).to.equal("1000000.0");
                                        let launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("0.0");

                                        // update token address
                                        await launchPadContract.connect(owner).setTokenAddress(tokenAddress);
                                        // verify token address is set
                                        expect(await launchPadContract.tokenAddress()).to.equal(tokenAddress);
                                        await launchPadContract.commitTokenAddress();

                                        await tokenContract.approve(launchPadContract.address, constants.MaxUint256);
                                        await launchPadContract.deposit(utils.parseEther("100"));
                                        launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("100.0");

                                        let tokenDeposit = await launchPadContract.totalTokenDeposited();
                                        expect(utils.formatEther(tokenDeposit)).to.equal("100.0");

                                        // total sale 1000, invest addr1 500, addr2 200, no refund
                                        // max need deposit 700
                                        // deposit 70 => addr1: 50, addr2 20
                                        
                                        let orderAddr1 = await launchPadContract.connect(addr1).getOrderSubscriber(addr1.address);
                                        
                                        const expectClaimable = (claimable: BigNumberish[], expected: number[]) => {
                                            expect(utils.formatEther(claimable[0])).to.equal(formatEther(expected[0]));
                                            expect(utils.formatEther(claimable[1])).to.equal(formatEther(expected[1]));
                                        }

                                        let claimable = await launchPadContract.getClaimable(addr1.address);
                                        expectClaimable(claimable, [0, 50]);
                                        // for addr2
                                        claimable = await launchPadContract.getClaimable(addr2.address);
                                        expectClaimable(claimable, [0, 20]);

                                        // claim
                                        console.log(
                                            'claim',
                                            utils.formatEther(claimable[1]),
                                            utils.formatEther(await tokenContract.balanceOf(launchPadContract.address))
                                        )                                        
                                        await launchPadContract.connect(addr1).claim();
                                        // make sure the claimed info update, balance is reduce
                                        orderAddr1 = await launchPadContract.connect(addr1).getOrderSubscriber(addr1.address);
                                        expect(utils.formatEther(orderAddr1[0])).to.equal("2.0", "Order RIR amount - Address 1"); // amountRIR
                                        expect(utils.formatEther(orderAddr1[1])).to.equal("500.0", "Order Busd amount - Address 1"); // amountBUSD
                                        expect(orderAddr1[2]).to.equal(addr4.address); // referer
                                        expect(utils.formatEther(orderAddr1[3])).to.equal("500.0"); // approvedBUSD
                                        expect(utils.formatEther(orderAddr1[4])).to.equal("0.0"); // refundedBUSD
                                        expect(utils.formatEther(orderAddr1[5])).to.equal("50.0"); // claimedToken


                                        // deposit more
                                        await launchPadContract.deposit(utils.parseEther("800000"));
                                        tokenDeposit = await launchPadContract.totalTokenDeposited();
                                        expect(utils.formatEther(tokenDeposit)).to.equal("800100.0");
                                        launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);

                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("800050.0");

                                        // check claimable
                                        claimable = await launchPadContract.getClaimable(addr1.address);
                                        expectClaimable(claimable, [0, 450]);
                                        
                                        // for addr2
                                        claimable = await launchPadContract.getClaimable(addr2.address);
                                        expectClaimable(claimable, [0, 200]);

                                        // claim for addr2, all it's token take
                                        await launchPadContract.connect(addr2).claim();
                                        let addr2_tokenAmount = await tokenContract.balanceOf(addr2.address);
                                        expect(utils.formatEther(addr2_tokenAmount)).to.equal("200.0");
                                        launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("799850.0");

                                        // reclaim for addr2, nothing change
                                        await launchPadContract.connect(addr2).claim();
                                        addr2_tokenAmount = await tokenContract.balanceOf(addr2.address);
                                        expect(utils.formatEther(addr2_tokenAmount)).to.equal("200.0");
                                        launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("799850.0");

                                        // claim token addr1, get last 450
                                        await launchPadContract.connect(addr1).claim();
                                        addr2_tokenAmount = await tokenContract.balanceOf(addr1.address);
                                        expect(utils.formatEther(addr2_tokenAmount)).to.equal("500.0");
                                        launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("799400.0");

                                        // check remain token to withdraw
                                        let remainToken = await launchPadContract.connect(owner).getUnsoldTokens();
                                        expect(utils.formatEther(remainToken)).to.equal("799400.0");

                                        // update withdraw address
                                        await launchPadContract.connect(owner).setWithdrawAddress(owner.address);
                                        // verify token address is set
                                        let withdrawAddress = await launchPadContract.WITHDRAW_ADDRESS();
                                        expect(withdrawAddress).to.equal(owner.address);
                                        await launchPadContract.commitWithdrawAddress();
                                        // verify cannot change
                                        //expect(await launchPadContract.setWithdrawAddress(addr1.address)).to.reverted;

                                        // withdraw
                                        await launchPadContract.withdrawUnsoldTokens();
                                        launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                        expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("0.0");
                                        

                                        describe("Withdraw Token", async () => {
                                            it("Withdraw Busd", async () => {
                                                await launchPadContract.withdrawBusdFunds();
                                                let launchPadContract_bUSDAmount = await bUSDContract.balanceOf(launchPadContract.address);
                                                expect(utils.formatEther(launchPadContract_bUSDAmount)).to.equal("0.0");

                                                let addrWithdraw_bUSDAmount = await bUSDContract.balanceOf(withdrawAddress);
                                                expect(utils.formatEther(addrWithdraw_bUSDAmount)).to.equal("700.0");

                                                // Test have withdrawn
                                                await expect(launchPadContract.withdrawBusdFunds()).to.revertedWith("You have withdrawn Busd");
                                            })

                                            // it("Withdraw Remain Token", async () => {
                                            //     await expect(launchPadContract.connect(addr4).withdrawTokensRemain()).to.reverted;
                                            //     await launchPadContract.withdrawTokensRemain();
                                            //     let launchPadContract_tokenAmount = await tokenContract.balanceOf(launchPadContract.address);
                                            //     expect(utils.formatEther(launchPadContract_tokenAmount)).to.equal("500.0");

                                            //     let addrWithdraw_tokenAmount = await tokenContract.balanceOf("0xdDDDbebEAD284030Ba1A59cCD99cE34e6d5f4C96");
                                            //     expect(utils.formatEther(addrWithdraw_tokenAmount)).to.equal("799400.0");
                                            // })
                                        })
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

    })

});
