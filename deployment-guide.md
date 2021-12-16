# Deployment new POOL guide

### Configuration 
Sample in .env.example
`.env.testnet` for testnet
`.env.mainnet` for mainnet

### Prepare POOL Information


### Deploy
Test deploy new POOL on `testnet` by running
```
npx hardhat --network testnet deploy --contract PoolClaim
npx hardhat --network testnet deploy --contract PoolWhitelist
npx hardhat --network testnet deploy --contract PoolRIR
npx hardhat --network testnet deploy --contract PoolShare
```
Change network to `mainnet` after test thouroughly.

### Upgrade
Test deploy new POOL on `testnet` by running
```
npx hardhat --network testnet upgrade --contract PoolClaim
npx hardhat --network testnet upgrade --contract PoolWhitelist
npx hardhat --network testnet upgrade --contract PoolRIR
npx hardhat --network testnet upgrade --contract PoolShare
```
Change network to `mainnet` after test thouroughly.

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