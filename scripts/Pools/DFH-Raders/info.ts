module.exports = {
    contractType: "LaunchVerseWhitelist",
    deploy: {
        title: "DFH for Raders",
        startDate: "2021/11/30 05:00:00 GMT+00:00",
        endDate: "2021/12/01 15:00:00 GMT+00:00",
         minAmountBusd: "100",
        maxAmountBusd: "800",
        price: "0.05",
        raise: "10300",
        tokenFee: "10"
    },
    upgrade: { 
        /* update after deploy, using for upgrade */
        address: {
            testnet: "",
            mainnet: "0xae88eBdEa01BE89Af2F3f64fF4C4cADB588B0ff4"            
        }
    }
};