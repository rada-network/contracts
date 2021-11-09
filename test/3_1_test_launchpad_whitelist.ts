import {expect} from "chai";
// @ts-ignore
import {ethers} from "hardhat"

describe("Whitelist", async function () {

    let whitelist : any;
    beforeEach('',async function () {
        const whitelistContractFactory = await ethers.getContractFactory("Whitelist")
        whitelist = await whitelistContractFactory.deploy(true);
    })

    it('Add / Get / Remove whitelist', async function () {
        let allWhiteListed = await whitelist.getWhitelistedAddresses();
        expect(allWhiteListed.length).to.equal(0);

        await whitelist.add(['0x87E3E0e2C4bB722F6Ae421F4e90DCe801070C411', '0x159891a3bE000d23160dD976e77CbA671a409602']);
        allWhiteListed = await whitelist.getWhitelistedAddresses();
        expect(allWhiteListed[0]).to.equal("0x87E3E0e2C4bB722F6Ae421F4e90DCe801070C411");
        expect(allWhiteListed[1]).to.equal("0x159891a3bE000d23160dD976e77CbA671a409602");

        await whitelist.remove('0x87E3E0e2C4bB722F6Ae421F4e90DCe801070C411',0);
        allWhiteListed = await whitelist.getWhitelistedAddresses();
        expect(allWhiteListed[1]).to.equal("0x159891a3bE000d23160dD976e77CbA671a409602");
    })

})