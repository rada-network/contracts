module.exports = {
    contractType: "LaunchVerseWhitelist",
    deploy: {
        title: "DFH for KOL",
        startDate: "2021/11/30 05:00:00 GMT+00:00",
        endDate: "2021/12/02 05:00:00 GMT+00:00",
        minAmountBusd: "1000",
        maxAmountBusd: "7000",
        price: "0.05",
        raise: "100000",
        tokenFee: "10"
    },
    upgrade: { 
        /* update after deploy, using for upgrade */
        address: {
            "testnet": "",
            "mainnet": ""            
        }
    }
};