//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.5;

import "./PoolBase.sol";

contract PoolRIR is
    PoolBase
{
    using SafeMathUpgradeable for uint256;

    string constant POOL_TYPE = "rir";

    event PaymentEvent(
        uint64 poolIndex,
        uint256 amountBusd,
        uint256 amountRir,
        address indexed buyer,
        uint256 timestamp
    );

    uint16 constant RIR_RATE = 100;
    mapping(uint256 => uint256) rirInvestorCounts;
    mapping(uint256 => bool) withdrawedPools;

    
    // Add / Import Allocation for winners
    function importWinners(
        uint64 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _allocationBusds,
        uint256[] memory _allocationRirs
    ) public virtual onlyAdmin {
        require(_poolIdx < pools.length, "84"); // Pool not available
        require(_addresses.length == _allocationBusds.length && _addresses.length == _allocationRirs.length, "85"); // Length not match

        // POOL_INFO memory pool = pools[_poolIdx]; // pool info

        for (uint256 i; i < _addresses.length; i++) {
            Investor memory investor = investors[_poolIdx][_addresses[i]]; 
            // user must paid to be winner
            require(investor.paid, "86"); // User not paid
            require(!investor.approved, "87"); // User already approved
            require(
                true
                && investor.claimedToken.mul(pools[_poolIdx].price).div(1e18) <= _allocationBusds[i] // Claim over allocation
                && _allocationBusds[i] <= investor.amountBusd // cannot approve more busd than prefunded
                && _allocationRirs[i] <= investor.amountRir // cannot approve more rir than prefunded
                && _allocationRirs[i].mul(RIR_RATE) <= _allocationBusds[i], // cannot approve more rir than busd
                "88" // Invalid Amount
            );
        }

        // import
        for (uint256 i; i < _addresses.length; i++) {
            address _address = _addresses[i];
            // update amount & allocation

            investors[_poolIdx][_address].allocationRir = _allocationRirs[i];

            uint256 _allocationBusd = _allocationBusds[i];
            if (_allocationBusd == 0) _allocationBusd = 1; // using a tiny value, will not valid to claim
            investors[_poolIdx][_address].allocationBusd = _allocationBusd;
        }
    }


    // Approve Investor
    function approveInvestors(uint64 _poolIdx) override external virtual onlyApprover {
        require(_poolIdx < pools.length, "89"); // Pool not available

        POOL_INFO memory pool = pools[_poolIdx]; // pool info

        // require pool is locked
        require(pool.locked, "90"); // Pool not locked
        // check for approved amount
        uint256 _totalAllocationBusd;
        uint256 _totalAllocationRir;
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            Investor memory investor = investors[_poolIdx][_address];

            require(
                investor.claimedToken.mul(pool.price).div(1e18) <= investor.allocationBusd // make sure the claim less amount
                && investor.allocationBusd <= investor.amountBusd // Busd approve less prefunded
                && investor.allocationRir <= investor.amountRir // Rir approve less prefunded
                && (investor.allocationRir > 0 || investor.amountRir == 0) // Rir investor must be approved rir allocation
                && investor.allocationRir.mul(RIR_RATE) <= investor.allocationBusd // Rir allocation converted must less Busd allocation
                ,
                "91"
            );

            if (investor.allocationBusd > 1) {
                _totalAllocationBusd += investor.allocationBusd;
            }
            _totalAllocationRir += investor.allocationRir;
        }
        require(_totalAllocationBusd > 0 && _totalAllocationBusd <= pool.allocationBusd, "92"); // Eceeds total allocation Busd or not import winners
        require(_totalAllocationRir <= pool.allocationRir, "93"); // Eceeds total allocation RIR

        // approve
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            investors[_poolIdx][_address].approved = true;
        }

        poolsStat[_poolIdx].approvedBusd = _totalAllocationBusd;
        poolsStat[_poolIdx].approvedRir = _totalAllocationRir;
    }


    /* Make a payment */
    function makePayment(
        uint64 _poolIdx,
        uint256 _amountBusd,
        uint256 _amountRir
    ) public payable virtual {
        require(_poolIdx < pools.length, "94"); // Pool not available

        address _address = msg.sender;
        Investor memory investor = investors[_poolIdx][_address];
        // require(!investor.paid, "Paid already");
        
        // check pool
        POOL_INFO memory pool = pools[_poolIdx]; // pool info
        require(pool.locked, "96"); // Pool not active

        // require project is open and not expire
        require(block.timestamp <= pool.endDate, "97"); // The Pool has been expired
        require(block.timestamp >= pool.startDate, "98"); // The Pool have not started
        // require(WITHDRAW_ADDRESS != address(0), "Not Ready for payment"); // pay to contract

        require(_amountBusd > 0 || _amountRir > 0, "99"); // Pay nothing

        // not over RIR count
        require (rirInvestorCounts[_poolIdx].mul(1e18) < pool.allocationRir || _amountRir ==  0 || investor.amountRir > 0, "100"); // Eceeds RIR allocation

        require(_amountBusd == 0 || investor.amountBusd + _amountBusd >= pool.minAllocationBusd, "101"); // Eceeds Minimum Busd
        require(_amountBusd == 0 || investor.amountBusd + _amountBusd <= pool.maxAllocationBusd, "102"); // Eceeds Maximum Busd


        require(
            busdToken.balanceOf(msg.sender) >= _amountBusd // Not enough BUSD
            && rirToken.balanceOf(msg.sender) >= _amountRir, // not enought RIR
            "103" // Not enough BUSD
        );

        if (_amountBusd > 0) {
            require(
                busdToken.transferFrom(msg.sender, address(this), _amountBusd),
                "104" // Payment failed
            );
            // put to address array
            if (investors[_poolIdx][_address].amountBusd == 0) {
                investorsAddress[_poolIdx].push(msg.sender);
            }
            investors[_poolIdx][_address].amountBusd += _amountBusd;
        }

        if (_amountRir > 0) {
            if (investor.amountRir == 0) rirInvestorCounts[_poolIdx]++;
            require(
                rirToken.transferFrom(msg.sender, address(this), _amountRir),
                "105" // Payment failed
            );
            investors[_poolIdx][_address].amountRir += _amountRir;
        }

        investors[_poolIdx][_address].paid = true;

        // update total RIR
        poolsStat[_poolIdx].amountBusd += _amountBusd;
        poolsStat[_poolIdx].amountRir += _amountRir;
        
        emit PaymentEvent(
            _poolIdx,
            investor.amountBusd,
            investor.amountRir,
            msg.sender,
            block.timestamp
        );
    }


    /* Admin Withdraw BUSD */
    function withdrawBusdFunds(uint64 _poolIdx) external virtual onlyModerator {
        require(_poolIdx < pools.length, "94"); // Pool not available
        require(WITHDRAW_ADDRESS != address(0), "112"); // Withdraw address net set
        require(!withdrawedPools[_poolIdx], "110"); // Pool withdraw already
        
        require(
            busdToken.transfer(WITHDRAW_ADDRESS, poolsStat[_poolIdx].approvedBusd),
            "111"
        );
        withdrawedPools[_poolIdx] = true;

        // also burn rir
        rirToken.burn(poolsStat[_poolIdx].approvedRir);
    }

}
