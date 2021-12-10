//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "./PoolBase.sol";

contract PoolRIR is
    PoolBase
{
    using SafeMathUpgradeable for uint256;

    event PaymentEvent(
        uint64 poolIndex,
        uint256 amountBusd,
        uint256 amountRir,
        address indexed buyer,
        uint256 timestamp
    );

    uint16 constant RIR_RATE = 100;
    mapping(uint256 => uint256) rirInvestorCounts;

    // Add/update/delete Pool - by Admin
    function addPool(
        string memory _title,
        uint256 _allocationBusd,
        uint256 _minAllocationBusd,
        uint256 _maxAllocationBusd,
        uint256 _allocationRir,
        uint256 _price,
        uint256 _startDate,
        uint256 _endDate
    ) public virtual onlyAdmin {
        require(_allocationBusd > 0, "Invalid allocationBusd");
        require(_price > 0, "Invalid Price");


        POOL_INFO memory pool;
        pool.allocationBusd = _allocationBusd;
        pool.minAllocationBusd = _minAllocationBusd;
        pool.maxAllocationBusd = _maxAllocationBusd;
        pool.allocationRir = _allocationRir;
        pool.price = _price;
        pool.startDate = _startDate;
        pool.endDate = _endDate;
        pool.title = _title;

        pools.push(pool);

        emit PoolCreated(uint64(pools.length-1), block.timestamp);
    }


    
    // Add / Import Investor - Not allow in RIR Pool
    function importInvestors(
        uint64 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _amountBusds,
        uint256[] memory _allocationBusds
    ) override public virtual onlyAdmin {
        require(false, "Not allow in RIR Pool");
    }

    
    // Add / Import Allocation for winners
    function importWinners(
        uint64 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _allocationBusds,
        uint256[] memory _allocationRirs
    ) public virtual onlyAdmin {
        require(_poolIdx < pools.length, "Pool not available");
        require(_addresses.length == _allocationBusds.length, "Length not match");
        require(_addresses.length == _allocationRirs.length, "Length not match");

        POOL_INFO memory pool = pools[_poolIdx]; // pool info

        for (uint256 i; i < _addresses.length; i++) {
            Investor memory investor = investors[_poolIdx][_addresses[i]]; 
            // user must paid to be winner
            require(!investor.paid, "User not paid");
            require(!investor.approved, "User already approved");
            require(
                investor.claimedToken.mul(pool.price) <= _allocationBusds[i],
                "Invalid Amount"
            );
            // cannot approve more busd than prefunded
            require(
                _allocationBusds[i] <= investor.amountBusd,
                "Invalid Amount"
            );
            // cannot approve more rir than prefunded
            require(
                _allocationRirs[i] <= investor.amountRir,
                "Invalid Amount"
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
        require(_poolIdx < pools.length, "Pool not available");

        POOL_INFO memory pool = pools[_poolIdx]; // pool info

        // require pool is locked
        require(pool.locked, "Pool not locked");

        // check for approved amount
        uint256 _totalAllocationBusd;
        uint256 _totalAllocationRir;
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            Investor memory investor = investors[_poolIdx][_address];

            // make sure the claim less amount
            require(
                investor.claimedToken.mul(pool.price) <= investor.allocationBusd,
                "Invalid Amount"
            );
            // Busd approve less prefunded
            require(
                investor.allocationBusd <= investor.amountBusd,
                "Invalid Amount"
            );
            // Rir approve less prefunded
            require(
                investor.allocationRir <= investor.amountRir,
                "Invalid Amount Rir"
            );
            // Rir investor must be approved
            require(
                investor.allocationRir > 0 || investor.amountRir == 0,
                "Invalid Amount Rir"
            );
            // Rir allocation converted must less Busd allocation
            require(
                investor.allocationRir.mul(RIR_RATE) <= investor.allocationBusd,
                "Invalid Amount Rir"
            );

            if (investor.allocationBusd > 1) {
                _totalAllocationBusd += investor.allocationBusd;
            }
            _totalAllocationRir += investor.allocationRir;
        }
        require(_totalAllocationBusd <= pool.allocationBusd, "Eceeds total allocation Busd");
        require(_totalAllocationRir <= pool.allocationRir, "Eceeds total allocation RIR");

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
        require(_poolIdx < pools.length, "Pool not available");

        address _address = msg.sender;
        Investor memory investor = investors[_poolIdx][_address];
        // require(!investor.paid, "Paid already");
        
        // check pool
        POOL_INFO memory pool = pools[_poolIdx]; // pool info
        require(!pool.claimOnly, "Not require payment");
        require(pool.locked, "Pool not active");

        // require project is open and not expire
        require(block.timestamp <= pool.endDate, "The Pool has been expired");
        require(block.timestamp >= pool.startDate, "The Pool have not started");
        // require(WITHDRAW_ADDRESS != address(0), "Not Ready for payment"); // pay to contract

        require(_amountBusd > 0 || _amountRir > 0, "Pay nothing");

        // not over RIR count
        require (rirInvestorCounts[_poolIdx] < pool.allocationRir || _amountRir ==  0 || investor.amountRir > 0, "Eceeds RIR allocation");

        require(_amountBusd == 0 || investor.amountBusd + _amountBusd >= pool.minAllocationBusd, "Eceeds Minimum Busd");
        require(_amountBusd == 0 || investor.amountBusd + _amountBusd <= pool.maxAllocationBusd, "Eceeds Maximum Busd");


        require(
            busdToken.balanceOf(msg.sender) >= _amountBusd,
            "Not enough BUSD"
        );

        require(
            busdToken.balanceOf(msg.sender) >= _amountRir,
            "Not enough RIR"
        );

        if (_amountBusd > 0) {
            require(
                busdToken.transferFrom(msg.sender, address(this), _amountBusd),
                "Payment failed"
            );
            investor.amountBusd += _amountBusd;
        }

        if (_amountRir > 0) {
            if (investor.amountRir == 0) rirInvestorCounts[_poolIdx]++;
            require(
                rirToken.transferFrom(msg.sender, address(this), _amountRir),
                "Payment failed"
            );
            investor.amountRir += _amountRir;
        }

        investors[_poolIdx][_address].paid = true;

        // update total RIR
        poolsStat[_poolIdx].amountBusd += investor.amountBusd;
        poolsStat[_poolIdx].amountRir += investor.amountRir;
        
        emit PaymentEvent(
            _poolIdx,
            investor.amountBusd,
            investor.amountRir,
            msg.sender,
            block.timestamp
        );
    }
}
