// @ts-ignore
import { ethers, upgrades } from "hardhat"
import { constants, Contract, utils, BigNumberish, BigNumber } from "ethers"
import { expect, use, util } from 'chai';
import { solidity } from 'ethereum-waffle';
import { Address } from "cluster";
import exp from "constants";

use(solidity);

describe("Claimonly", async function () {
    
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

        const launchPadFactory = await ethers.getContractFactory("PoolClaim");

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


    describe("ClaimOnly Pool", async function () {
        it ("Check admin & approver", async () => {
            expect (await testContract.admins(addr1.address)).to.equal(true);
            expect (await testContract.admins(addr2.address)).to.equal(false);
            expect (await testContract.approvers(addr1.address)).to.equal(false);
            expect (await testContract.approvers(addr2.address)).to.equal(true);
        })

        it ("Add a Pool", async () => {
            // create new pool
            console.log("Add Pool");
            await testContract.addPool(
                "tk1",
                tokenAddress,
                utils.parseEther("1000"),
                utils.parseEther("1")
            );
            await testContract.addPool(
                "elemon",
                tokenAddress,
                utils.parseEther("900"),
                utils.parseEther("1")
            );

            expect (await testContract.poolCount()).to.equal(2);
            let pool = await testContract.getPool(1);
            expect(pool.title).to.equal("elemon");
            expect(utils.formatEther(pool.allocationBusd)).to.equal("900.0");
            expect(utils.formatEther(pool.price)).to.equal("1.0");


            // Total allocation: 900
            console.log("Import Investor");
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
            await expect(testContract.connect(addr1).approveInvestors(1)).to.revertedWith("Caller is not an approver");
            await expect(testContract.connect(addr2).approveInvestors(1)).to.revertedWith("Pool not locked");

            // lock pool
            await expect(testContract.connect(addr1).lockPool(1)).to.revertedWith("Caller is not an approver");
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

            await testContract.connect(addr1).deposit(1, utils.parseEther("90.0"));

            // make it claimable
            await testContract.connect(addr1).setClaimable(true);
            
            // addr4 - claim empty
            await expect(testContract.connect(addr4).claim(1)).to.revertedWith("Nothing to claim");

            pool = await testContract.getPool(1);
            let investor = await testContract.getInvestor(1, addr2.address);
        
            // // claim for addr2
            // console.log("Claimable: ", utils.formatEther(await testContract.connect(addr2).getClaimable(1)));
            await testContract.connect(addr2).claim(1)
            await test_balance(tokenContract, addr2, "27.0");
            
            // claim again - revert
            await expect(testContract.connect(addr2).claim(1)).to.revertedWith("Nothing to claim");

            // deposit more, then claim again (total 30%)
            await testContract.connect(addr1).deposit(1, utils.parseEther("180.0"));

            // claim for addr2 => 81
            await testContract.connect(addr2).claim(1)
            await test_balance(tokenContract, addr2, "81.0");

            // claim for add3 => 45 * 3 = 
            await testContract.connect(addr3).claim(1)
            await test_balance(tokenContract, addr3, "135.0");

        })


    });    

});