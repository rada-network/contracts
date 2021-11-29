module.exports = {
    contractType: "LaunchVerseWhitelist",
    deploy: {
        title: "DFH for Raders",
        startDate: "2021/11/30 05:00:00 GMT+00:00",
        endDate: "2021/11/30 15:00:00 GMT+00:00",
         minAmountBusd: "100",
        maxAmountBusd: "500",
        price: "0.04",
        raise: "10300",
        tokenFee: "0"
    },
    upgrade: { 
        /* update after deploy, using for upgrade */
        address: {
            testnet: "0xcBC97e533aBd11f39C20a4D843963C8dFd3f38fb",
            mainnet: ""            
        }
    }
};