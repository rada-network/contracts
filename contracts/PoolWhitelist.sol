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
    ) public virtual {
        // check pool
        require(_poolIdx < pools.length, "Not Available"); // Pool not available

        Investor memory investor = investors[_poolIdx][msg.sender];
        require(investor.approved && investor.amountBusd > 1, "Not Allow"); // Not allow to join
        require(!investor.paid, "Paid Already"); // Paid already
        
        POOL_INFO memory pool = pools[_poolIdx]; // pool info
        require(pool.locked, "Not Ready"); // Pool not active

        // require project is open and not expire
        require(block.timestamp <= pool.endDate, "Expired"); // The Pool has been expired
        require(block.timestamp >= pool.startDate, "Not Started"); // The Pool have not started
        require(WITHDRAW_ADDRESS != address(0), "Not Ready"); // Not Ready for payment

        require(
            busdToken.balanceOf(msg.sender) >= investor.amountBusd,
            "Not enough BUSD" // Not enough BUSD
        );

        require(
            busdToken.transferFrom(msg.sender, WITHDRAW_ADDRESS, investor.amountBusd),
            "Payment Failed" // Payment failed
        );

        investors[_poolIdx][msg.sender].paid = true;

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
