//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.5;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./PoolBase.sol";

contract PoolClaim is
    PoolBase
{
    using SafeMathUpgradeable for uint256;

    string constant POOL_TYPE = "claim";

    
    // Add / Import Investor
    function importInvestors(
        uint64 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _amountBusds,
        uint256[] memory _allocationBusds,
        bool[] memory _refundeds
    ) public virtual onlyAdmin {
        require(_poolIdx < pools.length, "28"); // Pool not available
        require(
            _addresses.length == _amountBusds.length
            && _addresses.length == _allocationBusds.length
            && _addresses.length == _refundeds.length, "29"); // Length not match

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

            investors[_poolIdx][_address].refunded = _refundeds[i];

            // claimonly, then mark as paid - only import paid investors
            investors[_poolIdx][_address].paid = true;
        }
    }
}
