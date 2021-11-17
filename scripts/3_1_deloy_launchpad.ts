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
    const busdAddress = "0x6945239350AE805b0823cB292a4dA5974d166640";
     console.log('BUSD: ', busdAddress);

    // Token project
    const tokenAddress = "0xbaDB6b73c2FBE647a256Cf8F965f89573A054113";
     console.log('Token Project: ', tokenAddress);

    // Token RIR
  
    const rirAddress = "0x6768BDC5d03A87942cE7cB143fA74e0DadE0371b";
    console.log('RIR Contract: ', rirAddress);

    const launchPadFactory = await ethers.getContractFactory("LaunchPad");
    let launchPadContract = await launchPadFactory.deploy(tokenAddress, busdAddress, rirAddress, utils.parseEther("0.01"),utils.parseEther("1000000"),utils.parseEther("100"),utils.parseEther("500"), true);
    
    launchPadContract = await launchPadContract.deployed();
    const launchPadAddress = launchPadContract.address;
     console.log('LaunchPad Contract: ', launchPadAddress);
     console.log("LaunchPad Contract param",tokenAddress, busdAddress, rirAddress, utils.parseEther("0.01"),utils.parseEther("1000000"),utils.parseEther("100"),utils.parseEther("500"), true)
    // Send token to launchPad

    const tokenContract = await ethers.getContractFactory("ERC20Token");
    const token = tokenContract.attach(
      tokenAddress
    );
    await token.mint(launchPadAddress, utils.parseEther("1000000"));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
