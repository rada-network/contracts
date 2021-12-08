//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract ClaimOnly is
    Initializable,
    ContextUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    /* Admins List, state for user */
    mapping(address => bool) public admins;
    mapping(address => bool) public approvers;
    bool claimable; // global state for all,

    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
    }

    // Modifiers
    modifier onlyModerator() {
        require(msg.sender == owner() || admins[msg.sender] == true || approvers[msg.sender] == true, "Caller is not an admin");
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == owner() || admins[msg.sender] == true, "Caller is not an admin");
        _;
    }
    modifier onlyApprover() {
        require(msg.sender == owner() || approvers[msg.sender] == true, "Caller is not an approver");
        _;
    }
    modifier isClaimable() {
        require(claimable == true, "Claim is not available at this time.");
        _;
    }

    /* Admin role who can handle winner list, deposit token */
    function setAdmin(address _address, bool _allow) public onlyOwner {
        admins[_address] = _allow;
    }

    /* Admin role who can handle winner list, deposit token */
    function setApprover(address _address, bool _allow) public onlyOwner {
        approvers[_address] = _allow;
    }
    //
    function setClaimable(bool _allow) public onlyModerator {
        claimable = _allow;
    }

    /**
        DATA Structure
     */
    struct POOL {
        ERC20 token;
        uint256 amount; // total amount in $
        uint256 price;
        uint256 deposited;
        bool locked; // if locked, cannot change pool info
    }

    POOL[] public pools;

    struct Invester {
        uint256 amount; // approved amount in $
        uint256 claimed; // amount of Token claimed
        bool approved; // state to make sure this invester is approved
    }

    mapping(uint256 => mapping(address => Invester)) private investers;
    mapping(uint256 => address[]) private investersAddress;

    /**
        Modifiers
     */

    /**
        GETTER
     */ 
    function poolCount() external view returns (uint) {
        return pools.length;
    }

    function poolAddresses(uint _poolIdx) external view returns (address[] memory) {
        return investersAddress[_poolIdx];
    }

    function getInvester (uint _poolIdx, address _address) external view returns (Invester memory) {
        return investers[_poolIdx][_address];
    }

    /**
        SETTER
     */

    // Add/update/delete Pool - by Admin
    function addPool(
        address _tokenAddress,
        uint256 _amount,
        uint256 _price
    ) public virtual onlyAdmin {
        require(_amount > 0, "Invalid Amount");
        require(_price > 0, "Invalid Price");

        POOL memory pool;
        pool.token = ERC20(_tokenAddress);
        pool.amount = _amount;
        pool.price = _price;
    }

    function updatePool(
        uint256 _poolIdx,
        uint256 _amount,
        uint256 _price
    ) public virtual onlyAdmin {
        require(_amount > 0, "Invalid Amount");
        require(_price > 0, "Invalid Price");
        require(_poolIdx < pools.length, "Pool not available");

        POOL memory pool = pools[_poolIdx]; // pool info

        require(!pool.locked, "Pool locked");

        // do update
        pools[_poolIdx].amount = _amount;
        pools[_poolIdx].price = _price;
    }

    // Lock / unlock pool - By Approver
    function lockPool(uint256 _poolIdx) public virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");
        require(!pools[_poolIdx].locked, "Pool locked");
        // Lock pool
        pools[_poolIdx].locked = true;
    }

    // to unlock, all investers need unapproved
    function unlockPool(uint256 _poolIdx) public virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");
        require(pools[_poolIdx].locked, "Pool not locked");
        // make sure no approve invester
        for (uint256 i; i < investersAddress[_poolIdx].length; i++) {
            address _address = investersAddress[_poolIdx][i];
            Invester memory invester = investers[_poolIdx][_address];
            require(!invester.approved, "Invester approved");
        }
        // Lock pool
        pools[_poolIdx].locked = false;
    }

    // Add / Import Invester
    function importInvester(
        uint256 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _amounts
    ) public virtual onlyAdmin {
        require(_poolIdx < pools.length, "Pool not available");
        require(_addresses.length == _amounts.length, "Length not match");

        POOL memory pool = pools[_poolIdx]; // pool info

        for (uint256 i; i < _addresses.length; i++) {
            Invester memory invester = investers[_poolIdx][_addresses[i]];
            require(!invester.approved, "User is already approved");
            require(
                invester.claimed.mul(pool.price) <= _amounts[i],
                "Invalid Amount"
            );
        }

        // import
        for (uint256 i; i < _addresses.length; i++) {
            address _address = _addresses[i];
            // check and put to address list: amount is 0 <= new address
            if (investers[_poolIdx][_address].amount == 0) {
                investersAddress[_poolIdx].push(_address);
            }
            uint256 _amount = _amounts[i];
            if (_amount == 0) _amount = 1; // using a tiny value, will not valid to claim
            investers[_poolIdx][_address].amount = _amount;
        }
    }

    // Approve Invester
    function approveInvester(uint256 _poolIdx) internal virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");

        POOL memory pool = pools[_poolIdx]; // pool info

        // require pool is locked
        require(pool.locked, "Pool not locked");

        // check for approved amount
        uint256 _totalAmounts;
        for (uint256 i; i < investersAddress[_poolIdx].length; i++) {
            address _address = investersAddress[_poolIdx][i];
            Invester memory invester = investers[_poolIdx][_address];

            // make sure the claim less amount
            require(
                invester.claimed.mul(pool.price) <= invester.amount,
                "Invalid Amount"
            );

            if (invester.amount > 1) {
                _totalAmounts += invester.amount;
            }
        }
        require(_totalAmounts <= pool.amount, "Eceeds total amount");

        // approve
        for (uint256 i; i < investersAddress[_poolIdx].length; i++) {
            address _address = investersAddress[_poolIdx][i];
            investers[_poolIdx][_address].approved = true;
        }
    }

    // Deposit into pool - by Admin
    function deposit(uint256 _poolIdx, uint256 _amount)
        external
        payable
        onlyAdmin
    {
        require(_amount > 0, "Invalid Amount");
        require(_poolIdx < pools.length, "Pool not available");
        POOL memory pool = pools[_poolIdx]; // pool info
        require(pool.locked, "Pool not locked");
        // not allow deposit more than need
        require(
            pool.deposited.add(_amount).mul(pool.price) <= pool.amount,
            "Eceeds Pool Amount"
        );

        // transfer
        require(
            pool.token.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );

        // update total deposited token
        pools[_poolIdx].deposited += _amount;

        // emit DepositedEvent(_amount, block.timestamp);
    }

    // Claimed
    function getClaimable(uint256 _poolIdx) public view returns (uint256) {
        address _address = msg.sender;
        Invester memory invester = investers[_poolIdx][_address];
        
        if (!invester.approved) return 0;
        
        if (_poolIdx < pools.length) return 0;
        POOL memory pool = pools[_poolIdx]; // pool info
        if (!pool.locked) return 0;

        uint256 _deposited = pool.deposited;

        uint256 _tokenClaimable = invester.amount.mul(_deposited).div(
            pool.amount
        );
        return _tokenClaimable.sub(invester.claimed);
    }

    function claim(uint256 _poolIdx) public payable virtual isClaimable {
        uint256 _claimable = getClaimable(_poolIdx);
        require(_claimable > 0, "Nothing to claim");

        POOL memory pool = pools[_poolIdx]; // pool info

        // make sure not out of max
        // require(
        //     getTotalTokenForWinner(msg.sender) >=
        //         subscription[msg.sender].claimedToken + claimable[1],
        //     "Cannot claim more token than approved"
        // );
        // available claim busd
        require(
            pool.token.balanceOf(address(this)) >= _claimable,
            "Not enough token"
        );
        require(
            pool.token.transfer(msg.sender, _claimable),
            "ERC20 transfer failed - claim token"
        );
        // update claimed token
        investers[_poolIdx][msg.sender].claimed += _claimable;
    }
}
