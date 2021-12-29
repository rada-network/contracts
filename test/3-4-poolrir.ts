// @ts-ignore
import { ethers, upgrades } from "hardhat"
import { constants, Contract, utils, BigNumberish, BigNumber } from "ethers"
import { expect, use, util } from 'chai';
import { solidity } from 'ethereum-waffle';
import { Address } from "cluster";

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



    it ("Test Payments", async () => {
        await addPool();

        await expect(testContract.connect(addr1).makePayment(PoolIndex, pe("300"), pe("0"))).to.revertedWith("Not Ready"); // Investor not approved

        await testContract.connect(addr2).lockPool(PoolIndex);

        // payment before locked
        await expect(testContract.connect(addr1).makePayment(PoolIndex, pe("0"), pe("0"))).to.revertedWith("Invalid Amount"); // revert invalid amounts
        await expect(testContract.connect(addr1).makePayment(PoolIndex, pe("50"), pe("0"))).to.revertedWith("Under Minimum"); // revert - Exceeds min
        await expect(testContract.connect(addr1).makePayment(PoolIndex, pe("500"), pe("0"))).to.revertedWith("Over Maximum"); // revert - Exceeds  ax

        await test_mint(bUSDContract, addr1, "100");
        await expect(testContract.connect(addr1).makePayment(PoolIndex, pe("100"), pe("1"))).to.revertedWith("Not enough Token"); // revert - not enough rir
        await test_mint(rirContract, addr1, "10");
        await expect(testContract.connect(addr1).makePayment(PoolIndex, pe("200"), pe("1"))).to.revertedWith("Not enough Token"); // revert - not enough busd

        await test_mint(bUSDContract, addr1, "900");
        await testContract.connect(addr1).makePayment(PoolIndex, pe("200"), pe("1")); 
        await test_balance(bUSDContract, addr1, "800.0");
        await test_balance(rirContract, addr1, "9.0");
        // and more
        await testContract.connect(addr1).makePayment(PoolIndex, pe("0"), pe("1"));  // more rir only
        await test_balance(bUSDContract, addr1, "800.0");
        await test_balance(rirContract, addr1, "8.0");
        await testContract.connect(addr1).makePayment(PoolIndex, pe("100"), pe("1"));  // more to max
        await test_balance(bUSDContract, addr1, "700.0");
        await test_balance(rirContract, addr1, "7.0");

        await test_mint(bUSDContract, addrs[2], "1000");
        await test_mint(rirContract, addrs[2], "10");
        await testContract.connect(addrs[2]).makePayment(PoolIndex, pe("100"), pe("1"));  // more to max
        await test_mint(bUSDContract, addrs[3], "1000");
        await test_mint(rirContract, addrs[3], "10");
        await testContract.connect(addrs[3]).makePayment(PoolIndex, pe("100"), pe("1"));  // more to max
        await test_mint(bUSDContract, addrs[4], "1000");
        await test_mint(rirContract, addrs[4], "10");
        await testContract.connect(addrs[4]).makePayment(PoolIndex, pe("100"), pe("1"));  // more to max
        // over rir allocation
        await test_mint(bUSDContract, addrs[5], "1000");
        await test_mint(rirContract, addrs[5], "10");
        await expect(testContract.connect(addrs[5]).makePayment(PoolIndex, pe("100"), pe("1"))).to.revertedWith("Exceeds RIR Allocation");  // Revert - rir eceed allocation

    });


    it ("Import Winner & Approve Investors", async () => {
        await addPool();
        await testContract.connect(addr2).lockPool(PoolIndex);

        await test_mint(bUSDContract, addrs[1], "1000");
        await test_mint(rirContract, addrs[1], "10");
        await testContract.connect(addrs[1]).makePayment(PoolIndex, pe("300"), pe("3"));  // more to max
        await test_mint(bUSDContract, addrs[2], "1000");
        await test_mint(rirContract, addrs[2], "10");
        await testContract.connect(addrs[2]).makePayment(PoolIndex, pe("100"), pe("1"));  // more to max
        await test_mint(bUSDContract, addrs[3], "1000");
        await test_mint(rirContract, addrs[3], "10");
        await testContract.connect(addrs[3]).makePayment(PoolIndex, pe("100"), pe("0"));  // more to max
        await test_mint(bUSDContract, addrs[4], "1000");
        await test_mint(rirContract, addrs[4], "10");
        await testContract.connect(addrs[4]).makePayment(PoolIndex, pe("200"), pe("1"));  // more to max        
        await test_mint(bUSDContract, addrs[5], "1000");
        await test_mint(rirContract, addrs[5], "10");
        await testContract.connect(addrs[5]).makePayment(PoolIndex, pe("300"), pe("3"));  // more to max        
        await test_mint(bUSDContract, addrs[6], "1000");
        await test_mint(rirContract, addrs[6], "10");
        await testContract.connect(addrs[6]).makePayment(PoolIndex, pe("300"), pe("0"));  // more to max        

        // now approve Investor - Revert with Not import winner list
        await expect(testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 0, 6)).to.revertedWith("91");
        
        // import winners
/*
    function importWinners(
        uint64 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _allocationBusds,
        uint256[] memory _allocationRirs
    )
*/
        await expect(testContract.connect(addr1).importWinners(
            PoolIndex,
            [addrs[1].address, addrs[2].address, addrs[3].address, addrs[4].address, addrs[5].address, addrs[6].address],
            [pe("300"), pe("300"), pe("300"), pe("300"), pe("300"), pe("300")],
            [pe("0"), pe("0"), pe("0"), pe("0"), pe("0"), pe("0")]
        )).to.revertedWith("88"); // approve more than prefund (addrs[2])
        await expect(testContract.connect(addr1).importWinners(
            PoolIndex,
            [addrs[1].address, addrs[2].address, addrs[3].address, addrs[4].address, addrs[5].address, addrs[6].address],
            [pe("200"), pe("300"), pe("300"), pe("300"), pe("300"), pe("300")],
            [pe("3"), pe("0"), pe("0"), pe("0"), pe("0"), pe("0")]
        )).to.revertedWith("88"); // approve more rir than busd (addrs[2])

        await testContract.connect(addr1).importWinners(
            PoolIndex,
            [addrs[1].address, addrs[2].address, addrs[3].address, addrs[4].address, addrs[5].address, addrs[6].address],
            [pe("200"), pe("100"), pe("100"), pe("200"), pe("200"), pe("200")],
            [pe("2"), pe("0"), pe("0"), pe("0"), pe("0"), pe("0")]
        ); // approve more rir than busd (addrs[2])
        // approve fail
        await expect(testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 0, 6)).to.revertedWith("91"); // not all rir prefund are approved

        await testContract.connect(addr1).importWinners(
            PoolIndex,
            [addrs[1].address, addrs[2].address, addrs[3].address, addrs[4].address, addrs[5].address, addrs[6].address],
            [pe("300"), pe("100"), pe("100"), pe("200"), pe("200"), pe("200")],
            [pe("1"), pe("1"), pe("0"), pe("1"), pe("1"), pe("0")]
        ); // approve more rir than busd (addrs[2])
        await expect(testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 0, 6)).to.revertedWith("92"); // more rir than allow

        await testContract.connect(addr1).importWinners(
            PoolIndex,
            [addrs[1].address, addrs[2].address, addrs[3].address, addrs[4].address, addrs[5].address, addrs[6].address],
            [pe("200"), pe("100"), pe("100"), pe("200"), pe("200"), pe("200")],
            [pe("2"), pe("1"), pe("0"), pe("1"), pe("1"), pe("0")]
        ); // approve more rir than busd (addrs[2])
        await expect(testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 0, 6)).to.revertedWith("93"); // more rir than allow

        await testContract.connect(addr1).importWinners(
            PoolIndex,
            [addrs[1].address, addrs[2].address, addrs[3].address, addrs[4].address, addrs[5].address, addrs[6].address],
            [pe("200"), pe("100"), pe("100"), pe("200"), 100, pe("200")],
            [pe("1"), pe("1"), pe("0"), pe("1"), 1, pe("0")]
        ); // approve more rir than busd (addrs[2])


        // try approve
        await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 0, 2);
        await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 2, 2);
        await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 4, 2);
        
    })    


    it ("Test Deposit", async () => {
        await addPool();
        await testContract.connect(addr2).lockPool(PoolIndex);

        await test_mint(bUSDContract, addrs[1], "1000");
        await test_mint(rirContract, addrs[1], "10");
        await testContract.connect(addrs[1]).makePayment(PoolIndex, pe("300"), pe("3"));  // more to max
        await test_mint(bUSDContract, addrs[2], "1000");
        await test_mint(rirContract, addrs[2], "10");
        await testContract.connect(addrs[2]).makePayment(PoolIndex, pe("100"), pe("1"));  // more to max
        await test_mint(bUSDContract, addrs[3], "1000");
        await test_mint(rirContract, addrs[3], "10");
        await testContract.connect(addrs[3]).makePayment(PoolIndex, pe("100"), pe("0"));  // more to max
        await test_mint(bUSDContract, addrs[4], "1000");
        await test_mint(rirContract, addrs[4], "10");
        await testContract.connect(addrs[4]).makePayment(PoolIndex, pe("200"), pe("1"));  // more to max        
        await test_mint(bUSDContract, addrs[5], "1000");
        await test_mint(rirContract, addrs[5], "10");
        await testContract.connect(addrs[5]).makePayment(PoolIndex, pe("300"), pe("3"));  // more to max        
        await test_mint(bUSDContract, addrs[6], "1000");
        await test_mint(rirContract, addrs[6], "10");
        await testContract.connect(addrs[6]).makePayment(PoolIndex, pe("300"), pe("0"));  // more to max        

        await testContract.connect(addr1).importWinners(
            PoolIndex,
            [addrs[1].address, addrs[2].address, addrs[3].address, addrs[4].address, addrs[5].address, addrs[6].address],
            [pe("200"), pe("100"), pe("100"), pe("200"), pe("200"), pe("200")],
            [pe("1"), pe("1"), pe("0"), pe("1"), pe("1"), pe("0")]
        ); // approve more rir than busd (addrs[2])

        // try approve
        await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 0, 2);
        await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 2, 2);
        await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 4, 2);

        // deposit before setup token
        let _amountToken = await testContract.getDepositAmountBusd(PoolIndex, 10); // get 10% amount depsoti token 
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
        _amountToken = await testContract.getDepositAmountBusd(PoolIndex, 90); // get 90% amount depsoti token 
        expect(fe(_amountToken)).to.equal("810.0");
        await expect(testContract.connect(addr1).deposit(PoolIndex, _amountToken + 1)).to.revertedWith("40");
        // deposit full
        await testContract.connect(addr1).deposit(PoolIndex, _amountToken);
        await test_balance(tokenContract, testContract, "900.0"); // equal input
    });


    it ("Test Claim", async () => {
        await addPool();
        await testContract.connect(addr2).lockPool(PoolIndex);

        await test_mint(bUSDContract, addrs[1], "1000");
        await test_mint(rirContract, addrs[1], "10");
        await testContract.connect(addrs[1]).makePayment(PoolIndex, pe("300"), pe("3"));  // more to max
        await test_mint(bUSDContract, addrs[2], "1000");
        await test_mint(rirContract, addrs[2], "10");
        await testContract.connect(addrs[2]).makePayment(PoolIndex, pe("100"), pe("1"));  // more to max
        await test_mint(bUSDContract, addrs[3], "1000");
        await test_mint(rirContract, addrs[3], "10");
        await testContract.connect(addrs[3]).makePayment(PoolIndex, pe("100"), pe("0"));  // more to max
        await test_mint(bUSDContract, addrs[4], "1000");
        await test_mint(rirContract, addrs[4], "10");
        await testContract.connect(addrs[4]).makePayment(PoolIndex, pe("200"), pe("1"));  // more to max        
        await test_mint(bUSDContract, addrs[5], "1000");
        await test_mint(rirContract, addrs[5], "10");
        await testContract.connect(addrs[5]).makePayment(PoolIndex, pe("300"), pe("3"));  // more to max        
        await test_mint(bUSDContract, addrs[6], "1000");
        await test_mint(rirContract, addrs[6], "10");
        await testContract.connect(addrs[6]).makePayment(PoolIndex, pe("300"), pe("0"));  // more to max        

        await testContract.connect(addr1).importWinners(
            PoolIndex,
            [addrs[1].address, addrs[2].address, addrs[3].address, addrs[4].address, addrs[5].address, addrs[6].address],
            [pe("200"), pe("100"), pe("100"), pe("200"), 100, pe("200")],
            [pe("1"), pe("1"), pe("0"), pe("1"), 1, pe("0")]
        ); // approve more rir than busd (addrs[2])

        // try approve
        await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 0, 4);
        await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 2, 4);
        //await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 4, 6);

        // deposit
        await setTokenAddress();
        await test_mint(tokenContract, addr1, "1000");
        let _amountToken = await testContract.getDepositAmountBusd(PoolIndex, 10); // get 10% amount depsoti token 
        await testContract.connect(addr1).deposit(PoolIndex, _amountToken);

        // enable claimable
        await testContract.connect(addr2).setClaimable(true);

        // claim
        await testContract.connect(addr2).claim(PoolIndex);
        await test_balance(tokenContract, addr2, "9.0"); // 10%, after fee
        await test_balance(bUSDContract, addr2, "900.0"); // no refund

        // claim agian
        await testContract.connect(addr2).claim(PoolIndex);
        await test_balance(tokenContract, addr2, "9.0"); // 10%, after fee
        await test_balance(bUSDContract, addr2, "900.0"); // no refund

        // deposit more
        _amountToken = await testContract.getDepositAmountBusd(PoolIndex, 20); // get 20% amount depsoti token 
        await testContract.connect(addr1).deposit(PoolIndex, _amountToken);

        // claim agian
        await testContract.connect(addr2).claim(PoolIndex);
        await test_balance(tokenContract, addr2, "27.0"); // 10%

        // Investor 1: refunded, claim only token
        await testContract.connect(addr4).claim(PoolIndex);
        await test_balance(tokenContract, addr4, "54.0"); // 10%, after fee
        await test_balance(bUSDContract, addr4, "800.0"); // no refund

        let clab = await testContract.connect(addrs[5]).getClaimable(PoolIndex);
        expect(clab).to.equal(0);
        let [rfbusd, rfrir] = await testContract.connect(addrs[5]).getRefundable(PoolIndex);
        expect(fe(rfbusd)).to.equal("300.0");
        expect(fe(rfrir)).to.equal("3.0");


    });


    it ("Test Withdraw Fund", async () => {
        await addPool();
        await testContract.connect(addr2).lockPool(PoolIndex);

        await test_mint(bUSDContract, addrs[1], "1000");
        await test_mint(rirContract, addrs[1], "10");
        await testContract.connect(addrs[1]).makePayment(PoolIndex, pe("300"), pe("3"));  // more to max
        await test_mint(bUSDContract, addrs[2], "1000");
        await test_mint(rirContract, addrs[2], "10");
        await testContract.connect(addrs[2]).makePayment(PoolIndex, pe("100"), pe("1"));  // more to max
        await test_mint(bUSDContract, addrs[3], "1000");
        await test_mint(rirContract, addrs[3], "10");
        await testContract.connect(addrs[3]).makePayment(PoolIndex, pe("100"), pe("0"));  // more to max
        await test_mint(bUSDContract, addrs[4], "1000");
        await test_mint(rirContract, addrs[4], "10");
        await testContract.connect(addrs[4]).makePayment(PoolIndex, pe("200"), pe("1"));  // more to max        
        await test_mint(bUSDContract, addrs[5], "1000");
        await test_mint(rirContract, addrs[5], "10");
        await testContract.connect(addrs[5]).makePayment(PoolIndex, pe("300"), pe("3"));  // more to max        
        await test_mint(bUSDContract, addrs[6], "1000");
        await test_mint(rirContract, addrs[6], "10");
        await testContract.connect(addrs[6]).makePayment(PoolIndex, pe("300"), pe("0"));  // more to max        

        await testContract.connect(addr1).importWinners(
            PoolIndex,
            [addrs[1].address, addrs[2].address, addrs[3].address, addrs[4].address, addrs[5].address, addrs[6].address],
            [pe("200"), pe("100"), pe("100"), pe("200"), pe("200"), pe("200")],
            [pe("1"), pe("1"), pe("0"), pe("1"), pe("1"), pe("0")]
        ); // approve more rir than busd (addrs[2])

        // try approve
        await testContract.connect(addr2).approveInvestorsByBatch(PoolIndex, 0, 6);

        await expect(testContract.connect(addr2).withdrawBusdFunds(PoolIndex)).to.revertedWith("112");
        await setWithdrawAddress();
        await testContract.connect(addr2).withdrawBusdFunds(PoolIndex);
        await test_balance(bUSDContract, owner, "1000.0"); // withdraw successful
        await test_balance(rirContract, testContract, "4.0"); // burn RIR already

        // withdraw already
        await expect(testContract.connect(addr2).withdrawBusdFunds(PoolIndex)).to.revertedWith("110");

        expect((await testContract.poolsStat(PoolIndex)).approvedCount).to.equal(6);
        console.log(await testContract.getAddresses(PoolIndex, 2, 3));
        console.log(await testContract.getApprovedAddresses(PoolIndex, 1, 4));
    });    
});