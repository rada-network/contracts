import {expect} from "chai";
import {BigNumber} from "ethers";
import {ethers, upgrades} from "hardhat"

describe("Deploy", function () {
return;
    // @ts-ignore
    it("Deploy Token", async () => {
        const RIRContract = await ethers.getContractFactory("RIRContract");
        let accounts = await ethers.provider.listAccounts();
        console.log("Deploying token...");

        // Init Token
        const token = await upgrades.deployProxy(RIRContract, ["RIR Token", "RIR"], {unsafeAllowCustomTypes: true});
        console.log("Token deployed to:", token.address);
        console.log("Symbol: ", await token.symbol());
        expect(await token.name()).to.equal("RIR Token");
        expect(await token.symbol()).to.equal("RIR");

        // Mint
        const tokenNumber = BigNumber.from('100000000000000000000000000000').toHexString();
        await token.mint(accounts[0], tokenNumber);
        expect(await token.balanceOf(accounts[0])).to.equal('100000000000000000000000000000');

        // Decimals
        const tokenDecimals = await token.decimals();
        console.log("Decimals: ", tokenDecimals);
        expect(tokenDecimals).to.equal(18);

        // Total Supply
        const tokenTotalSupply = await token.totalSupply();
        console.log("Total Supply: ", tokenTotalSupply.toString());
        expect(tokenTotalSupply.toString()).to.equal('100000000000000000000000000000')
    });

});