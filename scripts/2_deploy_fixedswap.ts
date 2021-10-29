const { expect } = require('chai')
const { BigNumber } = require('ethers')

const _tradeValue = BigNumber.from(40000000000).toString();
const _tokensForSale = BigNumber.from(3500000000).mul(1000000000).mul(1000000000).toString();

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

const _individualMinimumAmount = BigNumber.from(10000000).mul(1000000000).mul(1000000000).toString();
const _individualMaximumAmount = BigNumber.from(200000000).mul(1000000000).mul(1000000000).toString();
const _isTokenSwapAtomic = false
const _minimumRaise = BigNumber.from(3500000000).mul(1000000000).mul(1000000000).toString();
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
