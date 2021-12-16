// @ts-ignore
import { ethers, upgrades } from "hardhat"
import { constants, Contract, utils, BigNumberish, BigNumber } from "ethers"
import { expect, use, util } from 'chai';
import { solidity } from 'ethereum-waffle';
import { Address } from "cluster";
import exp from "constants";

use(solidity);

describe("ClaimOnly", async function () {

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

    const pe = (num: string) => utils.parseEther(num) // parseEther
    const fe = (num: number) => utils.formatEther(num) // formatEther

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


    let PoolIndex = 0;

    const addPool = async () => {
        await testContract.addPool(
            "elemon-whitelist",
            utils.parseEther("1000"), // allocation
            utils.parseEther("100"),  // min
            utils.parseEther("300"),  // max
            pe("4"),                  // rir allocation
            utils.parseEther("1"),    // price
            Math.floor(Date.now() / 1000),  // start date
            Math.floor((Date.now() + 7 * 24 * 60 * 60 * 1000) / 1000),   //end date,
            10 // fee
        );
    }

    const importInvestors = async() => {
        await testContract.importInvestors(
            PoolIndex,
            [addr1.address, addr2.address, addr3.address, addr4.address],
            [pe("200"), pe("300"), pe("600"), pe("400")],
            [pe("200.0"), pe("300.0"), pe("300.0"), pe("200.0")],
            [0, 0, 0, 0],
            [true, true, true, false] // refunded
        );
    }

    const setWithdrawAddress = async() => {
        await testContract.connect(addr1).requestChangeWithdrawAddress(owner.address);
        await testContract.connect(owner).approveRequestChange();
        await testContract.connect(addr2).approveRequestChange();
    }

    const setTokenAddress = async() => {
        await testContract.connect(addr1).requestChangePoolData(PoolIndex, 0, 0, tokenAddress);
        await testContract.connect(owner).approveRequestChange();
        await testContract.connect(addr2).approveRequestChange();
    }
    
    it ("Add a Pool", async () => {
        // create new pool
        await addPool();
        await addPool();

        expect (await testContract.poolCount()).to.equal(2);
        let pool = await testContract.pools(1);
        expect(pool.title).to.equal("elemon-whitelist");
        expect(utils.formatEther(pool.allocationBusd)).to.equal("1000.0");
        expect(utils.formatEther(pool.price)).to.equal("1.0");

        // call update pool when not lock
        await testContract.connect(addr1).updatePool(PoolIndex, pe("2000"), pe("0.1"), 0, 0);
        pool = await testContract.pools(PoolIndex);
        expect(utils.formatEther(pool.allocationBusd)).to.equal("2000.0");
        expect(utils.formatEther(pool.price)).to.equal("0.1");

        // require lock pool before using requestChange
        await expect(testContract.connect(addr1).requestChangePoolData(PoolIndex, 0, 0, tokenAddress)).to.revertedWith("17"); // pool not locked

        // lock
        await testContract.connect(addr2).lockPool(PoolIndex);
        // cannot call update
        await expect(testContract.connect(addr1).updatePool(PoolIndex, pe("2000"), pe("0.1"), 0, 0)).to.revertedWith("22");
    })

    it ("Import Investors", async () => {
        await addPool();
        // Total allocation: 900
        await importInvestors();

        const investor1 = await testContract.getInvestor(PoolIndex, addr1.address);
        const investor2 = await testContract.getInvestor(PoolIndex, addr2.address);
        expect(utils.formatEther(investor1.amountBusd)).to.equal("200.0");
        expect(utils.formatEther(investor1.allocationBusd)).to.equal("200.0");
        expect(utils.formatEther(investor2.amountBusd)).to.equal("300.0");
        expect(utils.formatEther(investor2.allocationBusd)).to.equal("300.0");

    })


    it ("Approve Investors", async () => {
        await addPool();
        // Total allocation: 900
        await importInvestors();        

        // try to approve Investor before lock pool
        await expect(testContract.connect(addr1).approveInvestors(PoolIndex)).to.revertedWith("3");
        await expect(testContract.connect(addr2).approveInvestors(PoolIndex)).to.revertedWith("34");

        // lock pool
        await expect(testContract.connect(addr1).lockPool(PoolIndex)).to.revertedWith("3");
        await testContract.connect(addr2).lockPool(PoolIndex);
        expect((await testContract.pools(PoolIndex)).locked).to.equal(true);

        // update Investor to reduce allocation
        await testContract.importInvestors(
            PoolIndex,
            [addr4.address],
            [utils.parseEther("400.0")],
            [utils.parseEther("360.0")],
            [0],
            [false]
        );

        // now approve Investor - Revert with Eceeds total allocation
        await expect(testContract.connect(addr2).approveInvestors(PoolIndex)).to.revertedWith("36");

        // update Investor to reduce allocation
        await testContract.importInvestors(
            PoolIndex,
            [addr4.address],
            [utils.parseEther("400.0")],
            [utils.parseEther("100.0")],
            [0],
            [false]
        );

        // try approve
        await testContract.connect(addr2).approveInvestors(PoolIndex);
    })

    it ("Set Withdraw Address", async () => {
        await addPool();

        // set WITHDRAW_ADDRESS
        await testContract.connect(addr1).requestChangeWithdrawAddress(owner.address);
        // check address
        await testContract.connect(owner).approveRequestChange();
        expect(await testContract.connect(addr1).getWithdrawAddress()).to.equal(address0);

        // approve already
        await expect(testContract.connect(owner).approveRequestChange()).to.revertedWith("11");

        await testContract.connect(addr2).approveRequestChange();
        expect(await testContract.connect(addr1).getWithdrawAddress()).to.equal(owner.address);
    });

    it ("Set Token Address", async () => {
        await addPool();
        
        await testContract.connect(addr2).lockPool(PoolIndex);
        await testContract.connect(addr1).requestChangePoolData(PoolIndex, 0, 0, tokenAddress);

        // now need approve from 2 approvers: owner & addr2
        await testContract.connect(owner).approveRequestChange();
        // not change
        expect((await testContract.pools(PoolIndex)).tokenAddress).to.equal(address0);
        await testContract.connect(addr2).approveRequestChange();

        // now the token updated
        expect((await testContract.pools(PoolIndex)).tokenAddress).to.equal(tokenAddress);
    });


    it ("Test Deposit", async () => {
        await addPool();
        await testContract.connect(addr2).lockPool(PoolIndex);
        // Total allocation: 900
        await importInvestors();
        await testContract.connect(addr2).approveInvestors(PoolIndex);
        await setWithdrawAddress();

        // deposit before setup token
        let _amountToken = await testContract.getDepositAmount(PoolIndex, 10); // get 10% amount depsoti token 
        expect(fe(_amountToken)).to.equal("90.0");
        await expect(testContract.connect(addr1).deposit(PoolIndex, _amountToken)).to.revertedWith("39");

        // setup token address
        await setTokenAddress();
        // not enought token
        await expect(testContract.connect(addr1).deposit(PoolIndex, _amountToken)).to.revertedWith("41");

        await test_mint(tokenContract, addr1, "1000");
        await testContract.connect(addr1).deposit(PoolIndex, _amountToken);
        await test_balance(tokenContract, testContract, fe(_amountToken)); // equal input


        // deposit more than require
        _amountToken = await testContract.getDepositAmount(PoolIndex, 90); // get 10% amount depsoti token 
        expect(fe(_amountToken)).to.equal("810.0");
        await expect(testContract.connect(addr1).deposit(PoolIndex, _amountToken + 1)).to.revertedWith("40");
        // deposit full
        await testContract.connect(addr1).deposit(PoolIndex, _amountToken);
        await test_balance(tokenContract, testContract, "900.0"); // equal input
    });


    it ("Test Claim", async () => {
        await addPool();
        await testContract.connect(addr2).lockPool(PoolIndex);
        // Total allocation: 900
        await importInvestors();
        await testContract.connect(addr2).approveInvestors(PoolIndex);
        await setWithdrawAddress();

        // claim before enable
        await expect(testContract.connect(addr2).claim(PoolIndex)).to.revertedWith("Unclaimable");

        // enable claimable
        await testContract.connect(addr2).setClaimable(true);

        // claim before deposit - nothing happen
        await testContract.connect(addr2).claim(PoolIndex);
        await test_balance(tokenContract, addr2, "0.0"); // equal input

        // deposit
        await setTokenAddress();
        await test_mint(tokenContract, addr1, "1000");
        let _amountToken = await testContract.getDepositAmount(PoolIndex, 10); // get 10% amount depsoti token 
        await testContract.connect(addr1).deposit(PoolIndex, _amountToken);

        // claim
        await testContract.connect(addr2).claim(PoolIndex);
        await test_balance(tokenContract, addr2, "27.0"); // 10%, after fee
        await test_balance(bUSDContract, addr2, "0.0"); // no refund

        // claim agian
        await testContract.connect(addr2).claim(PoolIndex);
        await test_balance(tokenContract, addr2, "27.0"); // 10%

        // deposit more
        _amountToken = await testContract.getDepositAmount(PoolIndex, 20); // get 20% amount depsoti token 
        await testContract.connect(addr1).deposit(PoolIndex, _amountToken);

        // claim agian
        await testContract.connect(addr2).claim(PoolIndex);
        await test_balance(tokenContract, addr2, "81.0"); // 10%

        // Investor 3: refunded, claim only token
        await testContract.connect(addr3).claim(PoolIndex);
        await test_balance(tokenContract, addr3, "81.0"); // 10%, after fee
        await test_balance(bUSDContract, addr3, "0.0"); // no refund

        // Investor 4: refunded, claim With refund
        await expect(testContract.connect(addr4).claim(PoolIndex)).to.revertedWith("Not enough BUSD"); // not enough busd to refund
        // await test_mint(bUSDContract, testContract, "1000");
        await bUSDContract.mint(testContract.address, pe("1000"));
        await testContract.connect(addr4).claim(PoolIndex);
        await test_balance(tokenContract, addr4, "54.0"); // 30%, after fee
        await test_balance(bUSDContract, addr4, "200.0"); // prefund 400, approved 100
        // claim again
        await testContract.connect(addr4).claim(PoolIndex);
        await test_balance(tokenContract, addr4, "54.0"); // 30%, after fee
        await test_balance(bUSDContract, addr4, "200.0"); // prefund 400, approved 100

    });

});