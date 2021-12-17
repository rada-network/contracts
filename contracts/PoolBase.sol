//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./RIRContract.sol";

import "hardhat/console.sol";

contract PoolBase is
    Initializable,
    ContextUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    ERC20 busdToken;
    RIRContract rirToken;

    function initialize(
        address _busdAddress,
        address _rirAddress
    ) public initializer {
        __Ownable_init();
        __Pausable_init();

        busdToken = ERC20(_busdAddress);
        //rirToken = ERC20(_rirAddress);
        rirToken = RIRContract(_rirAddress);

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
        bool locked; // if locked, cannot change pool info
        uint8 fee; // percentage
        string title; // readable code        
    }

    struct POOL_STAT {
        uint256 depositedToken; // total deposited in Token
        uint256 amountBusd; // for paid Busd
        uint256 amountRir; // for paid RIR
        uint256 approvedBusd; // for paid Busd
        uint256 approvedRir; // for paid RIR
        uint256 approvedCount; // 
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
        require(admins[msg.sender] == true || approvers[msg.sender] == true, "1"); // Caller is not an Moderator
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == owner() || admins[msg.sender] == true, "2"); // Caller is not an admin
        _;
    }
    modifier onlyApprover() {
        require(approvers[msg.sender] == true, "3"); // Caller is not an approver
        _;
    }
    modifier isClaimable() {
        require(claimable == true, "Unclaimable"); // Claim is not available at this time.
        _;
    }

    /* Admin role who can handle winner list, deposit token */
    function setAdmin(address _address) public onlyOwner {
        require(!admins[_address], "5"); // Already Admin
        require(!approvers[_address], "6"); // Approver cannot be Admin
        adminCount++;
        admins[_address] = true;
    }
    function removeAdmin(address _address) public onlyOwner {
        require(admins[_address], "7"); // Not an Admin
        adminCount--;
        admins[_address] = false;
    }

    /* Admin role who can handle winner list, deposit token */
    function setApprover(address _address) public onlyOwner {
        require(!approvers[_address], "8"); // Already Approver
        require(!admins[_address], "9"); // Admin cannot be Approver
        approverCount++;
        approvers[_address] = true;
    }
    function removeApprover(address _address) public onlyOwner {
        require(approvers[_address], "10"); // Not an Approver
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
            require(requestChangeData.approvers[i] != msg.sender, "11"); // Approve already
        }
        require(requestChangeData.WITHDRAW_ADDRESS != address(0) 
            || requestChangeData.tokenAddress != address(0) 
            || requestChangeData.poolAllocationBusd > 0 
            || requestChangeData.poolEndDate > 0,
            "12"); // No Data
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
                require(_totalApprovedAllocationBusd <= requestChangeData.poolAllocationBusd, "13"); // Invalid Allocation
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
        require(WITHDRAW_ADDRESS != _address, "14"); // Same as current
        require(address(0) != _address, "15"); // Invalid Address
        delete requestChangeData;
        requestChangeData.WITHDRAW_ADDRESS = _address;
    }

    function requestChangePoolData(uint64 _poolIdx, uint256 _allocationBusd, uint256 _endDate, address _tokenAddress) external virtual onlyAdmin {
        require(_poolIdx < pools.length, "16"); // Pool not available
        // pool is not locked, then can update directly
        require(pools[_poolIdx].locked, "17"); // Use update pool function please.
        require(_allocationBusd > 0 || _endDate > 0 || _tokenAddress != address(0), "18"); // No Data
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

    function getPools() external view returns (POOL_INFO[] memory) {
        return pools;
    }

    function getInvestorCount(uint64 _poolIdx) external view returns (uint) {
        return investorsAddress[_poolIdx].length;
    }
    
    // Get maximum 100 address join in a pool
    function getAddresses(uint64 _poolIdx, uint _start, uint _limit) external view returns (address[] memory) {
        uint _length = _start + _limit > investorsAddress[_poolIdx].length ? investorsAddress[_poolIdx].length - _start : _limit;        
        address[] memory _addresses = new address[](_length);
        for (uint i; i<_length; i++)
            _addresses[i] = investorsAddress[_poolIdx][i+_start];
        return _addresses;
    }
    
    // Get maximum 100 address join in a pool
    function getApprovedAddresses(uint64 _poolIdx, uint _start, uint _limit) external view returns (address[] memory) {
        uint _length = _start + _limit > poolsStat[_poolIdx].approvedCount ? poolsStat[_poolIdx].approvedCount - _start : _limit;        
        address[] memory _addresses = new address[](_length);
        uint i;
        uint j;
        while (i < investorsAddress[_poolIdx].length && j < _start + _length) {
            address _address = investorsAddress[_poolIdx][i];
            if (investors[_poolIdx][_address].approved && investors[_poolIdx][_address].allocationBusd > 0) {
                if (j >= _start) { // skip _start items
                    _addresses[j - _start] = _address;
                }
                j++;
            }
            i++;
        }

        return _addresses;
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
    // Add/update/delete Pool - by Admin
    function addPool(
        string memory _title,
        uint256 _allocationBusd,
        uint256 _minAllocationBusd,
        uint256 _maxAllocationBusd,
        uint256 _allocationRir,
        uint256 _price,
        uint256 _startDate,
        uint256 _endDate,
        uint8   _fee
    ) public virtual onlyAdmin {
        require(_allocationBusd > 0, "80"); // Invalid allocationBusd
        require(_price > 0, "81"); // Invalid Price
        require(_fee < 100, "82"); // Invalid Fee


        POOL_INFO memory pool;
        pool.allocationBusd = _allocationBusd;
        pool.minAllocationBusd = _minAllocationBusd;
        pool.maxAllocationBusd = _maxAllocationBusd;
        pool.allocationRir = _allocationRir;
        pool.price = _price;
        pool.startDate = _startDate;
        pool.endDate = _endDate;
        pool.title = _title;
        pool.fee = _fee;

        pools.push(pool);

        emit PoolCreated(uint64(pools.length-1), block.timestamp);
    }


    function updatePool(
        uint64 _poolIdx,
        uint256 _allocationBusd,
        uint256 _price,
        uint256 _startDate,
        uint256 _endDate
    ) public virtual onlyAdmin {
        require(_allocationBusd > 0, "19"); // Invalid allocationBusd
        require(_price > 0, "20"); // Invalid Price
        require(_poolIdx < pools.length, "21"); // Pool not available

        POOL_INFO memory pool = pools[_poolIdx]; // pool info

        require(!pool.locked, "22"); // Pool locked

        // do update
        if (_allocationBusd > 0) pools[_poolIdx].allocationBusd = _allocationBusd;
        if (_price > 0) pools[_poolIdx].price = _price;
        if (_startDate > 0) pools[_poolIdx].startDate = _startDate;
        if (_endDate > 0) pools[_poolIdx].endDate = _endDate;
    }

    function setToken (uint64 _poolIdx, address _tokenAddress) external virtual onlyAdmin {
        // set token first time at TGE
        require(_poolIdx < pools.length, "21"); // Pool not available
        require(pools[_poolIdx].tokenAddress == address(0), "Set already"); 
        pools[_poolIdx].tokenAddress = _tokenAddress;
    }

    // Lock / unlock pool - By Approver
    function lockPool(uint64 _poolIdx) public virtual onlyApprover {
        require(_poolIdx < pools.length, "23"); // Pool not available
        require(!pools[_poolIdx].locked, "24"); // Pool locked
        // Lock pool
        pools[_poolIdx].locked = true;
    }

    // to unlock, all investors need unapproved
    function unlockPool(uint64 _poolIdx) public virtual onlyApprover {
        require(_poolIdx < pools.length, "25"); // Pool not available
        require(pools[_poolIdx].locked, "26"); // Pool not locked
        // make sure no approve investor
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            Investor memory investor = investors[_poolIdx][_address];
            require(!investor.approved, "27"); // Investor approved
        }
        // Lock pool
        pools[_poolIdx].locked = false;
    }


    // Approve Investor
    function approveInvestors(uint64 _poolIdx) external virtual onlyApprover {
        require(_poolIdx < pools.length, "33"); // Pool not available

        POOL_INFO memory pool = pools[_poolIdx]; // pool info

        // require pool is locked
        require(pool.locked, "34"); // Pool not locked

        // check for approved amount
        uint256 _totalAllocationBusd;
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            Investor memory investor = investors[_poolIdx][_address];

            // make sure the claim less amount
            require(
                investor.claimedToken.mul(pool.price).div(1e18) <= investor.allocationBusd,
                "35" // Invalid Amount
            );

            if (investor.allocationBusd > 1) {
                _totalAllocationBusd += investor.allocationBusd;
            }
        }
        require(_totalAllocationBusd <= pool.allocationBusd, "36"); // Eceeds total allocation

        // approve
        for (uint256 i; i < investorsAddress[_poolIdx].length; i++) {
            address _address = investorsAddress[_poolIdx][i];
            investors[_poolIdx][_address].approved = true;
            if (investors[_poolIdx][_address].allocationBusd > 0) {
                poolsStat[_poolIdx].approvedCount++;
            }
        }
        
        poolsStat[_poolIdx].approvedBusd = _totalAllocationBusd;
    }

    // unapprove investor
    function unapproveInvestor(uint64 _poolIdx, address _address) external virtual onlyApprover {
        // require(_poolIdx < pools.length, "Pool not available");
        // require Investor approved
        Investor memory investor = investors[_poolIdx][_address];
        require(_poolIdx < pools.length && investor.approved, "37"); // Not approved
        investors[_poolIdx][_address].approved = false;
    }

    function getDepositAmountToken(uint64 _poolIdx, uint8 _percentage) public view returns (uint256) {
        uint256 _depositAmountBusd = getDepositAmountBusd(_poolIdx, _percentage);
        return _depositAmountBusd.div(pools[_poolIdx].price).mul(1e18);
    }

    function getDepositAmountBusd(uint64 _poolIdx, uint8 _percentage) public view returns (uint256) {
        uint256 _totalRequireDepositBusd = poolsStat[_poolIdx].approvedBusd.mul(100-pools[_poolIdx].fee).div(100); // allocation after fee
        return _totalRequireDepositBusd.mul(_percentage).div(100);
    }

    // Deposit into pool - by Admin
    function deposit(uint64 _poolIdx, uint256 _amountToken)
        external
        virtual
        onlyModerator
    {
        require(_amountToken > 0 && _poolIdx < pools.length, "38"); // Invalid Data
        //POOL_INFO memory pool = pools[_poolIdx]; // pool info
        // require token set
        require(pools[_poolIdx].locked && pools[_poolIdx].tokenAddress != address(0), "39"); // Pool not ready
        // not allow deposit more than need
        uint256 _totalDepositedValueBusd = poolsStat[_poolIdx].depositedToken.add(_amountToken).mul(pools[_poolIdx].price).div(1e18); // deposited convert to busd
        // uint256 _totalRequireDepositBusd = poolsStat[_poolIdx].approvedBusd.mul(100-pools[_poolIdx].fee).div(100); // allocation after fee
        require(
            _totalDepositedValueBusd <= getDepositAmountBusd(_poolIdx, 100),
            "40" // Eceeds Pool Amount
        );
        ERC20 _token = ERC20(pools[_poolIdx].tokenAddress);
        require(
            _amountToken <= _token.balanceOf(msg.sender),
            "41" // Not enough Token
        );
        // transfer
        require(
            _token.transferFrom(msg.sender, address(this), _amountToken),
            "42" // Transfer failed
        );

        // update total deposited token
        poolsStat[_poolIdx].depositedToken += _amountToken;

        emit DepositedEvent(_poolIdx, _amountToken, block.timestamp);
    }


    /////////////////


    //////////////////
    /* FOR WITHDRAW TOKEN */

    function getTotalClaimable (uint64 _poolIdx) public view returns (uint256) {
        if (_poolIdx >= pools.length) return 0; // pool not available

        address _address = msg.sender;
        Investor memory investor = investors[_poolIdx][_address];
        
        if (!investor.approved) return 0; // require approved        

        POOL_INFO memory pool = pools[_poolIdx]; // pool info
        
        if (!pool.locked) return 0;
        if (!investor.paid) return 0; // require paid

        uint256 _tokenClaimable = investor.allocationBusd.mul(100-pool.fee).div(100).mul(1e18).div(pool.price);

        return _tokenClaimable;
    }

    // refund 
    function getRefundable (uint64 _poolIdx) public view virtual returns (uint256, uint256) {
        if (_poolIdx >= pools.length) return (0, 0); // pool not available

        Investor memory investor = investors[_poolIdx][msg.sender];
        
        if (
            !pools[_poolIdx].locked
            || !investor.paid
            || !investor.approved
            || investor.refunded
        ) 
            return (0, 0); // require paid
        
        return (investor.amountBusd.sub(investor.allocationBusd), investor.amountRir.sub(investor.allocationRir));
    }


    // Claimed
    function getClaimable(uint64 _poolIdx) public view virtual returns (uint256) {
        if (!claimable) return 0; // not allow at the moment

        if (_poolIdx >= pools.length) return 0; // pool not available

        address _address = msg.sender;
        Investor memory investor = investors[_poolIdx][_address];
        
        if (!investor.approved) return 0; // require approved        

        // POOL_INFO memory pool = pools[_poolIdx]; // pool info
        
        if (!pools[_poolIdx].locked) return 0;
        if (!investor.paid) return 0; // require paid

        uint256 _tokenClaimable = investor.allocationBusd
                                    .mul(poolsStat[_poolIdx].depositedToken)
                                    .div(poolsStat[_poolIdx].approvedBusd);

        return _tokenClaimable.sub(investor.claimedToken);
    }

    function refund(uint64 _poolIdx) internal isClaimable {
        if (investors[_poolIdx][msg.sender].refunded == false) {
            (uint256 _busdRefundable, uint256 _rirRefundable) = getRefundable(_poolIdx);

            require( busdToken.balanceOf(address(this)) >= _busdRefundable, "Not enough BUSD" ); // Not enough Busd
            require( rirToken.balanceOf(address(this)) >= _rirRefundable, "Not enough RIR" ); // Not enough Rir

            // refunded
            investors[_poolIdx][msg.sender].refunded = true;

            if (_busdRefundable > 0) {
                require(
                    busdToken.transfer(msg.sender, _busdRefundable),
                    "Refund BUSD Failed" // ERC20 transfer failed - refund Busd
                );            
            }
            if (_rirRefundable > 0) {
                require(
                    rirToken.transfer(msg.sender, _rirRefundable),
                    "Refund RIR Failed" // ERC20 transfer failed - refund Rir
                );
            }

        }        
    }

    function claim(uint64 _poolIdx) public virtual isClaimable {

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



    ////// PROTECT URGENTCY - Withdraw anytoken to main wallet
    /* Get Back unused token to Owner */
    function removeERC20Tokens(address _tokenAddress) external onlyOwner
    {
        // Confirm tokens addresses are different from main sale one
        ERC20 erc20Token = ERC20(_tokenAddress);
        uint256 _amount = erc20Token.balanceOf(address(this));
        require (_amount > 0, "N/A");
        require(
            erc20Token.transfer(WITHDRAW_ADDRESS, _amount),
            "46" // ERC20 Token transfer failed
        );
    }

}
