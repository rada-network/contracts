LaunchPad Smart Contract

Configuration .env file
```
MNEMONIC=""
BSCSCANAPIKEY=""
```
The following tasks:
```
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
```
Build & Deploy

RIR Token
```
npx hardhat run scripts/1_deploy_rir_token.ts --network testnet
```
Verify RIR
```
npx hardhat verify --network testnet ADDRESS_TOKEN_RIR
```
LaunchPad Token
```
npx hardhat run scripts/2_deloy_launchpad.ts --network testnet
```
Verify LaunchPad
```
npx hardhat verify --network testnet ADDRESS_LAUNCHPAD
```

Test
```
npx hardhat test --network testnet test
```