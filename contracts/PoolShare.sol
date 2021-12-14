//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.5;

import "./PoolRIR.sol";

// Investors will receive BUSD instead of Token. 
// Treasury after receveive token from Project, sell and deposit BUSD into contract for Investors claim
contract PoolShare is
    PoolRIR
{
    using SafeMathUpgradeable for uint256;

    // string constant POOL_TYPE = "share";
    mapping(uint256 => uint256) depositedBusd;

    function deposit(uint64 _poolIdx, uint256 _amountToken)
        external
        override
        payable
        virtual
        onlyModerator
    {
        require(false, "120");
    }


    // Deposit into pool - by Admin
    function depositBusd(uint64 _poolIdx, uint256 _amountToken, uint256 _amountBusd)
        external
        payable
        onlyModerator
    {
        require(_amountToken > 0 && _amountBusd > 0 && _poolIdx < pools.length, "38"); // Invalid Data
        //POOL_INFO memory pool = pools[_poolIdx]; // pool info
        // require token set
        // require(pools[_poolIdx].locked && pools[_poolIdx].tokenAddress != address(0), "39"); // Pool not ready
        // not allow deposit more than need
        uint256 _totalDepositedValueBusd = poolsStat[_poolIdx].depositedToken.add(_amountToken).mul(pools[_poolIdx].price).div(1e18); // deposited convert to busd
        // uint256 _totalRequireDepositBusd = poolsStat[_poolIdx].approvedBusd.mul(100-pools[_poolIdx].fee).div(100); // allocation after fee
        require(
            _totalDepositedValueBusd <= getDepositAmount(_poolIdx, 100),
            "40" // Eceeds Pool Amount
        );

        // now deposited Busd 
        // ERC20 _token = ERC20(pools[_poolIdx].tokenAddress);
        require(
            _amountBusd <= busdToken.balanceOf(msg.sender),
            "41" // Not enough Token
        );
        // transfer
        require(
            busdToken.transferFrom(msg.sender, address(this), _amountBusd),
            "42" // Transfer failed
        );

        // update total deposited token
        poolsStat[_poolIdx].depositedToken += _amountToken;
        depositedBusd[_poolIdx] += _amountBusd;

        emit DepositedEvent(_poolIdx, _amountToken, block.timestamp);
    }


    // Claimed
    function getClaimable(uint64 _poolIdx) override public view returns (uint256) {
        if (_poolIdx >= pools.length) return 0; // pool not available

        address _address = msg.sender;
        Investor memory investor = investors[_poolIdx][_address];
        
        if (!investor.approved) return 0; // require approved        
        
        if (!pools[_poolIdx].locked) return 0;
        if (!investor.paid) return 0; // require paid

        uint256 _tokenClaimable = investor.allocationBusd
                                    .mul(depositedBusd[_poolIdx])
                                    .div(poolsStat[_poolIdx].approvedBusd);

        return _tokenClaimable.sub(investor.claimedToken);
    }

    function claim(uint64 _poolIdx) override public payable virtual isClaimable {

        refund(_poolIdx);

        // claim token
        uint256 _claimable = getClaimable(_poolIdx);
        if (_claimable > 0) {
            // available claim busd
            require(
                busdToken.balanceOf(address(this)) >= _claimable,
                "Not enough BUSD" // Not enough token
            );
            require(
                busdToken.transfer(msg.sender, _claimable),
                "Claim BUSD Failed" // ERC20 transfer failed - claim token
            );
            // update claimed token
            investors[_poolIdx][msg.sender].claimedToken += _claimable;

            emit ClaimEvent(_poolIdx, _claimable, msg.sender, block.timestamp);
        }
    }

}