module.exports = {
    contractType: "LaunchVerse",
    deploy: {
        title: "WIDI First",
        startDate: "2021/11/30 00:00:00 GMT+00:00",
        endDate: "2021/11/30 15:00:00 GMT+00:00",
        minAmountBusd: "100",
        maxAmountBusd: "100",
        price: "0.025",
        raise: "5000",
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