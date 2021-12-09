//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract WhitelistPools is
    Initializable,
    ContextUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    event PaymentEvent(
        uint poolIndex,
        uint256 amountBUSD,
        address indexed buyer,
        uint256 timestamp
    );

    event DepositedEvent(
        uint poolIndex,
        uint256 amountToken,
        uint256 timestamp
    );

    event ClaimEvent(
        uint poolIndex,
        uint256 amountToken,
        address indexed buyer,
        uint256 timestamp
    );


    function initialize(
        /* address _tokenAddress, */ // Will setup later, not available at the Pool start
        address _bUSDAddress
    ) public initializer {
        __Ownable_init();
        __Pausable_init();

        busdToken = ERC20(_bUSDAddress);

        setApprover(owner());
    }



    /**
        DATA Structure
     */
    struct POOL {
        ERC20 token;
        uint256 allocationBusd; // total allocation in $
        uint256 price;
        uint256 depositedToken; // total deposited in Token
        uint256 startDate;
        uint256 endDate;

        uint256 paidAmount; // for paid

        bool claimOnly; // for
        bool locked; // if locked, cannot change pool info
    }

    POOL[] public pools;

    struct Investor {
        uint256 amountBusd; // approved amount in $
        uint256 allocationBusd; // approved amount in $
        uint256 claimedToken; // amount of Token claimed
        bool paid; // mark as paid
        bool approved; // state to make sure this investor is approved
    }

    struct ChangeData {
        address WITHDRAW_ADDRESS;
        uint256 poolAllocationBusd;
        uint256 poolEndDate;
        address tokenAddress;
        uint128 poolIndex;
        uint128 approvalCount;
        mapping (address => bool) approvers;
    }

    ChangeData private requestChangeData;


    ERC20 busdToken;
    address private WITHDRAW_ADDRESS; /* Address to cashout */

    /* Admins List, state for user */
    mapping(address => bool) public admins;
    mapping(address => bool) public approvers;
    bool claimable; // global state for all,

    uint8 private adminCount;
    uint8 private approverCount;


    mapping(uint256 => mapping(address => Investor)) private investors;
    mapping(uint256 => address[]) private investorsAddress;

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
        delete requestChangeData;
    }

    function approveRequestChange() external virtual onlyApprover {
        // make sure not duplicate approve
        require(!requestChangeData.approvers[msg.sender], "Approve already");
        require(requestChangeData.WITHDRAW_ADDRESS != address(0) || requestChangeData.poolAllocationBusd > 0 || requestChangeData.poolEndDate > 0, "No Data");
        // make approved
        requestChangeData.approvalCount++;
        requestChangeData.approvers[msg.sender] = true;

        if (requestChangeData.approvalCount >= approverCount) {
            // update change data
            if (requestChangeData.WITHDRAW_ADDRESS != address(0)) {
                WITHDRAW_ADDRESS = requestChangeData.WITHDRAW_ADDRESS;
            }

            // apply change when enough agreement
            if (requestChangeData.poolAllocationBusd > 0) {
                // make sure cannot under approved allocation
                uint _poolIdx = requestChangeData.poolIndex;
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
                pools[requestChangeData.poolIndex].token = ERC20(requestChangeData.tokenAddress);
            }
            // clear change data
            delete requestChangeData;
        }
    }

    function requestChangeWithdrawAddress(address _address) external virtual onlyAdmin {
        require(WITHDRAW_ADDRESS != _address, "Same as current");
        delete requestChangeData;
        requestChangeData.WITHDRAW_ADDRESS = _address;
    }

    function requestChangePoolData(uint128 _poolIdx, uint256 _allocationBusd, uint256 _endDate, address _tokenAddress) external virtual onlyAdmin {
        require(_poolIdx < pools.length, "Pool not available");
        // pool is not locked, then can update directly
        require(pools[_poolIdx].locked, "Use update pool function please.");
        require(_allocationBusd > 0 || _endDate > 0, "No Data");
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
    function poolCount() external view returns (uint) {
        return pools.length;
    }

    function poolAddresses(uint _poolIdx) external view returns (address[] memory) {
        return investorsAddress[_poolIdx];
    }

    function getInvestor (uint _poolIdx, address _address) external view returns (Investor memory) {
        return investors[_poolIdx][_address];
    }

    /**
        SETTER
     */

    // Add/update/delete Pool - by Admin
    function addClaimOnlyPool(
        address _tokenAddress,
        uint256 _allocationBusd,
        uint256 _price
    ) public virtual onlyAdmin {
        require(_allocationBusd > 0, "Invalid allocationBusd");
        require(_price > 0, "Invalid Price");

        POOL memory pool;
        pool.token = ERC20(_tokenAddress);
        pool.allocationBusd = _allocationBusd;
        pool.price = _price;
        pool.claimOnly = true;

        pools.push(pool);
    }

    function addPayablePool(
        uint256 _allocationBusd,
        uint256 _price,
        uint256 _startDate,
        uint256 _endDate
    ) public virtual onlyAdmin {
        require(_allocationBusd > 0, "Invalid allocationBusd");
        require(_price > 0, "Invalid Price");

        POOL memory pool;
        pool.allocationBusd = _allocationBusd;
        pool.price = _price;
        pool.startDate = _startDate;
        pool.endDate = _endDate;

        pools.push(pool);
    }

    function updatePool(
        uint256 _poolIdx,
        uint256 _allocationBusd,
        uint256 _price,
        uint256 _startDate,
        uint256 _endDate
    ) public virtual onlyAdmin {
        require(_allocationBusd > 0, "Invalid allocationBusd");
        require(_price > 0, "Invalid Price");
        require(_poolIdx < pools.length, "Pool not available");

        POOL memory pool = pools[_poolIdx]; // pool info

        require(!pool.locked, "Pool locked");

        // do update
        if (_allocationBusd > 0) pools[_poolIdx].allocationBusd = _allocationBusd;
        if (_price > 0) pools[_poolIdx].price = _price;
        if (_startDate > 0) pools[_poolIdx].startDate = _startDate;
        if (_endDate > 0) pools[_poolIdx].endDate = _endDate;
    }

    // Lock / unlock pool - By Approver
    function lockPool(uint256 _poolIdx) public virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");
        require(!pools[_poolIdx].locked, "Pool locked");
        // Lock pool
        pools[_poolIdx].locked = true;
    }

    // to unlock, all investors need unapproved
    function unlockPool(uint256 _poolIdx) public virtual onlyApprover {
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
    function importInvestor(
        uint256 _poolIdx,
        address[] memory _addresses,
        uint256[] memory _amountBusds,
        uint256[] memory _allocationBusds
    ) public virtual onlyAdmin {
        require(_poolIdx < pools.length, "Pool not available");
        require(_addresses.length == _amountBusds.length, "Length not match");

        POOL memory pool = pools[_poolIdx]; // pool info

        for (uint256 i; i < _addresses.length; i++) {
            Investor memory investor = investors[_poolIdx][_addresses[i]];
            require(!investor.approved, "User is already approved");
            require(
                investor.claimedToken.mul(pool.price) <= _amountBusds[i],
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
    function approveInvestors(uint256 _poolIdx) external virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");

        POOL memory pool = pools[_poolIdx]; // pool info

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
        require(_totalAmounts <= pool.allocationBusd, "Eceeds total amount");

        // approve
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            investors[_poolIdx][_address].approved = true;
        }
    }

    // unapprove investor
    function unapproveInvestor(uint256 _poolIdx, address _address) external virtual onlyApprover {
        require(_poolIdx < pools.length, "Pool not available");
        // require Investor approved
        Investor memory investor = investors[_poolIdx][_address];
        require(investor.approved, "Investor not approved");
        investors[_poolIdx][_address].approved = false;
    }

    // Deposit into pool - by Admin
    function deposit(uint256 _poolIdx, uint256 _amountToken)
        external
        payable
        onlyAdmin
    {
        require(_amountToken > 0, "Invalid Amount");
        require(_poolIdx < pools.length, "Pool not available");
        POOL memory pool = pools[_poolIdx]; // pool info
        require(pool.locked, "Pool not locked");
        // not allow deposit more than need
        require(
            pool.depositedToken.add(_amountToken).mul(pool.price) <= pool.allocationBusd,
            "Eceeds Pool Amount"
        );

        // transfer
        require(
            pool.token.transferFrom(msg.sender, address(this), _amountToken),
            "Transfer failed"
        );

        // update total deposited token
        pools[_poolIdx].depositedToken += _amountToken;

        emit DepositedEvent(_poolIdx, _amountToken, block.timestamp);
    }

    // Claimed
    function getClaimable(uint256 _poolIdx) public view returns (uint256) {
        address _address = msg.sender;
        Investor memory investor = investors[_poolIdx][_address];
        
        if (!investor.approved) return 0; // require approved
        
        if (_poolIdx < pools.length) return 0;
        POOL memory pool = pools[_poolIdx]; // pool info
        if (!pool.locked) return 0;

        if (!pool.claimOnly && !investor.paid) return 0; // require paid

        uint256 _deposited = pool.depositedToken;

        uint256 _tokenClaimable = investor.allocationBusd.mul(_deposited).div(
            pool.allocationBusd
        );
        return _tokenClaimable.sub(investor.claimedToken);
    }

    function claim(uint256 _poolIdx) public payable virtual isClaimable {
        uint256 _claimable = getClaimable(_poolIdx);
        require(_claimable > 0, "Nothing to claim");

        POOL memory pool = pools[_poolIdx]; // pool info

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
        investors[_poolIdx][msg.sender].claimedToken += _claimable;

        emit ClaimEvent(_poolIdx, _claimable, msg.sender, block.timestamp);
    }


    /////////////////

    /* Make a payment */
    function makePayment(
        uint _poolIdx
    ) public payable virtual {
        address _address = msg.sender;
        Investor memory investor = investors[_poolIdx][_address];
        require(investor.approved, "Not allow to join");
        require(investor.paid, "Paid already");
        require(investor.amountBusd > 1, "Not allow to join pool");
        
        // check pool
        require(_poolIdx < pools.length, "Pool not available");
        POOL memory pool = pools[_poolIdx]; // pool info
        require(!pool.claimOnly, "Not require payment");
        require(pool.locked, "Pool not active");

        // require project is open and not expire
        require(block.timestamp <= pool.endDate, "The Pool has been expired");
        require(block.timestamp >= pool.startDate, "The Pool have not started");
        require(WITHDRAW_ADDRESS != address(0), "Not Ready for payment");

        require(
            busdToken.balanceOf(msg.sender) >= investor.amountBusd,
            "Not enough BUSD"
        );

        require(
            busdToken.transferFrom(msg.sender, WITHDRAW_ADDRESS, investor.amountBusd),
            "Payment failed"
        );

        investors[_poolIdx][_address].paid = true;

        // update total RIR
        pools[_poolIdx].paidAmount += investor.amountBusd;
        
        emit PaymentEvent(
            _poolIdx,
            investor.amountBusd,
            msg.sender,
            block.timestamp
        );
    }



    //////////////////
    /* FOR WITHDRAW TOKEN */



}
