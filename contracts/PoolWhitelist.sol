//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.5;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./PoolBase.sol";

contract PoolWhitelist is
    PoolBase
{
    using SafeMathUpgradeable for uint256;

    string constant POOL_TYPE = "whitelist";

    event PaymentEvent(
        uint64 poolIndex,
        uint256 amountBusd,
        address indexed buyer,
        uint256 timestamp
    );

    function addPool(
        string memory _title,
        uint256 _allocationBusd,
        uint256 _price,
        uint256 _startDate,
        uint256 _endDate
    ) public virtual onlyAdmin {
        require(_allocationBusd > 0, "47"); // Invalid allocationBusd
        require(_price > 0, "48"); // Invalid Price

        POOL_INFO memory pool;
        pool.allocationBusd = _allocationBusd;
        pool.price = _price;
        pool.startDate = _startDate;
        pool.endDate = _endDate;
        pool.title = _title;

        pools.push(pool);

        emit PoolCreated(uint64(pools.length-1), block.timestamp);
    }
    

    /* Make a payment */
    function makePayment(
        uint64 _poolIdx
    ) public payable virtual {
        address _address = msg.sender;
        Investor memory investor = investors[_poolIdx][_address];
        require(investor.approved, "49"); // Not allow to join
        require(!investor.paid, "50"); // Paid already
        require(investor.amountBusd > 1, "51"); // Not allow to join pool
        
        // check pool
        require(_poolIdx < pools.length, "52"); // Pool not available
        POOL_INFO memory pool = pools[_poolIdx]; // pool info
        require(!pool.claimOnly, "53"); // Not require payment
        require(pool.locked, "54"); // Pool not active

        // require project is open and not expire
        require(block.timestamp <= pool.endDate, "55"); // The Pool has been expired
        require(block.timestamp >= pool.startDate, "56"); // The Pool have not started
        require(WITHDRAW_ADDRESS != address(0), "57"); // Not Ready for payment

        require(
            busdToken.balanceOf(msg.sender) >= investor.amountBusd,
            "58" // Not enough BUSD
        );

        require(
            busdToken.transferFrom(msg.sender, WITHDRAW_ADDRESS, investor.amountBusd),
            "59" // Payment failed
        );

        investors[_poolIdx][_address].paid = true;

        // update total RIR
        poolsStat[_poolIdx].amountBusd += investor.amountBusd;
        
        emit PaymentEvent(
            _poolIdx,
            investor.amountBusd,
            msg.sender,
            block.timestamp
        );
    }

}
