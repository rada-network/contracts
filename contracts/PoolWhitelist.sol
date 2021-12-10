//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./PoolBase.sol";

contract PoolWhitelist is
    PoolBase
{
    using SafeMathUpgradeable for uint256;


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
        require(_allocationBusd > 0, "Invalid allocationBusd");
        require(_price > 0, "Invalid Price");

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
        require(investor.approved, "Not allow to join");
        require(!investor.paid, "Paid already");
        require(investor.amountBusd > 1, "Not allow to join pool");
        
        // check pool
        require(_poolIdx < pools.length, "Pool not available");
        POOL_INFO memory pool = pools[_poolIdx]; // pool info
        require(!pool.claimOnly, "Not require payment");
        require(pool.locked, "Pool not active");

        // require project is open and not expire
        require(block.timestamp <= pool.endDate, "The Pool has been expired");
        require(block.timestamp >= pool.startDate, "The Pool have not started");
        require(WITHDRAW_ADDRESS != address(0), "Not Ready for payment");

        require(
            busdToken.balanceOf(msg.sender) >= investor.amountBusd,
            "Not enough BUSD"
        );

        require(
            busdToken.transferFrom(msg.sender, WITHDRAW_ADDRESS, investor.amountBusd),
            "Payment failed"
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
