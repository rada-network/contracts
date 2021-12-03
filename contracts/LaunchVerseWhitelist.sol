//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./LaunchVerse.sol";

contract LaunchVerseWhitelist is LaunchVerse {
    using SafeMathUpgradeable for uint256;

    // store list to accept to join Pool
    mapping (address => bool) public whitelist;
    address[] whitelistAddresses;

    mapping (address => uint256) public allocations;


    // Getter
    function inWhitelist(address _address) public view returns (bool) {
        return whitelist[_address];
    }
    function countWhitelist() public view returns (uint) {
        return whitelistAddresses.length;
    }
    /** 
        Add or update to whitelist
     */
    function addToWhitelist(address _address) public virtual onlyUncommit onlyAdmin {
        if (!inWhitelist(_address)) {
            whitelistAddresses.push(_address);
        }
        whitelist[_address] = true;
    }
    function removeFromWhitelist(address _address) external virtual onlyUncommit onlyAdmin {
        require(inWhitelist(_address), "Not in whitelist");
        delete whitelist[_address];
        // takeout from array of address
        bool found;
        for (uint256 i = 0; i < whitelistAddresses.length; i++) {
            if (!found && whitelistAddresses[i] == _address) {
                found = true;                
            }

            // shift up when found
            if (found && i<whitelistAddresses.length-1) {
                whitelistAddresses[i] = whitelistAddresses[i+1];
            }
        }
        // takeout last one if found
        if (found) {
            delete whitelistAddresses[whitelistAddresses.length-1];
            // whitelistAddresses.length--;
        }
    }
    function importWhitelist(address[] memory _addresses) external virtual onlyUncommit onlyAdmin {
        for (uint256 i = 0; i < _addresses.length; i++) {
            addToWhitelist(_addresses[i]);
        }
    }


    function importAllocations(address[] memory _addresses, uint256[] memory _allocations) external virtual onlyAdmin {
        require(_addresses.length == _allocations.length, "length not match");
        for (uint256 i = 0; i < _addresses.length; i++) {
            allocations[_addresses[i]] = _allocations[i];
        }
    }


    function createSubscription(
        uint256 _amountBusd,
        uint256 _amountRIR,
        address _referer
    ) public payable override {
        // make sure the caller inside whitelist
        require(inWhitelist(msg.sender), "Not allow");

        // call parent
        super.createSubscription(_amountBusd, _amountRIR, _referer);
    }


    /**
     Pick Winner List base on the allocations and subscriptions
     */
    function pickWinners() external virtual onlyAdmin winEmpty {
        uint256 _bUSDLeft = bUSDForSale;
        uint256 _bUSDAllocated = 0;
        for (uint256 i=0; i< subscribers.length && _bUSDLeft > 0; i++) {
            address _address = subscribers[i];
            Order memory _order = subscription[_address];
            // max approved allocation
            uint256 _allocation = allocations[_address];
            // check with input
            if (_allocation > _order.amountBUSD) _allocation = _order.amountBUSD;
            // check if over total
            if (_allocation > _bUSDLeft) _allocation = _bUSDLeft;
            if (_allocation > 0) {
                // approve this allocation for this address
                subscription[_address].approvedBUSD = _allocation;
                winners.push(_address);
                // 
                _bUSDAllocated += _allocation;
                _bUSDLeft -= _allocation;
            }
        }

        bUSDAllocated = _bUSDAllocated;
    }

}
