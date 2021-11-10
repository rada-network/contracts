// @ts-ignore
import {ethers} from "hardhat"
import {utils} from "ethers"

const _tradeValue = utils.formatEther("40000000000");
const _tokensForSale = utils.formatEther("3500000000");

/*
GMT: Wednesday, June 23, 2021 1:00:00 AM
Your time zone: Wednesday, June 23, 2021 8:00:00 AM GMT+07:00
*/
const _startDate = '1627741323' // https://www.epochconverter.com/

/*
GMT: Thursday, July 1, 2021 1:00:00 AM
Your time zone: Thursday, July 1, 2021 8:00:00 AM GMT+07:00
*/
const _endDate = '1659277323' // https://www.epochconverter.com/

const _individualMinimumAmount = utils.formatEther("10000000");
const _individualMaximumAmount = utils.formatEther("200000000");
const _isTokenSwapAtomic = false
const _minimumRaise = utils.formatEther("3500000000");
const _feeAmount = '1'
const _hasWhitelisting = false
let addressToken = '0x84Be2E42e970A9815424619317bc249893d45ef7'

async function main() {
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
}

main()
	.then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});
