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

    // state to mark pool are approved
    mapping(uint256 => bool) poolApproved;
    mapping(uint256 => uint256) rirApprovedCount;
    
    // Add / Import Allocation for winners
    function importWinners(
        uint64 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _allocationBusds,
        uint256[] memory _allocationRirs
    ) public virtual onlyAdmin {
        // require(_poolIdx < pools.length, "84"); // Pool not available
        require(_addresses.length == _allocationBusds.length && _addresses.length == _allocationRirs.length, "85"); // Length not match
        require(!poolApproved[_poolIdx], "Pool Approved already");

        // POOL_INFO memory pool = pools[_poolIdx]; // pool info
        uint256 _totalAllocationBusd = poolsStat[_poolIdx].approvedBusd ;
        uint256 _totalAllocationRir = poolsStat[_poolIdx].approvedRir;
        uint256 _approvedCount = poolsStat[_poolIdx].approvedCount;

        for (uint256 i; i < _addresses.length; i++) {
            Investor memory investor = investors[_poolIdx][_addresses[i]]; 
            // user must paid to be winner
            require(investor.paid, "86"); // User not paid
            // require(!investor.approved, "87"); // User already approved
            require(
                true
                && investor.claimedToken.mul(pools[_poolIdx].price).div(1e18) <= _allocationBusds[i] // Claim over allocation
                && _allocationBusds[i] <= investor.amountBusd // cannot approve more busd than prefunded
                && _allocationRirs[i] <= investor.amountRir // cannot approve more rir than prefunded
                && _allocationRirs[i].mul(RIR_RATE) <= _allocationBusds[i], // cannot approve more rir than busd
                "88" // Invalid Amount
            );

            _totalAllocationBusd = _totalAllocationBusd.add(_allocationBusds[i]).sub(investor.allocationBusd);
            _totalAllocationRir = _totalAllocationRir.add(_allocationRirs[i]).sub(investor.allocationRir);
        }

        require(_totalAllocationBusd <= pools[_poolIdx].allocationBusd, "92"); // Exceeds total allocation Busd or not import winners
        require(_totalAllocationRir <= pools[_poolIdx].allocationRir, "93"); // Exceeds total allocation RIR

        // import
        for (uint256 i; i < _addresses.length; i++) {
            address _address = _addresses[i];
            // approved count
            if (investors[_poolIdx][_address].allocationBusd > 0 && _allocationBusds[i] == 0) {
                _approvedCount--;
                investors[_poolIdx][_address].approved = false;
            } else if (investors[_poolIdx][_address].allocationBusd == 0 && _allocationBusds[i] > 0) {
                _approvedCount++;
                investors[_poolIdx][_address].approved = true;
            }
            if (investors[_poolIdx][_address].allocationRir > 0 && _allocationRirs[i] == 0) {
                rirApprovedCount[_poolIdx]--;
            } else if (investors[_poolIdx][_address].allocationRir == 0 && _allocationRirs[i] > 0) {
                rirApprovedCount[_poolIdx]++;
            }
            // update amount & allocation
            investors[_poolIdx][_address].allocationRir = _allocationRirs[i];
            investors[_poolIdx][_address].allocationBusd = _allocationBusds[i];
            // uint256 _allocationBusd = _allocationBusds[i];
            // if (_allocationBusd == 0) _allocationBusd = 1; // using a tiny value, will not valid to claim
        }

        poolsStat[_poolIdx].approvedBusd = _totalAllocationBusd;
        poolsStat[_poolIdx].approvedRir = _totalAllocationRir;
        poolsStat[_poolIdx].approvedCount = investorsAddress[_poolIdx].length;        
    }

    // Approve winner list
    function approveInvestors(uint64 _poolIdx) override external virtual onlyApprover {
        require(pools[_poolIdx].locked, "90"); // Pool not locked
        require(!poolApproved[_poolIdx], "Pool Approved already");
        require(poolsStat[_poolIdx].approvedCount > 0, "No Winner");
        if (_msgSender() != owner()) 
            require(rirApprovedCount[_poolIdx] == rirInvestorCounts[_poolIdx], "91");
        poolApproved[_poolIdx] = true;
    }

    function unApproveInvestors(uint64 _poolIdx) external virtual onlyApprover {
        require(poolApproved[_poolIdx], "Pool Not Approved");
        poolApproved[_poolIdx] = false;
    }

    /* Make a payment */
    function makePayment(
        uint64 _poolIdx,
        uint256 _amountBusd,
        uint256 _amountRir
    ) public virtual {
        //require(_poolIdx < pools.length, "Not Available"); // Pool not available

        Investor memory investor = investors[_poolIdx][msg.sender];
        // require(!investor.paid, "Paid already");
        
        // check pool
        POOL_INFO memory pool = pools[_poolIdx]; // pool info
        require(pool.locked, "Not Ready"); // Pool not active

        // require project is open and not expire
        require(block.timestamp <= pool.endDate, "Expired"); // The Pool has been expired
        require(block.timestamp >= pool.startDate, "Not Started"); // The Pool have not started
        // require(WITHDRAW_ADDRESS != address(0), "Not Ready for payment"); // pay to contract

        require(_amountBusd > 0 || _amountRir > 0, "Invalid Amount"); // Pay nothing

        // not over RIR count
        require (rirInvestorCounts[_poolIdx].mul(1e18) < pool.allocationRir || _amountRir ==  0 || investor.amountRir > 0, "Exceeds RIR Allocation"); // Exceeds RIR allocation

        require(_amountBusd == 0 || investor.amountBusd + _amountBusd >= pool.minAllocationBusd, "Under Minimum"); // Exceeds Minimum Busd
        require(_amountBusd == 0 || investor.amountBusd + _amountBusd <= pool.maxAllocationBusd, "Over Maximum"); // Exceeds Maximum Busd


        require(
            busdToken.balanceOf(msg.sender) >= _amountBusd // Not enough BUSD
            && rirToken.balanceOf(msg.sender) >= _amountRir, // not enought RIR
            "Not enough Token" // Not enough BUSD
        );

        if (_amountBusd > 0) {
            require(
                busdToken.transferFrom(msg.sender, address(this), trimnum(_amountBusd)),
                "Transfer BUSD Failed" // Payment failed
            );
            // put to address array
            if (investors[_poolIdx][msg.sender].amountBusd == 0) {
                investorsAddress[_poolIdx].push(msg.sender);
            }
            investors[_poolIdx][msg.sender].amountBusd += trimnum(_amountBusd);
        }

        if (_amountRir > 0) {
            if (investor.amountRir == 0) rirInvestorCounts[_poolIdx]++;
            require(
                rirToken.transferFrom(msg.sender, address(this), trimnum(_amountRir)),
                "Transfer RIR Failed" // Payment failed
            );
            investors[_poolIdx][msg.sender].amountRir += trimnum(_amountRir);
        }

        investors[_poolIdx][msg.sender].paid = true;

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
        //require(_poolIdx < pools.length, "94"); // Pool not available
        require(poolsStat[_poolIdx].approvedBusd > 0, "Fund not available"); // Pool not available
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


    /////////////////////////////////////////////////
    /// Override claim base on poolApproved
    // refund 
    function getRefundable (uint64 _poolIdx) override public view virtual returns (uint256, uint256) {
        if (!poolApproved[_poolIdx]) return (0, 0); // pool not approved

        Investor memory investor = investors[_poolIdx][msg.sender];
        
        if (
            !pools[_poolIdx].locked
            || !investor.paid
            //|| !investor.approved
            || investor.refunded
        ) 
            return (0, 0); // require paid
        
        return (investor.amountBusd.sub(trimnum(investor.allocationBusd)), investor.amountRir.sub(trimnum(investor.allocationRir)));
    }


    function claim(uint64 _poolIdx) override public virtual isClaimable {
        // need paid & approved to call claim
        require(poolApproved[_poolIdx], "Pool Not Approved");
        require(investors[_poolIdx][msg.sender].paid, "Not Paid");

        refund(_poolIdx);

        // claim token
        uint256 _claimable = getClaimable(_poolIdx);
        if (_claimable > 0) {
            // available claim busd
            ERC20 _token = ERC20(pools[_poolIdx].tokenAddress);
            require(
                _token.balanceOf(address(this)) >= _claimable,
                "Not enough Token" // Not enough token
            );

            // update claimed token then transfer
            investors[_poolIdx][msg.sender].claimedToken += _claimable;
            require(
                _token.transfer(msg.sender, _claimable),
                "Claim Token Failed" // ERC20 transfer failed - claim token
            );

            emit ClaimEvent(_poolIdx, _claimable, msg.sender, block.timestamp);
        }
    }


}
