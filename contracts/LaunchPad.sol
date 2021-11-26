//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract LaunchPad is
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
    }

    struct Wallet {
        uint256[] amountToken;
        uint256 amountBUSD;
    }

    mapping(address => Order) public subscription;
    uint256 public subscriptionCount;
    address[] public subscribers;

    mapping(address => Order) public wins;
    uint256 public winCount;
    address[] public winners;

    mapping(address => Wallet) public wallets;
    uint256 public buyersCount;
    address[] public buyers;

    uint256[] public depositTokens;

    event DepositEvent(
        uint256 amount,
        address indexed depositor,
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
        require(winCount == 0, "Wins need empty");
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

    bool public isCommit;
    uint256 public startDate; /* Start Date  - https://www.epochconverter.com/ */
    uint256 public endDate; /* End Date - https://www.epochconverter.com/ */
    uint256 public individualMinimumAmountBusd; /* Minimum Amount Per Address */
    uint256 public individualMaximumAmountBusd; /* Minimum Amount Per Address */
    uint256 public tokenPrice; /* Gia token theo USD */
    uint256 public bUSDAllocated; /* Tokens Allocated */
    uint256 public bUSDForSale; /* Tokens for Sale */
    uint256 public rate; /* 1 RIR = 100 BUSD */
    uint256 public feeTax;
    bool public unsoldTokensReedemed;
    address public ADDRESS_WITHDRAW;

    ERC20 public tokenAddress;
    ERC20 public bUSDAddress;
    ERC20 public rirAddress;

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
        uint256 _feeTax
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        //        require(
        //            block.timestamp < _endDate,
        //            "End Date should be further than current date"
        //        );

        //        require(
        //            block.timestamp < _startDate,
        //            "Start Date should be further than current date"
        //        );

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
        subscriptionCount = 0;
        winCount = 0;
        rate = 100;
        feeTax = _feeTax;
        unsoldTokensReedemed = false;
        isCommit = false;
        ADDRESS_WITHDRAW = 0x128392d27439F0E76b3612E9B94f5E9C072d74e0;
        individualMinimumAmountBusd = _individualMinimumAmountBusd;
        individualMaximumAmountBusd = _individualMaximumAmountBusd;

        tokenAddress = ERC20(_tokenAddress);
        bUSDAddress = ERC20(_bUSDAddress);
        rirAddress = ERC20(_rirAddress);
    }

    function bUSDLeft() external view returns (uint256) {
        return bUSDForSale - bUSDAllocated;
    }

    /**
     * Get List Subscribers
     **/
    function getSubscribers() external view returns (address[] memory) {
        return subscribers;
    }

    /**
     * Get List Winners
     **/
    function getWinners() external view returns (address[] memory) {
        return winners;
    }

    /**
     * Get Order Of Subscriber
     **/
    function getOrderSubscriber(address _buyer)
    external
    view
    returns (Order memory)
    {
        return subscription[_buyer];
    }

    /**
     * Get Order Of Winner
     **/
    function getOrderWinner(address _buyer)
    external
    view
    returns (Order memory)
    {
        return wins[_buyer];
    }

    /**
     * Get Wallet Of Buyer
     **/
    function getWalletBuyer(address _buyer)
    external
    view
    returns (Wallet memory)
    {
        return wallets[_buyer];
    }

    /**
     * Check Buyer is Subscriber
     **/
    function isSubscriber(address _buyer) external view returns (bool) {
        return isBuyerAdded(_buyer, subscribers);
    }

    /**
     * Check Buyer is Winner
     **/
    function isWinner(address _buyer) external view returns (bool) {
        return isBuyerAdded(_buyer, winners);
    }

    /**
     * Check Buyer is Buyers
     **/
    function isBuyer(address _buyer) external view returns (bool) {
        return isBuyerAdded(_buyer, buyers);
    }

    /**
     * Set Wins is empty
     **/
    function setEmptyWins() external onlyOwner onlyUncommit {
        require(winCount > 0);
        require(winners.length > 0);
        for (uint256 i = 0; i < winners.length; i++) {
            address _winner = winners[i];
            delete wins[_winner];
        }

        delete winners;
        delete winCount;
    }

    /**
     * Import Winners
     **/
    function importWinners(
        address[] calldata _buyer,
        uint256[] calldata _approvedBusd
    ) external onlyOwner winEmpty {
        uint256 _bUSDAllocated = 0;

        for (uint256 i = 0; i < _buyer.length; i++) {
            _bUSDAllocated += _approvedBusd[i];

            require(this.isSubscriber(_buyer[i]), "Buyer is not subscriber");

            require(
                !this.isWinner(_buyer[i]),
                "Buyer already exists in the list"
            );

            require(
                bUSDForSale.sub(_bUSDAllocated) >= 0,
                "Approved BUSD exceed the amount for sale"
            );

            require(_approvedBusd[i] > 0, "Amount has to be positive");

            require(
                _approvedBusd[i] >= individualMinimumAmountBusd,
                "Individual Minimum Amount Busd"
            );

            require(
                _approvedBusd[i] <= individualMaximumAmountBusd,
                "Individual Maximum Amount Busd"
            );

            Order memory _wins = Order(0, _approvedBusd[i], address(0));

            wins[_buyer[i]] = _wins;

            winners.push(_buyer[i]);

            winCount += 1;
        }
    }

    function commitWinners() external payable onlyOwner onlyUncommit {
        require(winners.length > 0, "You need import winners");

        require(verifySubWinnerHasRIR(), "Winner dont have in winners list");

        uint256 _bUSDAllocatedWins = 0;
        uint256 _bUSDAllocatedSub = 0;
        uint256 _bUSDForSale = 0;

        for (uint256 i = 0; i < subscribers.length; i++) {
            address _subscriber = subscribers[i];
            _bUSDAllocatedSub += subscription[_subscriber].amountBUSD;
        }

        if (_bUSDAllocatedSub >= bUSDForSale) {
            _bUSDForSale = bUSDForSale;
        } else {
            _bUSDForSale = _bUSDAllocatedSub;
        }

        for (uint256 i = 0; i < winners.length; i++) {
            address _winner = winners[i];
            _bUSDAllocatedWins += wins[_winner].amountBUSD;
        }

        require(_bUSDAllocatedWins == _bUSDForSale, "You need to check again");

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

    function createSubscription(
        uint256 _amountBusd,
        uint256 _amountRIR,
        address _referer
    ) external payable {
        require(_amountBusd >= 0, "Amount BUSD is not valid");

        require(_amountRIR >= 0, "Amount RIR is not valid");

        require(_amountBusd > 0 || _amountRIR > 0, "Amount is not valid");

        require(
            individualMaximumAmountBusd >=
            subscription[msg.sender].amountBUSD + _amountBusd,
            "Amount is overcome maximum"
        );

        require(
            individualMinimumAmountBusd <=
            subscription[msg.sender].amountBUSD + _amountBusd,
            "Amount is overcome minimum"
        );

        if (_amountRIR > 0) {
            require(
                rirAddress.balanceOf(msg.sender) >= _amountRIR,
                "You dont have enough RIR Token"
            );

            require(
                bUSDAddress.balanceOf(msg.sender) >= _amountBusd,
                "You dont have enough Busd Token"
            );

            // Prevent misunderstanding: only RIR is enough
            require(_amountRIR.mul(rate) <= subscription[msg.sender].amountBUSD + _amountBusd, "Amount is not valid");

            require(
                rirAddress.transferFrom(msg.sender, address(this), _amountRIR),
                "RIR transfer failed"
            );

            subscription[msg.sender].amountRIR += _amountRIR;
        }

        if (_amountBusd > 0) {
            require(
                bUSDAddress.balanceOf(msg.sender) >= _amountBusd,
                "You dont have enough Busd Token"
            );

            require(
                bUSDAddress.transferFrom(
                    msg.sender,
                    address(this),
                    _amountBusd
                ),
                "Transfer BUSD fail"
            );

            subscription[msg.sender].amountBUSD += _amountBusd;
        }

        if (_referer != address(0)) {
            subscription[msg.sender].referer = _referer;
        }

        if (!this.isSubscriber(msg.sender)) {
            subscribers.push(msg.sender);
            subscriptionCount += 1;
        }

        emit SubscriptionEvent(
            _amountRIR,
            _amountBusd,
            _referer,
            msg.sender,
            block.timestamp
        );
    }

    function isBuyerAdded(address _addr_buyer, address[] memory data)
    internal
    pure
    returns (bool)
    {
        uint256 i;
        while (i < data.length) {
            if (_addr_buyer == data[i]) {
                return true;
            }
            i++;
        }
        return false;
    }

    /*
    /* Deposit Token
    */
    function deposit(uint256 _amount) external payable onlyCommit onlyOwner {
        require(_amount > 0, "Amount has to be positive");
        require(
            tokenAddress.transferFrom(msg.sender, address(this), _amount),
            "Transfer failed"
        );
        depositTokens.push(_amount);
        sync(_amount);

        emit DepositEvent(_amount, msg.sender, block.timestamp);
    }

    // Claim Token from Wallet Contract
    function claimToken() external payable onlyCommit {
        /*
            Claim 
            1. If refund available => get back busd
            refund = sub - win

            2. If token available => get token
            for each winner: 
            token claimable = busd win / total busd * total deposited token - token claimed

            function: getClaimableToken of sender
            return token claimable = busd win / total busd * total deposited token - token claimed
        */

        uint256 balanceBusd = wins[msg.sender].amountBUSD;
        // require(
        //     this.availableBusd() >= balanceBusd,
        //     "Amount has to be positive"
        // );
        // uint256 balanceRIR = wins[msg.sender].amountRIR;
        // require(this.availableRIR() >= balanceRIR, "Amount has to be positive");
        // uint256 balanceToken = wins[msg.sender].amountToken;
        // require(
        //     this.availableTokens() >= balanceToken,
        //     "Amount has to be positive"
        // );
        // require(
        //     bUSDAddress.transfer(msg.sender, balanceBusd),
        //     "ERC20 transfer failed"
        // );
        // require(
        //     rirAddress.transfer(msg.sender, balanceRIR),
        //     "ERC20 transfer failed"
        // );
        // require(
        //     tokenAddress.transfer(msg.sender, balanceToken),
        //     "ERC20 transfer failed"
        // );
        // delete wins[msg.sender];
    }

    function sync(uint256 _amount) internal {
        uint256 i = 0;
        while (i < subscribers.length) {
            address _buyer = subscribers[i];
            if (!this.isBuyer(_buyer)) {
                Wallet storage _buyerWallet = wallets[_buyer];

                // Tinh toan refund BUSD
                if (subscription[_buyer].amountBUSD > wins[_buyer].amountBUSD && _buyerWallet.amountBUSD == 0) {
                    _buyerWallet.amountBUSD = subscription[_buyer].amountBUSD - wins[_buyer].amountBUSD;
                }
                uint256 _amountBUSDDeposite = _amount.mul(tokenPrice);
                // Token Receive = busd wins * ( _deposit busd / total busd *100) / tokenPrice
                uint256 tokenReceive = wins[_buyer].amountBUSD.mul(_amountBUSDDeposite).div(bUSDForSale).div(tokenPrice).mul(100);

                uint256 _totalBusdWillReceive = getTotalBusdWillReceive(_buyer, tokenReceive);

                if (_totalBusdWillReceive <= wins[_buyer].amountBUSD) {
                    _buyerWallet.amountToken.push(tokenReceive);
                } else {
                    uint256 _bUSDRemain = wins[_buyer].amountBUSD - getTotalBusdReceived(_buyer);
                    tokenReceive = _bUSDRemain.div(tokenPrice);
                    _buyerWallet.amountToken.push(tokenReceive);
                }

                buyers.push(_buyer);
                buyersCount++;
            }
            i++;
        }
    }

    function getTotalBusdWillReceive(address _buyer, uint256 _tokenReceive) internal returns (uint256) {
        Wallet memory _wallet = wallets[_buyer];
        uint256[] memory _amountToken = _wallet.amountToken;
        uint256 _totalTokenReceived = 0;
        for (uint i = 0; i < _amountToken.length; i++) {
            _totalTokenReceived += _amountToken[i];
        }
        _totalTokenReceived += _tokenReceive;
        uint256 _totalBusdWillReceived = _totalTokenReceived.div(tokenPrice);
        return _totalBusdWillReceived;
    }

    function getTotalBusdReceived(address _buyer) internal returns (uint256) {
        Wallet memory _wallet = wallets[_buyer];
        uint256[] memory _amountToken = _wallet.amountToken;
        uint256 _totalTokenReceived = 0;
        for (uint i = 0; i < _amountToken.length; i++) {
            _totalTokenReceived += _amountToken[i];
        }
        uint256 _totalBusdReceived = _totalTokenReceived.div(tokenPrice);
        return _totalBusdReceived;
    }

    /* Admin Withdraw BUSD */
    function withdrawBusdFunds() external onlyOwner onlyCommit {
        uint256 _balanceBusd = getTotalBusdWinners();
        bUSDAddress.transfer(ADDRESS_WITHDRAW, _balanceBusd);
    }

    function getTotalBusdWinners() internal view returns (uint256) {
        uint256 _totalBusdSold = 0;
        for (uint256 i = 0; i < winners.length; i++) {
            address _winner = winners[i];
            _totalBusdSold += wins[_winner].amountBUSD;
        }
        return _totalBusdSold;
    }

    function getTotalUnsoldTokens() internal view returns (uint256) {}

    /* Admin withdraw unsold token */
    /*
    require all totken send to contract
    total unsoldtoken = (total busd - total win)/total busd * total token in contract
    */
    function withdrawUnsoldTokens() external onlyOwner onlyCommit {
        // Chi rut phan token chưa bán
        require(!unsoldTokensReedemed);
        // uint256 unsoldTokens;
        // unsoldTokens = tokensForSale.sub(tokensAllocated);
        // if (unsoldTokens > 0) {
        //     unsoldTokensReedemed = true;
        //     require(
        //         tokenAddress.transfer(ADDRESS_WITHDRAW, unsoldTokens),
        //         "ERC20 transfer failed"
        //     );
        // }
    }

    function balanceTokens() external view returns (uint256) {
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
