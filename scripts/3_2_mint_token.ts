// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// @ts-ignore
import {ethers} from "hardhat";
import {utils} from "ethers";

async function main() {
    // Token Busd
    let accounts = await ethers.provider.listAccounts();
    const busdContracts = await ethers.getContractFactory("ERC20Token");
    const busdAddress = "0x6945239350AE805b0823cB292a4dA5974d166640"
    console.log("busdContracts : ", busdAddress)
    const busd = busdContracts.attach(
      busdAddress
    );
    await busd.mint(accounts[0],utils.parseEther("1000000"))

    const rirContract = await ethers.getContractFactory("ERC20Token");
    const rirAddress = "0x6768BDC5d03A87942cE7cB143fA74e0DadE0371b"
    console.log("rirAddress : ", rirAddress)
    const rir = rirContract.attach(
      rirAddress
    );
    await rir.mint(accounts[0],utils.parseEther("1000000"))

    const tokenContact = await ethers.getContractFactory("ERC20Token");
    const tokenAddress = "0xbaDB6b73c2FBE647a256Cf8F965f89573A054113"
    console.log("tokenAddress : ", tokenAddress)
    const token = tokenContact.attach(
      tokenAddress
    );
    await token.mint(accounts[0],utils.parseEther("10000000"))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
