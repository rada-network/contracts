// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// @ts-ignore
import { ethers } from "hardhat";
import { utils } from "ethers";

async function main() {

  let address = [
    // "0xE44F02C9cdC402dd2f133C9f48D1254904455e34",
    // "0xA8f68bB8d525f5874df9202c63C1f02eeC3dFE1f",
    // "0x82a0c5334F177649C48f1cC04245F57f4540148E",
    // "0x1f6A21AF5a882527af291227d0E6E72c372E5290",
    // "0xAE51701F3eB7b897eB6EE5ecdf35c4fEE29BFAe6",
    // "0x128392d27439F0E76b3612E9B94f5E9C072d74e0",
    // "0x3e11F3295b0af76C3AFAF545206b3d65F85eA82b",
    // "0x567f7A998Ea079619a7948dAad06416b5F4e166f",
    // "0x2D30a721eA478c3D7Fb766d125fefF781A2CB855",
    // "0x6C2cDd0d96B638D06a18108FE7B707BeD1C2E74e",
    // "0xf17C51A31F74517B94Fb4F3ceE932338bc0dC11D",
    // "0xE8A5011e68f2Bb601d71100714248788Cd0171FD",
    // "0x6d9d9567d639DD0FFD8b72e449E6b3A2846A81d2",
    // "0x1334e18C74D983692647C7ad029E595B1D9b1699",
    // "0x1D6018370Cb31dC97EA9aAb36491b99f675E47a8",
    // "0x0b188f2AE9a91dA7bF92ce623C65B2Ee032D5765",
    // "0x36Ab1192Ac6532aE1D4A691cC1D361372276cA4f",
    // "0x1861233D1Ab84dD59F8ce798BDEe7B164117e8f2",
    // "0xC8F7D67c47B2f6a53a514aC18bE2ff32Fb184150",
    // "0xF5e2BE3Cc5d32Fa1C53274C6e3bA266964097e17",
    // "0x070a5aCdD3724542336A4Fb975146BC92160C8e6",
    // "0xf5B190315fb1EB68576CFbCda7BA888aA158152f",
    // "0xb62552c188BF34C9d21B89F2219e7991068cE4F0",
    // "0x88cd5582802116D3b718D1B1c8D2742f9D0E8C32",
    // "0xB020e48C9c4E968b8B9ea84504E9F358167812aE",
    // "0x440FA8AD6d8bA817DB526402E0A78Fd643956a0E",
    // "0xAD65a301dA963ee0aE216a26081e9FD65DE17230",
    // "0xBd49a0556b9e4dA9e62633620B807d7994b5Ab01",
    // "0xfA873c1F60F708e94c6c1015980b0a42F1d94a5c",
    // "0x26846918B6BE733A2c953504006ace26F558665a",
    // "0xbc1c3cC9C8ca7B2AB5252CF47566a5FA51893F42",
    // "0xd21400d5EE27DfF4B058ff4b7176599d4038466b",
    // "0x554Ec809b351FA971ACbF723c5Db5f1699eC69b0",
    // "0x406c0c123546d4EeC631FE329936523Ac19831d6",
    // "0x04f043FD1fb6079a7672B35AABE690e40a35Df83",
    // "0x42f16dCDF20a3F479cd16B1032cf93eAA7330cE3",
    // "0xC8F7D67c47B2f6a53a514aC18bE2ff32Fb184150",
    // "0x3587949799e0E37C8a65ec31FFf610b75545B19d",
    // "0x1FE1d8Be7Afb3d0bfe1Bc321974c1A15889f9Fef",
    // "0x36Ab1192Ac6532aE1D4A691cC1D361372276cA4f",
    // "0x2D30a721eA478c3D7Fb766d125fefF781A2CB855",
    // "0x58E78124fe7cc061E1A9c05118379E72f0ed0621",
    "0xAE51701F3eB7b897eB6EE5ecdf35c4fEE29BFAe6"
  ]

  for (let index = 0; index < address.length; index++) {
        // Token Busd
        const busdContracts = await ethers.getContractFactory("ERC20Token");
        const busdAddress = "0x6945239350AE805b0823cB292a4dA5974d166640"
        const busd = busdContracts.attach(busdAddress);
        await busd.mint(address[index], utils.parseEther("1000000"))
    
        const rirContract = await ethers.getContractFactory("ERC20Token");
        const rirAddress = "0x6768BDC5d03A87942cE7cB143fA74e0DadE0371b"
        const rir = rirContract.attach(rirAddress);
        await rir.mint(address[index], utils.parseEther("1000000"))
  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
