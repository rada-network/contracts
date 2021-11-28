//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./LaunchVerse.sol";

contract LaunchVerseWhitelist is LaunchVerse {
    using SafeMathUpgradeable for uint256;

    // store list to accept to join Pool
    mapping (address => bool) public whitelist;
    address[] whitelistAddresses;


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
    function addToWhitelist(address _address) public virtual onlyAdmin {
        if (!inWhitelist(_address)) {
            whitelistAddresses.push(_address);
        }
        whitelist[_address] = true;
    }
    function removeFromWhitelist(address _address) external virtual onlyAdmin {
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
    function importWhitelist(address[] memory _addresses) external virtual onlyAdmin {
        for (uint256 i = 0; i < _addresses.length; i++) {
            addToWhitelist(_addresses[i]);
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

}
