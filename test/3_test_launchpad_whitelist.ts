import {ethers} from "hardhat"

describe("Whitelist", async function () {

    const whitelistContractFactory = new ethers.getContractFactory("Whitelist")
    const whitelist = await whitelistContractFactory.deploy("true");
    it('Them dia chi vao whitelist', async function () {
        await whitelist.add(['0x87E3E0e2C4bB722F6Ae421F4e90DCe801070C411', '0x159891a3bE000d23160dD976e77CbA671a409602']);
        const whitelists = await whitelist.getWhitelistedAddresses();
        console.log(whitelists);
    });

}