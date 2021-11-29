module.exports = {
    contractType: "LaunchVerseWhitelist",
    deploy: {
        title: "DFH for KOL",
        startDate: "",
        endDate: "",
        minAmountBusd: "1000",
        maxAmountBusd: "10000",
        price: "0.04",
        raise: "100000",
        tokenFee: "0"
    },
    upgrade: { 
        /* update after deploy, using for upgrade */
        address: {
            "testnet": "0xac13d42526f9aef7a2985aaa93729d28d580a4ee",
            "mainnet": ""            
        }
    }
};