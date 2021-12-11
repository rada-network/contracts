// @ts-ignore
import { ethers, upgrades } from "hardhat"
import { constants, Contract, utils, BigNumberish, BigNumber } from "ethers"
import { expect, use, util } from 'chai';
import { solidity } from 'ethereum-waffle';
import { Address } from "cluster";
import exp from "constants";

use(solidity);

describe("RIR", async function () {

    let testContract: Contract;
    let tokenContract: Contract;
    let bUSDContract: Contract;
    let rirContract: Contract;
    let owner: any;
    let addr1: any;
    let addr2: any;
    let addr3: any;
    let addr4: any;

    let addrs: any[] = [];

    const address0 = '0x0000000000000000000000000000000000000000';
    const TOKEN_FEE = 0;

    const bn0 = utils.parseEther("0");
    const bn1 = utils.parseEther("1");
    const bn2 = utils.parseEther("2");
    const bn3 = utils.parseEther("3");
    const bn4 = utils.parseEther("4");
    const bn100 = utils.parseEther("100");
    const bn200 = utils.parseEther("200");
    const bn300 = utils.parseEther("300");
    const bn700 = utils.parseEther("700");
    const bn800 = utils.parseEther("800");
    const bn900 = utils.parseEther("900");
    const bn1000 = utils.parseEther("1000");


    const pe = (num: string) => utils.parseEther(num)
    const fe = (num: number) => utils.formatEther(num)

    let tokenAddress: String;

    beforeEach('Setup', async function () {
        [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
        addrs = await ethers.getSigners();

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

        const launchPadFactory = await ethers.getContractFactory("PoolRIR");


        testContract = await upgrades.deployProxy(launchPadFactory, [
            busdAddress,
            rirAddress
        ],
            { unsafeAllowCustomTypes: true }
        );
        testContract = await testContract.deployed();
        const launchPadAddress = testContract.address;
        
        // set admin and approver
        await testContract.setAdmin(addr1.address);
        await testContract.setApprover(addr2.address);
    });

    // min token for addr1 to deposit
    const test_mint = async(_tokenContract: any, _addr: any, _amount: any) => {
        let _amountBN = utils.parseEther(_amount);
        let _oldAmout = await _tokenContract.balanceOf(_addr.address);
        await _tokenContract.mint(_addr.address, _amountBN);
        let _newAmout = await _tokenContract.balanceOf(_addr.address);
        expect(utils.formatEther(_newAmout.sub(_oldAmout))).to.equal(utils.formatEther(_amountBN));
        await _tokenContract.connect(_addr).approve(testContract.address, constants.MaxUint256);
    }
    const test_balance = async(_tokenContract: any, _addr: any, _amount: any) => {
        let _balance = await _tokenContract.balanceOf(_addr.address);
        expect(utils.formatEther(_balance)).to.equal(_amount);
    }
    const show_balance = async(_tokenContract: any, _addr: any) => {
        let _balance = await _tokenContract.balanceOf(_addr.address);
        console.log("Balance: ", fe(_balance));
    }

    /*
    string memory _title,
        uint256 _allocationBusd,
        uint256 _minAllocationBusd,
        uint256 _maxAllocationBusd,
        uint256 _allocationRir,
        uint256 _price,
        uint256 _startDate,
        uint256 _endDate
        */
    
    describe("Whitelist Pool", async function () {
        it ("Add a Pool", async () => {
            // create new pool
            console.log("Add Pool");
            await testContract.addPool(
                "tk1",
                utils.parseEther("900"),
                utils.parseEther("100"),
                utils.parseEther("300"),
                utils.parseEther("4"),
                utils.parseEther("1"),
                Math.floor(Date.now() / 1000),
                Math.floor(Date.now() / 1000),
                0
            );
            await testContract.addPool(
                "elemon-whitelist",
                utils.parseEther("1000"),
                utils.parseEther("100"),
                utils.parseEther("300"),
                bn4,
                utils.parseEther("1"),
                Math.floor(Date.now() / 1000),  // start date
                Math.floor((Date.now() + 7 * 24 * 60 * 60 * 1000) / 1000),   //end date,
                10
            );
    
            expect (await testContract.poolCount()).to.equal(2);
            let pool = await testContract.getPool(1);
            expect(pool.title).to.equal("elemon-whitelist");
            expect(utils.formatEther(pool.allocationBusd)).to.equal("1000.0");
            expect(utils.formatEther(pool.price)).to.equal("1.0");
            expect(pool.claimOnly).to.equal(false);


            await test_mint(bUSDContract, addr2, "1000");
            await test_mint(rirContract, addr2, "10");
            await expect(testContract.connect(addr1).makePayment(1, utils.parseEther("100"), 0)).to.revertedWith("96");
            
            // lock pool
            await expect(testContract.connect(addr1).lockPool(1)).to.revertedWith("3");
            await testContract.connect(addr2).lockPool(1);
            expect((await testContract.getPool(1)).locked).to.equal(true);


            await test_mint(bUSDContract, addr1, "1000");
            await test_mint(rirContract, addr1, "10");

            await expect(testContract.connect(addr1).makePayment(1, utils.parseEther("1000"), 0)).to.revertedWith("102"); // over max
            await expect(testContract.connect(addr1).makePayment(1, utils.parseEther("50"), 0)).to.revertedWith("101"); // under min
            await testContract.connect(addr1).makePayment(1, utils.parseEther("300"), 0);

            await testContract.connect(addr2).makePayment(1, utils.parseEther("100"), 0);
            await testContract.connect(addr2).makePayment(1, utils.parseEther("0"), utils.parseEther("1"));
            await testContract.connect(addr2).makePayment(1, utils.parseEther("100"), utils.parseEther("1"));
            await test_balance(bUSDContract, addr2, "800.0"); 
            await test_balance(rirContract, addr2, "8.0"); 

            // purchase more
            await test_mint(bUSDContract, addr3, "1000");
            await test_mint(rirContract, addr3, "10");
            await testContract.connect(addr3).makePayment(1, utils.parseEther("300"), utils.parseEther("3"));

            await test_mint(bUSDContract, addr4, "1000");
            await test_mint(rirContract, addr4, "10");
            await testContract.connect(addr4).makePayment(1, utils.parseEther("300"), utils.parseEther("3"));

            await test_mint(bUSDContract, addrs[5], "1000");
            await test_mint(rirContract, addrs[5], "10");
            await testContract.connect(addrs[5]).makePayment(1, utils.parseEther("300"), utils.parseEther("1"));

            await test_mint(bUSDContract, addrs[6], "1000");
            await test_mint(rirContract, addrs[6], "10");
            // over rir allocation
            await expect(testContract.connect(addrs[6]).makePayment(1, utils.parseEther("300"), utils.parseEther("1"))).to.revertedWith("100");
            await testContract.connect(addrs[6]).makePayment(1, utils.parseEther("300"), 0);

            await test_mint(bUSDContract, addrs[7], "1000");
            await test_mint(rirContract, addrs[7], "10");
            await testContract.connect(addrs[7]).makePayment(1, utils.parseEther("300"), 0);

/*
    function importWinners(
        uint64 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _allocationBusds,
        uint256[] memory _allocationRirs
    )
    */            
            // now import winner
            await testContract.importWinners (
                1,
                [addr1.address, addr2.address, addr3.address, addr4.address],
                [bn100, bn100, bn100, bn100],
                [bn0, bn1, bn1, bn1]
            );

            // approve
            // await testContract.connect(addr2).approveInvestors(1);
            await expect(testContract.connect(addr2).approveInvestors(1)).to.revertedWith("91");

            // add more winners - rir investors
            await testContract.importWinners (
                1,
                [addrs[5].address, addrs[6].address, addrs[7].address, addr4.address],
                [bn100, bn100, bn100, bn200],
                [bn1, bn0, bn0, bn1]
            );
            //await expect(testContract.connect(addr2).approveInvestors(1)).to.revertedWith("93");
            let refundBusd: number, refundRir: number, claimable: number;

            // test get refund before approve
            claimable = await testContract.connect(addr1).getTotalClaimable(1);
            [refundBusd, refundRir] = await testContract.connect(addr1).getRefundable(1);
            expect(fe(refundBusd)).to.equal("0.0");
            expect(fe(refundRir)).to.equal("0.0");
            expect(fe(claimable)).to.equal("0.0");


            await testContract.connect(addr2).approveInvestors(1);

            // show total approve
            const ps = await testContract.poolsStat(1);
            console.log("Approved: ", fe(ps.amountBusd), fe(ps.approvedBusd), fe(ps.amountRir), fe(ps.approvedRir));

            // refund
            claimable = await testContract.connect(addr1).getTotalClaimable(1);
            [refundBusd, refundRir] = await testContract.connect(addr1).getRefundable(1);
            expect(fe(refundBusd)).to.equal("200.0");
            expect(fe(refundRir)).to.equal("0.0");
            expect(fe(claimable)).to.equal("90.0"); // should be 90
            claimable = await testContract.connect(addr1).getClaimable(1);
            expect(fe(claimable)).to.equal("0.0"); // not deposit

            // deposit
            let depositAmount = await testContract.getDepositAmount(1, 10);
            expect(fe(depositAmount)).to.equal("72.0");
            await expect(testContract.connect(addr1).deposit(1, depositAmount)).to.revertedWith("39"); // Not set tokenAddress

            // set token by request change
            await testContract.connect(addr1).requestChangePoolData(1, 0, 0, tokenAddress);

            // now need approve from 2 approvers: owner & addr2
            await testContract.connect(owner).approveRequestChange();
            // not change
            expect((await testContract.getPool(1)).tokenAddress).to.equal(address0);
            await testContract.connect(addr2).approveRequestChange();
            // now the token updated
            expect((await testContract.getPool(1)).tokenAddress).to.equal(tokenAddress);
            // Deposit again
            await expect(testContract.connect(addr1).deposit(1, depositAmount)).to.revertedWith("41"); // not enough Token
            // min

            await test_mint(tokenContract, addr1, "1000");
            await testContract.connect(addr1).deposit(1, depositAmount); // deposit 10%

            claimable = await testContract.connect(addr1).getTotalClaimable(1);
            [refundBusd, refundRir] = await testContract.connect(addr1).getRefundable(1);
            expect(fe(refundBusd)).to.equal("200.0");
            expect(fe(refundRir)).to.equal("0.0");
            expect(fe(claimable)).to.equal("90.0"); // should be 90
            claimable = await testContract.connect(addr1).getClaimable(1);
            expect(fe(claimable)).to.equal("9.0"); // not deposit

            // now claim
            await expect(testContract.connect(addr1).claim(1)).to.revertedWith("4"); // not enable claimable

            // make it claimable
            await testContract.connect(addr1).setClaimable(true);

            await testContract.connect(addr1).claim(1); // it is ok to claim now


            // check refund and claimable
            claimable = await testContract.connect(addr1).getTotalClaimable(1);
            [refundBusd, refundRir] = await testContract.connect(addr1).getRefundable(1);
            expect(fe(refundBusd)).to.equal("0.0");
            expect(fe(refundRir)).to.equal("0.0");
            expect(fe(claimable)).to.equal("90.0"); // should be 90
            claimable = await testContract.connect(addr1).getClaimable(1);
            expect(fe(claimable)).to.equal("0.0"); // not deposit

            // deposit more
            await expect(testContract.connect(addr1).deposit(1, utils.parseEther("649.0"))).to.revertedWith("40"); // deposit more than need - require only 720

            testContract.connect(addr1).deposit(1, utils.parseEther("648.0")); // deposit full
            claimable = await testContract.connect(addr1).getClaimable(1);
            expect(fe(claimable)).to.equal("81.0"); // rest
            [refundBusd, refundRir] = await testContract.connect(addr1).getRefundable(1);
            expect(fe(refundBusd)).to.equal("0.0");
            expect(fe(refundRir)).to.equal("0.0");

            await testContract.connect(addr2).claim(1); // it is ok to claim now
            test_balance(rirContract, addr2, "9.0"); // mint 10, prefund 2, approve 1

            // get fund and burn rir
            // set WITHDRAW_ADDRESS
            await testContract.connect(addr1).requestChangeWithdrawAddress(owner.address);
            // check address
            await testContract.connect(owner).approveRequestChange();
            expect(await testContract.connect(addr1).getWithdrawAddress()).to.equal(address0);
            await testContract.connect(addr2).approveRequestChange();
            expect(await testContract.connect(addr1).getWithdrawAddress()).to.equal(owner.address);

            // 
            test_balance(bUSDContract, testContract, "1700.0"); // prefund 2000, approve 800, refunded 200 for addr1, 100 for addr2
            test_balance(rirContract, testContract, "8.0"); // prefund 9, approve 4, refunded 1
            test_balance(bUSDContract, owner, "0.0"); // approved
            await testContract.connect(addr1).withdrawBusdFunds(1);
            test_balance(bUSDContract, testContract, "900.0"); // prefund 2000, approve 800, refunded 200 for addr1, 100 for addr2
            test_balance(rirContract, testContract, "4.0"); // prefund 9, approve 4, refunded 1
            test_balance(bUSDContract, owner, "800.0"); // approved

            // again
            await expect(testContract.connect(addr1).withdrawBusdFunds(1)).to.revertedWith("110"); // withdraw already
            // claim all

return;

            // Total allocation: 900
            console.log("Import Investor Whitelist");
            await testContract.importInvestors(
                1,
                [addr1.address, addr2.address, addr3.address, addr4.address],
                [utils.parseEther("200.0"),utils.parseEther("300.0"),utils.parseEther("500.0"),utils.parseEther("400.0")],
                [utils.parseEther("180.0"),utils.parseEther("270.0"),utils.parseEther("450.0"),utils.parseEther("360.0")]
            );

            console.log("Verify Investor Amount & Allocation");
            const investor1 = await testContract.getInvestor(1, addr1.address);
            const investor2 = await testContract.getInvestor(1, addr2.address);
            expect(utils.formatEther(investor1.amountBusd)).to.equal("200.0");
            expect(utils.formatEther(investor1.allocationBusd)).to.equal("180.0");
            expect(utils.formatEther(investor2.amountBusd)).to.equal("300.0");
            expect(utils.formatEther(investor2.allocationBusd)).to.equal("270.0");

            // try to approve Investor before lock pool
            console.log("Approve Investor");
            await expect(testContract.connect(addr1).approveInvestors(1)).to.revertedWith("3");
            await expect(testContract.connect(addr2).approveInvestors(1)).to.revertedWith("Pool not locked");

            // lock pool
            await expect(testContract.connect(addr1).lockPool(1)).to.revertedWith("3");
            await testContract.connect(addr2).lockPool(1);
            expect((await testContract.getPool(1)).locked).to.equal(true);

            // now approve Investor - Revert with Eceeds total allocation
            await expect(testContract.connect(addr2).approveInvestors(1)).to.revertedWith("Eceeds total allocation");

            // update Investor to reduce allocation
            await testContract.importInvestors(
                1,
                [addr4.address],
                [utils.parseEther("400.0")],
                [utils.parseEther("0.0")]
            );

            // try approve
            await testContract.connect(addr2).approveInvestors(1);

            // test Claim
            console.log("Test Claim")
            // claim before deposit and mark claimable
            await expect(testContract.connect(addr1).claim(1)).to.revertedWith("Claim is not available at this time.");

            // deposit

            await test_mint(tokenContract, addr1, "1000");
            console.log("Balance 1: ", utils.formatEther(await tokenContract.balanceOf(addr1.address)));
            //test_balance(tokenContract, addr1, "1000.0");

            // Not update tokenAddress, revert
            await expect(testContract.connect(addr1).deposit(1, utils.parseEther("90.0"))).to.revertedWith("Token not set");

            // Now update token address using approval 
            // function requestChangePoolData(uint64 _poolIdx, uint256 _allocationBusd, uint256 _endDate, address _tokenAddress)
            await testContract.connect(addr1).requestChangePoolData(1, 0, 0, tokenAddress);

            // now need approve from 2 approvers: owner & addr2
            await testContract.connect(owner).approveRequestChange();
            // not change
            expect((await testContract.getPool(1)).tokenAddress).to.equal(address0);
            await testContract.connect(addr2).approveRequestChange();

            // now the token updated
            expect((await testContract.getPool(1)).tokenAddress).to.equal(tokenAddress);
            // Deposit again
            testContract.connect(addr1).deposit(1, utils.parseEther("90.0"));

            // make it claimable
            await testContract.connect(addr1).setClaimable(true);
            
            await expect(testContract.connect(addr2).claim(1)).to.revertedWith("Nothing to claim");
            // make payment
            await test_mint(bUSDContract, addr2, "1000");
            await expect(testContract.connect(addr1).makePayment(1)).to.revertedWith("Not Ready for payment");
            
            // set WITHDRAW_ADDRESS
            await testContract.connect(addr1).requestChangeWithdrawAddress(owner.address);
            // check address
            await testContract.connect(owner).approveRequestChange();
            expect(await testContract.connect(addr1).getWithdrawAddress()).to.equal(address0);

            await expect(testContract.connect(owner).approveRequestChange()).to.revertedWith("Approve already");


            await testContract.connect(addr2).approveRequestChange();
            expect(await testContract.connect(addr1).getWithdrawAddress()).to.equal(owner.address);

            // let requestChangeData = await testContract.requestChangeData();
            // console.log("xx: ", requestChangeData);

            await testContract.connect(addr2).makePayment(1);
            await test_balance(bUSDContract, addr2, "700.0"); 


            // addr4 - claim empty
            await expect(testContract.connect(addr4).claim(1)).to.revertedWith("Nothing to claim");

            pool = await testContract.getPool(1);
            let investor = await testContract.getInvestor(1, addr2.address);
        
            // // claim for addr2
            // console.log("Claimable: ", utils.formatEther(await testContract.connect(addr2).getClaimable(1)));
            await testContract.connect(addr2).claim(1)
            await test_balance(tokenContract, addr2, "27.0");
            
            // claim already - revert
            await expect(testContract.connect(addr2).claim(1)).to.revertedWith("Nothing to claim");
            // not payment - claim also revert
            await expect(testContract.connect(addr1).claim(1)).to.revertedWith("Nothing to claim");

            // deposit more, then claim again (total 30%)
            await testContract.connect(addr1).deposit(1, utils.parseEther("180.0"));

            // claim for addr2 => 81
            await testContract.connect(addr2).claim(1)
            await test_balance(tokenContract, addr2, "81.0");

            // // claim for add3 => 45 * 3 = 
            // await testContract.connect(addr3).claim(1)
            // await test_balance(tokenContract, addr3, "135.0");

        })


    });
});