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

    
    // Add / Import Investor
    function importInvestors (
        uint64 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _amountBusds,
        uint256[] memory _allocationBusds
    ) public virtual onlyAdmin {
        require(_poolIdx < pools.length, "28"); // Pool not available
        require(
            _addresses.length == _amountBusds.length
            && _addresses.length == _allocationBusds.length,
            "29"
        ); // Length not match

        for (uint256 i; i < _addresses.length; i++) {
            Investor memory investor = investors[_poolIdx][_addresses[i]];
            require(!investor.approved, "31"); // User is already approved
            require(
                investor.claimedToken.mul(pools[_poolIdx].price) <= _allocationBusds[i] && _allocationBusds[i] <= _amountBusds[i],
                "32" // Invalid Amount
            );
        }

        // import
        for (uint256 i; i < _addresses.length; i++) {
            address _address = _addresses[i];
            // check and put to address list: amount is 0 <= new address
            if (investors[_poolIdx][_address].allocationBusd == 0) {
                investorsAddress[_poolIdx].push(_address);
            }

            // update amount & allocation
            investors[_poolIdx][_address].amountBusd = _amountBusds[i];

            uint256 _allocationBusd = _allocationBusds[i];
            if (_allocationBusd == 0) _allocationBusd = 1; // using a tiny value, will not valid to claim
            investors[_poolIdx][_address].allocationBusd = _allocationBusd;
        }
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


    // No refund for whitelist pool
    function getRefundable (uint64 _poolIdx) override public pure returns (uint256, uint256) {
        return (0, 0);
    }
}
