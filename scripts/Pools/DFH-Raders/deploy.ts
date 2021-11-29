import { deployContract } from "../lib"

async function main() {
    let launchPadAddress = await deployContract (__dirname)
    console.log('LaunchPad Contract: ', launchPadAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });