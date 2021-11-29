import { upgradeContract } from "../lib"

async function main() {
    let launchPadAddress = await upgradeContract (__dirname)
    console.log('Upgrade Contract: ', launchPadAddress);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });