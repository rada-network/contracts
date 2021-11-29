//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract LaunchVerse is
    Initializable,
    ContextUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    struct Order {
        uint256 amountRIR;
        uint256 amountBUSD;
        address referer;
        uint256 approvedBUSD;
        uint256 refundedBUSD;
        uint256 claimedToken;
    }


    // List of subscriber who prefund to Pool
    mapping(address => Order) public subscription; 
    address[] public subscribers;
    uint256 public totalSubBUSD;
    uint256 public totalSubRIR;
    function subscriptionCount() public view returns (uint) {
        return subscribers.length;
    }

    // List of winner address and count
    address[] public winners;
    function winCount() public view returns (uint) {
        return winners.length;
    }

    // deposited token
    uint256 public totalTokenDeposited;

    event DepositEvent(
        uint256 amount,
        uint256 timestamp
    );

    event SubscriptionEvent(
        uint256 amountRIR,
        uint256 amountBUSD,
        address indexed referer,
        address indexed buyer,
        uint256 timestamp
    );

    uint256 public startDate; /* Start Date  - https://www.epochconverter.com/ */
    uint256 public endDate; /* End Date - https://www.epochconverter.com/ */
    uint256 public individualMinimumAmountBusd; /* Minimum Amount Per Address */
    uint256 public individualMaximumAmountBusd; /* Minimum Amount Per Address */
    uint256 public tokenPrice; /* Token price */
    uint256 public bUSDForSale; /* Total Raising fund */
    uint256 public rate; /* 1 RIR = 100 BUSD */
    uint256 public tokenFee; /* Platform fee, token keep to platform. Should be zero */

    uint256 public totalRIRAllocation; /* Maximum RIR can be used for all, by default is 80% of sale allocation */

    address public WITHDRAW_ADDRESS; /* Address to cashout */

    uint256 public bUSDAllocated; /* Total Tokens Approved */

    ERC20 public tokenAddress; /* Address of token to be sold */
    ERC20 public bUSDAddress; /* Address of bUSD */
    ERC20 public rirAddress; /* Address of RIR */

    
    /* Admins List */
    mapping(address => bool) public admins;

    /* State variables */
    bool private isTokenAddressSet;
    bool public isCommit;
    bool public isWithdrawBusd;
    bool public isWithdrawAddressSet;



    function initialize(
        /* address _tokenAddress, */ // Will setup later, not available at the Pool start
        address _bUSDAddress,
        address _rirAddress,
        uint256 _tokenPrice, // Price Token (Ex: 1 TOKEN = 0.01 BUSD)
        uint256 _bUSDForSale,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _individualMinimumAmountBusd,
        uint256 _individualMaximumAmountBusd,
        uint256 _tokenFee
    ) public initializer {
        __Ownable_init();
        __Pausable_init();

        require(_startDate < _endDate, "End Date higher than Start Date");

        require(_tokenPrice > 0, "Price token of project should be > 0");

        require(_bUSDForSale > 0, "BUSD for Sale should be > 0");

        require(
            _individualMinimumAmountBusd > 0,
            "Individual Minimum Amount Busd should be > 0"
        );

        require(
            _individualMaximumAmountBusd > 0,
            "Individual Maximim Amount Busd should be > 0"
        );

        require(
            _individualMaximumAmountBusd >= _individualMinimumAmountBusd,
            "Individual Maximim Amount should be > Individual Minimum Amount"
        );

        require(_bUSDForSale >= _individualMinimumAmountBusd);

        startDate = _startDate;
        endDate = _endDate;
        bUSDForSale = _bUSDForSale;
        tokenPrice = _tokenPrice;
        bUSDAllocated = 0;
        rate = 100;
        tokenFee = _tokenFee;
        isCommit = false;
        
        // for widthdraw BUSD
        isWithdrawBusd = false;
        // WITHDRAW_ADDRESS = 0xdDDDbebEAD284030Ba1A59cCD99cE34e6d5f4C96; // should not change

        individualMinimumAmountBusd = _individualMinimumAmountBusd;
        individualMaximumAmountBusd = _individualMaximumAmountBusd;

        // tokenAddress = ERC20(_tokenAddress); // 
        bUSDAddress = ERC20(_bUSDAddress);
        rirAddress = ERC20(_rirAddress);

        // Default total RIR allocation: 80% of sale allocation
        totalRIRAllocation = bUSDForSale.div(rate).mul(80).div(100);

        // Grant admin role to a owner
        admins[owner()] = true;
    }


    /**
     * MODIFIERS
     */
    modifier winEmpty() {
        require(winners.length == 0, "Wins need empty");
        require(winCount() == 0, "Wins need empty");
        _;
    }

    modifier onlyUncommit() {
        require(!isCommit, "Wins is verifyed");
        _;
    }

    modifier onlyCommit() {
        require(isCommit, "Wins not verifyed");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender] == true, "Caller is not an approved user");
        _;
    }

    modifier onlyUnwithdrawBusd() {
        require(!isWithdrawBusd, "You have withdrawn Busd");
        _;
    }

    /* State for setup Token Address */
    modifier onlyTokenNotSet() {
        require(!isTokenAddressSet, "Token Address has set already");
        _;
    }
    modifier onlyTokenSet() {
        require(isTokenAddressSet, "Token Address has not set");
        _;
    }
    
    /* State for setup WITHDRAW Address */
    modifier onlyWithdrawAddressNotSet() {
        require(!isWithdrawAddressSet, "Token Address has set already");
        _;
    }
    modifier onlyWithdrawAddressSet() {
        require(isWithdrawAddressSet, "Token Address has not set");
        _;
    }
    


    /*
     * INTERNAL Funtions
    */
    function _tokenDeduceFee(uint256 numOfToken) internal view returns (uint256) {
        if (tokenFee <= 0) return numOfToken;
        uint256 cent = 100;
        return numOfToken.mul(cent.mul(1e18) - tokenFee).div(cent.mul(1e18));
    }

    /* Check if all RIR prefunders in Winner List */
    function verifySubWinnerHasRIR() internal view returns (bool) {
        bool _isVerify = true;
        for (uint256 i = 0; i < subscribers.length; i++) {
            address _subscriber = subscribers[i];
            Order memory _order = subscription[_subscriber];
            if (_order.amountRIR > 0) {
                if (!this.isWinner(_subscriber)) {
                    _isVerify = false;
                }
            }
        }
        return _isVerify;
    }

    /**
     *   GETTER Functions
     */
    
    /* not win fund, then need refund to subscribers */
    function bUSDLeft() external view returns (uint256) {
        return bUSDForSale - bUSDAllocated;
    }

    /* Get List Subscribers address */
    function getSubscribers() external view returns (address[] memory) {
        return subscribers;
    }

    /* Get List Winners address */
    function getWinners() external view returns (address[] memory) {
        return winners;
    }

    /* Get Order Of Subscriber */
    function getOrderSubscriber(address _address)
        external
        view
        returns (Order memory)
    {
        return subscription[_address];
    }

    function minimumAmountBusd() public view returns (uint256) {
        return individualMinimumAmountBusd;
    }
    function maximumAmountBusd() public view returns (uint256) {
        return individualMaximumAmountBusd;
    }
    function getTotalTokenForSale() public view returns (uint256) {
        return _tokenDeduceFee(bUSDForSale.div(tokenPrice).mul(1e18));
    }
    function getTotalTokenSold() public view returns (uint256) {
        return _tokenDeduceFee(bUSDAllocated.div(tokenPrice).mul(1e18));
    }

    /**
     * Check Buyer is Subscriber - just check in the subscription list
     **/
    function isSubscriber(address _address) external view returns (bool) {
        return subscription[_address].amountBUSD != 0;
    }

    /**
     * Check Buyer is Winner - just check in the winners list
     **/
    function isWinner(address _address) external view returns (bool) {
        return subscription[_address].approvedBUSD > 0;
    }

    function isBuyerHasRIR(address buyer) external view returns (bool) {
        return rirAddress.balanceOf(buyer) > 0;
    }

    function getTotalBusdWinners() internal view returns (uint256) {
        return bUSDAllocated;
    }

    function balanceTokens() public view returns (uint256) {
        return tokenAddress.balanceOf(address(this));
    }

    function balanceBusd() external view returns (uint256) {
        return bUSDAddress.balanceOf(address(this));
    }

    function balanceRIR() external view returns (uint256) {
        return rirAddress.balanceOf(address(this));
    }


    /**
     * MAIN Functions
     */
    
    /* Create Subscription */
    function createSubscription(
        uint256 _amountBusd,
        uint256 _amountRIR,
        address _referer
    ) public payable virtual {

        // require project is open and not expire
        require(block.timestamp <= endDate, "The Pool has been expired");
        require(block.timestamp >= startDate, "The Pool have not started");

        // amount cannot be negative
        require(_amountBusd >= 0, "Amount BUSD is not valid");
        require(_amountRIR >= 0, "Amount RIR is not valid");
        // and at least one is positive
        require(_amountBusd > 0 || _amountRIR > 0, "Amount is not valid");

        // cannot out of bound 
        require(
            maximumAmountBusd() >=
                subscription[msg.sender].amountBUSD + _amountBusd,
            "Amount is overcome maximum"
        );
        require(
            minimumAmountBusd() <=
                subscription[msg.sender].amountBUSD + _amountBusd,
            "Amount is overcome minimum"
        );

        if (!this.isSubscriber(msg.sender)) {
            // first time, need add to subscribers address list and count
            // do we need check and init subscription[msg.sender] = Order ?
            subscribers.push(msg.sender);
        }

        if (_amountRIR > 0) {
            require(
                rirAddress.balanceOf(msg.sender) >= _amountRIR,
                "You dont have enough RIR Token"
            );

            // check if over RIR allocation fill
            require(
                totalSubRIR + _amountRIR <= totalRIRAllocation,
                "Eceeds Total RIR Allocation"
            );

            // Prevent misunderstanding: only RIR is enough
            // (_amountRIR + subscription[msg.sender].amountRIR).mul(rate) <= need include prefunded RIR
            require(
                subscription[msg.sender].amountRIR.add(_amountRIR).mul(rate) <=
                    subscription[msg.sender].amountBUSD + _amountBusd,
                "Amount is not valid"
            );

            require(
                rirAddress.transferFrom(msg.sender, address(this), _amountRIR),
                "RIR transfer failed"
            );

            subscription[msg.sender].amountRIR += _amountRIR;
            // update total RIR
            totalSubRIR += _amountRIR;
        }

        if (_amountBusd > 0) {
            require(
                bUSDAddress.transferFrom(
                    msg.sender,
                    address(this),
                    _amountBusd
                ),
                "Transfer BUSD fail"
            );

            subscription[msg.sender].amountBUSD += _amountBusd;
            // update total
            totalSubBUSD += _amountBusd;
        }

        // check referer if not set
        if (_referer != address(0) && subscription[msg.sender].referer == address(0)) {
            subscription[msg.sender].referer = _referer;
        }

        emit SubscriptionEvent(
            _amountRIR,
            _amountBusd,
            _referer,
            msg.sender,
            block.timestamp
        );
    }


    /**
        Claim totken
     */
    function getTotalTokenForWinner(address _winner) public view returns (uint256)  {
        Order memory _winnerOrder = subscription[_winner];
        return _winnerOrder.approvedBUSD.mul(getTotalTokenForSale()).div(bUSDForSale);
    }
    
    function getClaimable(address _address) public view returns (uint256[2] memory) {
        uint256[2] memory claimable;
        Order memory _order = subscription[_address];
        // check if available busd to refund
        claimable[0] = _order.amountBUSD - _order.approvedBUSD - _order.refundedBUSD;

        // check if available token to claim
        if (isTokenAddressSet) {
            uint256 _deposited =  totalTokenDeposited;
            uint256 _maxDeposited = getTotalTokenForSale();
            if (_deposited > _maxDeposited) _deposited = _maxDeposited; // cannot eceeds total sale token

            uint256 _tokenClaimable = _order.approvedBUSD.mul(_deposited).div(bUSDForSale);
            claimable[1] = _tokenClaimable.sub(_order.claimedToken);
        }
        return claimable;
    }

    function claim() external payable onlyCommit {
        uint256[2] memory claimable = getClaimable(msg.sender);
        if (claimable[0] > 0) {
            require(bUSDAddress.balanceOf(address(this)) >= claimable[0], "BUSD Not enough");
            // available claim busd
            require(
                bUSDAddress.transfer(msg.sender, claimable[0]),
                "ERC20 transfer failed - claim refund"
            );

            // update refunded
            subscription[msg.sender].refundedBUSD = claimable[0];
        }
        if (isTokenAddressSet && claimable[1] > 0) {
            // make sure not out of max
            require(getTotalTokenForWinner(msg.sender) >= subscription[msg.sender].claimedToken + claimable[1], "Cannot claim more token than approved");
            // available claim busd
            require(tokenAddress.balanceOf(address(this)) >= claimable[1], "Not enough token");
            require(
                tokenAddress.transfer(msg.sender, claimable[1]),
                "ERC20 transfer failed - claim token"
            );
            // update claimed token
            subscription[msg.sender].claimedToken += claimable[1];
        }
    }


    /**
     * ADMIN FUNCTIONS
     */
    /*
    /* Deposit Token by admin
    */
    function deposit(uint256 _amount) external payable onlyTokenSet onlyAdmin {
        require(_amount > 0, "Amount has to be positive");
        require(
            tokenAddress.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );

        // update total deposited token
        totalTokenDeposited += _amount;

        emit DepositEvent(_amount, block.timestamp);
    }

    /**
     * Import Winners by Admin
     **/
    function importWinners(
        address[] calldata _address,
        uint256[] calldata _approvedBusd
    ) external virtual onlyAdmin winEmpty {
        uint256 _bUSDAllocated = 0;

        for (uint256 i = 0; i < _address.length; i++) {
            _bUSDAllocated += _approvedBusd[i];

            // should put buyer address into error message
            require(this.isSubscriber(_address[i]), "Buyer is not subscriber");

            require(
                !this.isWinner(_address[i]),
                "Buyer already exists in the list"
            );

            require(_approvedBusd[i] > 0, "Amount has to be positive");

            // need require less than his prefund amount
            require(
                _approvedBusd[i] <= subscription[_address[i]].amountBUSD,
                "Approved BUSD exceed the amount for a buyer"
            );

            // update approveBUSD
            subscription[_address[i]].approvedBUSD = _approvedBusd[i];

            // push into winners list address and increase count
            winners.push(_address[i]);
        }

        require(
            bUSDForSale >= _bUSDAllocated,
            "Approved BUSD exceed the amount for sale"
        );

        // check if all RIR holder are in winners list
        require(verifySubWinnerHasRIR(), "Some RIR investers are not in winners list");

        // make sure maximize total approved
        if (totalSubBUSD >= bUSDForSale) {
            // oversub, then the approved amount need full
            require(_bUSDAllocated == bUSDForSale, "Sale is not fullfill");
        } else {
            // sub less than tota raising, fullfill all sub
            require(_bUSDAllocated == totalSubBUSD, "Sub is not fullfill");
        }

        // update bUSDAllocated
        bUSDAllocated = _bUSDAllocated;
    }

    /**
     * Reset Winner List to make new Import
     **/
    function setEmptyWins() external onlyAdmin onlyUncommit {
        require(winCount() > 0);
        require(winners.length > 0);
        for (uint256 i = 0; i < subscribers.length; i++) {
            address _address = subscribers[i];
            // just reset approvedBUSD
            if (subscription[_address].approvedBUSD != 0) {
                subscription[_address].approvedBUSD = 0;
            }
        }

        // reset winners and allocated
        delete winners;
        delete bUSDAllocated;
    }

    /* Setup Token Address */
    function setTokenAddress(address _tokenAddress) external onlyTokenNotSet onlyAdmin {
        tokenAddress = ERC20(_tokenAddress); 
    }
    /* Setup Token Address */
    function setWithdrawAddress(address _withdrawAddress) external onlyWithdrawAddressNotSet onlyAdmin {
        WITHDRAW_ADDRESS = _withdrawAddress;
    }


    /**
     * OWNER FUNCTIONS
     */

    /* Admin role who can handle winner list, deposit token */
    function setAdmin(address _adminAddress, bool _allow) public onlyOwner {
        admins[_adminAddress] = _allow;
    }    

    /* 
    /* Admin withdraw token remain
    /* require total token deposit > total token of winners
    */
    function getUnsoldTokens() public view onlyOwner onlyCommit returns (uint256) {
        // get total claimed token
        uint256 _totalClaimedToken;
        for (uint256 i = 0; i < subscribers.length; i++) {
            _totalClaimedToken += subscription[subscribers[i]].claimedToken;
        }
        uint256 _tokenBalance = balanceTokens();
        uint256 _remain = _tokenBalance.add(_totalClaimedToken).sub(getTotalTokenSold());
        return _remain > 0 ? _remain : 0;
    }

    function withdrawUnsoldTokens() external payable onlyOwner onlyCommit onlyTokenSet onlyWithdrawAddressSet {
        uint256 _remain = getUnsoldTokens();
        require(_remain > 0, "No remain token");
        require(tokenAddress.transfer(WITHDRAW_ADDRESS, _remain), "ERC20 Cannot widthraw remaining token");
    }

    /* Admin Withdraw BUSD */
    function withdrawBusdFunds() external virtual onlyOwner onlyCommit onlyUnwithdrawBusd onlyWithdrawAddressSet {
        uint256 _balanceBusd = getTotalBusdWinners();
        require(
            bUSDAddress.transfer(WITHDRAW_ADDRESS, _balanceBusd),
            "ERC20 Cannot withdraw fund"
        );
        isWithdrawBusd = true;
    }

    /* Get Back unused token to Owner */
    function removeOtherERC20Tokens(address _tokenAddress) external onlyOwner
    {
        require(
            _tokenAddress != address(bUSDAddress),
            "Cannot remove BUSD"
        );

        require(
            _tokenAddress != address(tokenAddress),
            "Token Address has to be diff than the erc20 subject to sale"
        );

        require(
            _tokenAddress != address(rirAddress),
            "Token Address has to be diff than the erc20 subject to sale"
        );
        // Confirm tokens addresses are different from main sale one
        ERC20 erc20Token = ERC20(_tokenAddress);
        require(
            erc20Token.transfer(WITHDRAW_ADDRESS, erc20Token.balanceOf(address(this))),
            "ERC20 Token transfer failed"
        );
    }


    /* After Admin import WinnerList, make a verification and Owner will commit the WinnerList */
    /* After WinnerList is committed, the List cannot be changed */
    function commitWinners() external payable virtual onlyOwner onlyUncommit {
        // make sure winners list available
        require(winners.length > 0 && winCount() > 0, "No winner");

        // every thing need to be check are checked when import
        require(isCommit = true);
    }

    /* Not allow change Pool Token Address later */
    function commitTokenAddress() external onlyTokenNotSet onlyOwner {
        isTokenAddressSet = true; 
    }

    /* Not allow change Pool Token Address later */
    function commitWithdrawAddress() external onlyWithdrawAddressNotSet onlyOwner {
        isWithdrawAddressSet = true; 
    }

    /**
     * UPDATE Total RIR Allocation - by default is 80% of all allocation
     */
    function updateRIRAllocation(uint percentage) external onlyOwner {
        totalRIRAllocation = bUSDForSale.div(rate).mul(percentage).div(100);
    }

}
