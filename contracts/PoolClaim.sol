//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./PoolBase.sol";

contract PoolClaim is
    PoolBase
{
    using SafeMathUpgradeable for uint256;

    // Add/update/delete Pool - by Admin
    function addPool(
        string memory _title,
        address _tokenAddress,
        uint256 _allocationBusd,
        uint256 _price
    ) public virtual onlyAdmin {
        require(_allocationBusd > 0, "Invalid allocationBusd");
        require(_price > 0, "Invalid Price");

        POOL_INFO memory pool;
        pool.tokenAddress = _tokenAddress;
        pool.allocationBusd = _allocationBusd;
        pool.price = _price;
        pool.claimOnly = true;
        pool.title = _title;

        pools.push(pool);

        emit PoolCreated(uint64(pools.length-1), block.timestamp);
    }


}
