import { deployContract } from "../lib"

async function main() {
    console.log('xx:', __dirname);
    return '';
    let launchPadAddress = await deployContract ('DFH-VIP')
    console.log('LaunchPad Contract: ', launchPadAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });