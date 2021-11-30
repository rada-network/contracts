# Deployment new POOL guide

### Configuration 
`.env` for testnet
`.env.mainnet` for mainnet

```shell
MNEMONIC=""
BSCSCANAPIKEY=""
```

### Prepare POOL Information

To deploy a new POOL, clone a folder inside `scripts/POOLS/` folder, eg to `scripts/POOLS/ABC-Test` and update information in `infor.ts`

    module.exports = {
        contractType: "LaunchVerseWhitelist",
        deploy: {
            title: "ABC Test Pool",
            startDate: "2021/11/30 05:00:00 GMT+00:00",
            endDate: "2021/11/30 15:00:00 GMT+00:00",
            minAmountBusd: "1000",
            maxAmountBusd: "10000",
            price: "0.04",
            raise: "100000",
            tokenFee: "0"
        },
        upgrade: { 
            /* update after deploy, using for upgrade */
            address: {
                "testnet": "",
                "mainnet": ""            
            }
        }
    };

### Deploy
Test deploy new POOL on `testnet` by running
```
npx hardhat run scripts/POOLS/ABC-Test/deploy.ts --network testnet
```
Change network to `mainnet` after test thouroughly.
Copy return address and store to `info.ts`
### Verify
After deploy contract, go to bscscan.com (or testnet.bscscan.com)j to view the new contract. Click on `contract` and choose `More Options`, select `Is this is Proxy?` to verify. Copy the implemented token address there if cannot verify, and run following command
```
npx hardhat verify [implemented-token-address] --network testnet
```
After successfully verify, go back to bscscan to verify the Contract.

### Setup POOL
1. Withdraw Address: add WITHDRAW ADDRESS to cashout Raising Fund
2. Whitelist: if this is Whitelist Pool, then need import whitelist
 
### Upgrade POOL Contract
If the contract update, deploy a Contract upgrade by running
```
npx hardhat run scripts/POOLS/ABC-Test/upgrade.ts --network testnet
```

### Create POOL in CMS
Setup and test new POOL (testnet) on staging server.