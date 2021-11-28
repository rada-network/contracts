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

    /**
     * Admin role who can handle winner list, deposit token
     */
    mapping(address => bool) public admins;
    function setAdmin(address _adminAddress, bool _allow) public onlyOwner {
        admins[_adminAddress] = _allow;
    }
    modifier onlyAdmin() {
        require(admins[msg.sender] == true, "Caller is not an approved user");
        _;
    }

    modifier onlyUnwithdrawBusd() {
        require(!isWithdrawBusd, "You have withdrawn Busd");
        _;
    }
    

    bool public isCommit;
    bool public isWithdrawBusd;
    uint256 public startDate; /* Start Date  - https://www.epochconverter.com/ */
    uint256 public endDate; /* End Date - https://www.epochconverter.com/ */
    uint256 public individualMinimumAmountBusd; /* Minimum Amount Per Address */
    uint256 public individualMaximumAmountBusd; /* Minimum Amount Per Address */
    uint256 public tokenPrice; /* Token price */
    uint256 public bUSDForSale; /* Total Raising fund */
    uint256 public rate; /* 1 RIR = 100 BUSD */
    uint256 public tokenFee; /* Platform fee, token keep to platform. Should be zero */

    address public ADDRESS_WITHDRAW; /* Address to cashout */

    uint256 public bUSDAllocated; /* Total Tokens Approved */

    ERC20 public tokenAddress; /* Address of token to be sold */
    ERC20 public bUSDAddress; /* Address of bUSD */
    ERC20 public rirAddress; /* Address of RIR */

    function initialize(
        address _tokenAddress,
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
        ADDRESS_WITHDRAW = 0xdDDDbebEAD284030Ba1A59cCD99cE34e6d5f4C96; // should not change

        individualMinimumAmountBusd = _individualMinimumAmountBusd;
        individualMaximumAmountBusd = _individualMaximumAmountBusd;

        tokenAddress = ERC20(_tokenAddress); 
        // should check null for default mainnet address of busd & rir
        if (_bUSDAddress != address(0)) {
            bUSDAddress = ERC20(_bUSDAddress);
        } else {
            //bUSDAddress = 0xe9e7cea3dedca5984780bafc599bd69add087d56; // Binance-Peg BUSD Token on mainnet
        }

        if (_rirAddress != address(0)) {
            rirAddress = ERC20(_rirAddress);
        } else {
            //rirAddress = 0x30FB969AD2BFCf0f3136362cccC0bCB99a7193bC; // RIR Token on mainnet
        }

        // Grant admin role to a owner
        admins[owner()] = true;
    }

    /*
    */
    function _tokenDeduceFee(uint256 numOfToken) internal view returns (uint256) {
        if (tokenFee <= 0) return numOfToken;
        uint256 cent = 100;
        return numOfToken.mul(cent.mul(1e18) - tokenFee).div(cent.mul(1e18));
    }

    /**
     * not win fund, then need refund to subscribers
     */
    function bUSDLeft() external view returns (uint256) {
        return bUSDForSale - bUSDAllocated;
    }

    /**
     * Get List Subscribers address
     **/
    function getSubscribers() external view returns (address[] memory) {
        return subscribers;
    }

    /**
     * Get List Winners address
     **/
    function getWinners() external view returns (address[] memory) {
        return winners;
    }

    /**
     * Get Order Of Subscriber
     **/
    function getOrderSubscriber(address _address)
        external
        view
        returns (Order memory)
    {
        return subscription[_address];
    }

    /**
        GETTER 
     */
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

    /**
     * Set Wins is empty
     **/
    function setEmptyWins() external onlyOwner onlyUncommit {
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

    /**
     * Import Winners
     **/
    function importWinners(
        address[] calldata _address,
        uint256[] calldata _approvedBusd
    ) external virtual onlyOwner winEmpty {
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

    function commitWinners() external payable virtual onlyOwner onlyUncommit {
        // make sure winners list available
        require(winners.length > 0 && winCount() > 0, "No winner");

        // every thing need to be check are checked when import
        require(isCommit = true);
    }

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

    function isBuyerHasRIR(address buyer) external view returns (bool) {
        return rirAddress.balanceOf(buyer) > 0;
    }


    /**
     * Create Subscription
     */
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

    /*
    /* Deposit Token,
     * Call by admin
    */
    function deposit(uint256 _amount) external payable onlyOwner {
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
        uint256 _deposited =  totalTokenDeposited;
        uint256 _maxDeposited = getTotalTokenForSale();
        if (_deposited > _maxDeposited) _deposited = _maxDeposited; // cannot eceeds total sale token

        uint256 _tokenClaimable = _order.approvedBUSD.mul(_deposited).div(bUSDForSale);
        claimable[1] = _tokenClaimable.sub(_order.claimedToken);
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
        if (claimable[1] > 0) {
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

    /* Admin Withdraw BUSD */
    function withdrawBusdFunds() external virtual onlyOwner onlyCommit onlyUnwithdrawBusd {
        uint256 _balanceBusd = getTotalBusdWinners();
        require(
            bUSDAddress.transfer(ADDRESS_WITHDRAW, _balanceBusd),
            "ERC20 Cannot withdraw fund"
        );
        isWithdrawBusd = true;
    }

    function getTotalBusdWinners() internal view returns (uint256) {
        return bUSDAllocated;
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

    function withdrawUnsoldTokens() external payable onlyOwner onlyCommit {
        uint256 _remain = getUnsoldTokens();
        require(_remain > 0, "No remain token");
        require(tokenAddress.transfer(ADDRESS_WITHDRAW, _remain), "ERC20 Cannot widthraw remaining token");
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

    function removeOtherERC20Tokens(address _tokenAddress, address _to)
        external
        onlyOwner
    {
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
            erc20Token.transfer(_to, erc20Token.balanceOf(address(this))),
            "ERC20 Token transfer failed"
        );
    }
}
