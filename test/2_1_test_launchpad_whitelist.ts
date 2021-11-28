import {expect} from "chai";
// @ts-ignore
import {ethers, upgrades} from "hardhat"
import {Contract, utils} from "ethers";

describe("Whitelist", async function () {
return;
    let launchPadContract: Contract;
    let tokenContract: Contract;
    let bUSDContract: Contract;
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
        console.log('BUSD: ', busdAddress);

        // Token project
        const tokenContractFactory = await ethers.getContractFactory("ERC20Token");
        tokenContract = await tokenContractFactory.deploy("TOKEN", "TOKEN");
        tokenContract = await tokenContract.deployed();
        const tokenAddress = tokenContract.address;
        console.log('Token Project: ', tokenAddress);

        const startDate = Math.floor(Date.now() / 1000);
        const endDate = Math.floor((Date.now() + 7 * 24 * 60 * 60 * 1000) / 1000);

        const launchPadFactory = await ethers.getContractFactory("WhiteListPad");
        const paramLaunchpad = {
            _tokenAddress: tokenAddress,
            _bUSDAddress: busdAddress,
            _rirAddress: "0x0000000000000000000000000000000000000000",
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
        console.log('LaunchPad Contract: ', launchPadAddress);


    });

    it('Add / Get / Remove whitelist', async function () {
        let allWhiteListed = await launchPadContract.getWhitelistedAddresses();
        expect(allWhiteListed.length).to.equal(0);

        await launchPadContract.add(['0x87E3E0e2C4bB722F6Ae421F4e90DCe801070C411', '0x159891a3bE000d23160dD976e77CbA671a409602']);
        allWhiteListed = await launchPadContract.getWhitelistedAddresses();
        expect(allWhiteListed[0]).to.equal("0x87E3E0e2C4bB722F6Ae421F4e90DCe801070C411");
        expect(allWhiteListed[1]).to.equal("0x159891a3bE000d23160dD976e77CbA671a409602");

        await launchPadContract.remove('0x87E3E0e2C4bB722F6Ae421F4e90DCe801070C411',0);
        allWhiteListed = await launchPadContract.getWhitelistedAddresses();
        expect(allWhiteListed[1]).to.equal("0x159891a3bE000d23160dD976e77CbA671a409602");
    })

})