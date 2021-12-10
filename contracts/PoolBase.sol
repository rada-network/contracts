//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";


contract PoolBase is
    Initializable,
    ContextUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    ERC20 busdToken;
    ERC20 rirToken;

    function initialize(
        address _busdAddress,
        address _rirAddress
    ) public initializer {
        __Ownable_init();
        __Pausable_init();

        busdToken = ERC20(_busdAddress);
        rirToken = ERC20(_rirAddress);

        setApprover(owner());
    }

    event PoolCreated (
        uint64 poolIndex,
        uint256 timestamp
    );


    event DepositedEvent(
        uint64 poolIndex,
        uint256 amountToken,
        uint256 timestamp
    );

    event ClaimEvent(
        uint64 poolIndex,
        uint256 amountToken,
        address indexed buyer,
        uint256 timestamp
    );



    /**
        DATA Structure
     */
    struct POOL_INFO {
        address tokenAddress;
        uint256 allocationBusd; // total allocation in $
        uint256 allocationRir; // Max allocation for RIR (in RIR count)
        uint256 minAllocationBusd; // minimum an investor must prefund
        uint256 maxAllocationBusd; // maximum an investor can prefund
        uint256 price;
        uint256 startDate;
        uint256 endDate;
        bool claimOnly; // for
        bool locked; // if locked, cannot change pool info
        string title; // readable code
    }

    struct POOL_STAT {
        uint256 depositedToken; // total deposited in Token
        uint256 amountBusd; // for paid Busd
        uint256 amountRir; // for paid RIR
        uint256 approvedBusd; // for paid Busd
        uint256 approvedRir; // for paid RIR
    }

    POOL_INFO[] public pools;
    mapping(uint64 => POOL_STAT) public poolsStat;

    struct Investor {
        uint256 amountBusd; // approved amount in $
        uint256 allocationBusd; // approved amount in $
        uint256 amountRir; // amount user prefund in RIR
        uint256 allocationRir; // approved amount in RIR
        uint256 claimedToken; // amount of Token claimed
        bool paid; // mark as paid
        bool approved; // state to make sure this investor is approved
        bool refunded; // for community pool
    }

    struct ChangeData {
        address WITHDRAW_ADDRESS;
        uint256 poolAllocationBusd;
        uint256 poolEndDate;
        address tokenAddress;
        uint64 poolIndex;
        address[] approvers;
    }

    ChangeData public requestChangeData;


    address internal WITHDRAW_ADDRESS; /* Address to cashout */

    /* Admins List, state for user */
    mapping(address => bool) public admins;
    mapping(address => bool) public approvers;
    bool claimable; // global state for all,

    uint8 internal adminCount;
    uint8 internal approverCount;


    mapping(uint256 => mapping(address => Investor)) internal investors;
    mapping(uint256 => address[]) internal investorsAddress;

    /**
        Modifiers
     */
    // Modifiers
    modifier onlyModerator() {
        require(admins[msg.sender] == true || approvers[msg.sender] == true, "Caller is not an admin");
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == owner() || admins[msg.sender] == true, "Caller is not an admin");
        _;
    }
    modifier onlyApprover() {
        require(approvers[msg.sender] == true, "Caller is not an approver");
        _;
    }
    modifier isClaimable() {
        require(claimable == true, "Claim is not available at this time.");
        _;
    }

    /* Admin role who can handle winner list, deposit token */
    function setAdmin(address _address) public onlyOwner {
        require(!admins[_address], "Already Admin");
        require(!approvers[_address], "Approver cannot be Admin");
        adminCount++;
        admins[_address] = true;
    }
    function removeAdmin(address _address) public onlyOwner {
        require(admins[_address], "Already Admin");
        adminCount--;
        admins[_address] = false;
    }

    /* Admin role who can handle winner list, deposit token */
    function setApprover(address _address) public onlyOwner {
        require(!approvers[_address], "Already Approver");
        require(!admins[_address], "Admin cannot be Approver");
        approverCount++;
        approvers[_address] = true;
    }
    function removeApprover(address _address) public onlyOwner {
        require(approvers[_address], "Already Admin");
        approverCount--;
        approvers[_address] = false;
    }
    //
    function setClaimable(bool _allow) public onlyModerator {
        claimable = _allow;
    }


    //// FOR CASHOUT ADDRESS
    /* Reject change */
    function rejectRequestChange() external virtual onlyModerator {
        // delete requestChangeData;
        delete requestChangeData;
    }

    function approveRequestChange() external virtual onlyApprover {
        // make sure not duplicate approve
        for(uint16 i; i<requestChangeData.approvers.length; i++) {
            require(requestChangeData.approvers[i] != msg.sender, "Approve already");
        }
        require(requestChangeData.WITHDRAW_ADDRESS != address(0) 
            || requestChangeData.tokenAddress != address(0) 
            || requestChangeData.poolAllocationBusd > 0 
            || requestChangeData.poolEndDate > 0,
            "No Data");
        // make approved
        requestChangeData.approvers.push(msg.sender);

        if (requestChangeData.approvers.length >= approverCount) {
            // update change data
            if (requestChangeData.WITHDRAW_ADDRESS != address(0)) {
                WITHDRAW_ADDRESS = requestChangeData.WITHDRAW_ADDRESS;
            }

            // apply change when enough agreement
            if (requestChangeData.poolAllocationBusd > 0) {
                // make sure cannot under approved allocation
                uint64 _poolIdx = requestChangeData.poolIndex;
                uint256 _totalApprovedAllocationBusd;
                for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
                    address _address = investorsAddress[_poolIdx][i];
                    Investor memory investor = investors[_poolIdx][_address];
                    if (investor.approved) {
                        _totalApprovedAllocationBusd += investor.allocationBusd;
                    }
                }
                require(_totalApprovedAllocationBusd <= requestChangeData.poolAllocationBusd, "Invalid Allocation");
                pools[requestChangeData.poolIndex].allocationBusd = requestChangeData.poolAllocationBusd;
            }

            if (requestChangeData.poolEndDate > 0) {
                pools[requestChangeData.poolIndex].endDate = requestChangeData.poolEndDate;
            }

            if (requestChangeData.tokenAddress != address(0)) {
                pools[requestChangeData.poolIndex].tokenAddress = requestChangeData.tokenAddress;
            }
            // clear change data
            delete requestChangeData;
        }
    }

    function requestChangeWithdrawAddress(address _address) external virtual onlyAdmin {
        require(WITHDRAW_ADDRESS != _address, "Same as current");
        require(address(0) != _address, "Invalid Address");
        delete requestChangeData;
        requestChangeData.WITHDRAW_ADDRESS = _address;
    }

    function requestChangePoolData(uint64 _poolIdx, uint256 _allocationBusd, uint256 _endDate, address _tokenAddress) external virtual onlyAdmin {
        require(_poolIdx < pools.length, "Pool not available");
        // pool is not locked, then can update directly
        require(pools[_poolIdx].locked, "Use update pool function please.");
        require(_allocationBusd > 0 || _endDate > 0 || _tokenAddress != address(0), "No Data");
        delete requestChangeData;
        requestChangeData.poolIndex = _poolIdx;
        if (_allocationBusd > 0) {
            requestChangeData.poolAllocationBusd = _allocationBusd;
        }
        if (_endDate > 0) {
            requestChangeData.poolEndDate = _endDate;
        }
        if (_tokenAddress != address(0)) {
            requestChangeData.tokenAddress = _tokenAddress;
        }
    }



    /**
        GETTER
     */ 
    function poolCount() external view returns (uint64) {
        return uint64(pools.length);
    }
    function getPool(uint64 _poolIdx) external view returns (POOL_INFO memory) {
        POOL_INFO memory pool;
        if (_poolIdx >= pools.length) return pool;
        return pools[_poolIdx];
    }
    function getPools() external view returns (POOL_INFO[] memory) {
        return pools;
    }
    function poolAddresses(uint64 _poolIdx) external view returns (address[] memory) {
        return investorsAddress[_poolIdx];
    }

    function getInvestor (uint64 _poolIdx, address _address) external view returns (Investor memory) {
        return investors[_poolIdx][_address];
    }

    function getWithdrawAddress() external view onlyModerator returns (address) {
        return WITHDRAW_ADDRESS;
    }
    /**
        SETTER
     */


    function updatePool(
        uint64 _poolIdx,
        uint256 _allocationBusd,
        uint256 _price,
        uint256 _startDate,
        uint256 _endDate
    ) public virtual onlyAdmin {
        require(_allocationBusd > 0, "Invalid allocationBusd");
        require(_price > 0, "Invalid Price");
        require(_poolIdx < pools.length, "Pool not available");

        POOL_INFO memory pool = pools[_poolIdx]; // pool info

        require(!pool.locked, "Pool locked");

        // do update
        if (_allocationBusd > 0) pools[_poolIdx].allocationBusd = _allocationBusd;
        if (_price > 0) pools[_poolIdx].price = _price;
        if (_startDate > 0) pools[_poolIdx].startDate = _startDate;
        if (_endDate > 0) pools[_poolIdx].endDate = _endDate;
    }

    // Lock / unlock pool - By Approver
    function lockPool(uint64 _poolIdx) public virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");
        require(!pools[_poolIdx].locked, "Pool locked");
        // Lock pool
        pools[_poolIdx].locked = true;
    }

    // to unlock, all investors need unapproved
    function unlockPool(uint64 _poolIdx) public virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");
        require(pools[_poolIdx].locked, "Pool not locked");
        // make sure no approve investor
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            Investor memory investor = investors[_poolIdx][_address];
            require(!investor.approved, "Investor approved");
        }
        // Lock pool
        pools[_poolIdx].locked = false;
    }

    
    // Add / Import Investor
    function importInvestors(
        uint64 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _amountBusds,
        uint256[] memory _allocationBusds
    ) public virtual onlyAdmin {
        require(_poolIdx < pools.length, "Pool not available");
        require(_addresses.length == _amountBusds.length, "Length not match");
        require(_addresses.length == _allocationBusds.length, "Length not match");

        POOL_INFO memory pool = pools[_poolIdx]; // pool info

        for (uint256 i; i < _addresses.length; i++) {
            Investor memory investor = investors[_poolIdx][_addresses[i]];
            require(!investor.approved, "User is already approved");
            require(
                investor.claimedToken.mul(pool.price) <= _allocationBusds[i],
                "Invalid Amount"
            );
            require(
                _allocationBusds[i] <= _amountBusds[i],
                "Invalid Amount"
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

    // Approve Investor
    function approveInvestors(uint64 _poolIdx) external virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");

        POOL_INFO memory pool = pools[_poolIdx]; // pool info

        // require pool is locked
        require(pool.locked, "Pool not locked");

        // check for approved amount
        uint256 _totalAmounts;
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            Investor memory investor = investors[_poolIdx][_address];

            // make sure the claim less amount
            require(
                investor.claimedToken.mul(pool.price) <= investor.allocationBusd,
                "Invalid Amount"
            );

            if (investor.allocationBusd > 1) {
                _totalAmounts += investor.allocationBusd;
            }
        }
        require(_totalAmounts <= pool.allocationBusd, "Eceeds total allocation");

        // approve
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            investors[_poolIdx][_address].approved = true;
        }
    }

    // unapprove investor
    function unapproveInvestor(uint64 _poolIdx, address _address) external virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");
        // require Investor approved
        Investor memory investor = investors[_poolIdx][_address];
        require(investor.approved, "Investor not approved");
        investors[_poolIdx][_address].approved = false;
    }

    // Deposit into pool - by Admin
    function deposit(uint64 _poolIdx, uint256 _amountToken)
        external
        payable
        onlyAdmin
    {
        require(_amountToken > 0, "Invalid Amount");
        require(_poolIdx < pools.length, "Pool not available");
        POOL_INFO memory pool = pools[_poolIdx]; // pool info
        require(pool.locked, "Pool not locked");
        // require token set
        require(pool.tokenAddress != address(0), "Token not set");
        // not allow deposit more than need
        require(
            poolsStat[_poolIdx].depositedToken.add(_amountToken).mul(pool.price).div(1e18) <= pool.allocationBusd,
            "Eceeds Pool Amount"
        );
        ERC20 _token = ERC20(pool.tokenAddress);
        require(
            _amountToken <= _token.balanceOf(msg.sender),
            "Not enough Token"
        );
        // transfer
        require(
            _token.transferFrom(msg.sender, address(this), _amountToken),
            "Transfer failed"
        );

        // update total deposited token
        poolsStat[_poolIdx].depositedToken += _amountToken;

        emit DepositedEvent(_poolIdx, _amountToken, block.timestamp);
    }


    /////////////////


    //////////////////
    /* FOR WITHDRAW TOKEN */


    // Claimed
    function getClaimable(uint64 _poolIdx) public view returns (uint256) {
        address _address = msg.sender;
        Investor memory investor = investors[_poolIdx][_address];
        
        if (!investor.approved) return 0; // require approved        
        if (_poolIdx >= pools.length) return 0; // pool not available

        POOL_INFO memory pool = pools[_poolIdx]; // pool info
        
        if (!pool.locked) return 0;
        if (!pool.claimOnly && !investor.paid) return 0; // require paid

        uint256 _tokenClaimable = investor.allocationBusd
                                    .mul(poolsStat[_poolIdx].depositedToken)
                                    .div(pool.allocationBusd);

        return _tokenClaimable.sub(investor.claimedToken);
    }

    function claim(uint64 _poolIdx) public payable virtual isClaimable {
        uint256 _claimable = getClaimable(_poolIdx);
        require(_claimable > 0, "Nothing to claim");

        POOL_INFO memory pool = pools[_poolIdx]; // pool info

        // available claim busd
        ERC20 _token = ERC20(pool.tokenAddress);
        require(
            _token.balanceOf(address(this)) >= _claimable,
            "Not enough token"
        );
        require(
            _token.transfer(msg.sender, _claimable),
            "ERC20 transfer failed - claim token"
        );
        // update claimed token
        investors[_poolIdx][msg.sender].claimedToken += _claimable;

        emit ClaimEvent(_poolIdx, _claimable, msg.sender, block.timestamp);
    }

}
