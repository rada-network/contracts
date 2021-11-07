const { expect } = require('chai')
const { BigNumber } = require('ethers')
// @ts-ignore
import {ethers, upgrades} from "hardhat"

describe("FixedSwap", function () {

    const _tradeValue = BigNumber.from(1).div(100).mul(1000000000).mul(1000000000).toString(); // Gia tuong duong voi BNB
    const _tokensForSale = BigNumber.from(2500000).mul(1000000000).mul(1000000000).toString();
    const _startDate = '1622505600' // https://www.epochconverter.com/
    const _endDate = '1667260800' // https://www.epochconverter.com/
    const _individualMinimumAmount = '0'
    const _individualMaximumAmount = BigNumber.from(2500000).mul(1000000000).mul(1000000000).toString();
    const _isTokenSwapAtomic = false
    const _minimumRaise = BigNumber.from(1000000).mul(1000000000).mul(1000000000).toString();
    const _feeAmount = '1'
    const _hasWhitelisting = false
    let addressToken = ''

    it("Deploy Token", async function () {
        const RIRContract = await ethers.getContractFactory("RIRContract");
        const accounts = await ethers.provider.listAccounts()
        console.log("Deploying token...");
        // Init Token
        const token = await upgrades.deployProxy(RIRContract, ["RIR Token", "RIR"], { unsafeAllowCustomTypes: true });
        addressToken = token.address;
        console.log("Token deployed to:", addressToken);
        console.log("Symbol: ", await token.symbol());
        expect(await token.name()).to.equal("RIR Token");
        expect(await token.symbol()).to.equal("RIR");

        // Mint
        const tokenNumber = BigNumber.from(100000000000).mul(1000000000).mul(1000000000)._hex;
        await token.mint(accounts[0], tokenNumber)
        expect(await token.balanceOf(accounts[0])).to.equal('100000000000000000000000000000')
        // Decimals
        const tokenDecimals = await token.decimals();
        console.log("Decimals: ", tokenDecimals);
        expect(tokenDecimals).to.equal(18)

        // Total Supply
        const tokenTotalSupply = await token.totalSupply();
        console.log("Total Supply: ", tokenTotalSupply.toString());
        expect(tokenTotalSupply.toString()).to.equal('100000000000000000000000000000')
    });

    it("Deploy FixedSwap With Address Token", async function () {
        const fixedSwapContract = await ethers.getContractFactory('FixedSwap')

        const fixedSwap = await fixedSwapContract.deploy(addressToken.toString(),
            _tradeValue,
            _tokensForSale,
            _startDate,
            _endDate,
            _individualMinimumAmount,
            _individualMaximumAmount,
            _isTokenSwapAtomic,
            _minimumRaise,
            _feeAmount,
            _hasWhitelisting);
        console.log("Token deployed to:", fixedSwap.address);

        expect(await fixedSwap.isOpen()).to.equal(true)
    })

});
