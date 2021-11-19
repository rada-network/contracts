//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract LaunchPad is Initializable, ContextUpgradeable, PausableUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    struct Order {
        uint256 amountRIR;
        uint256 amountBUSD;
        uint256 amountToken;
    }

    mapping(address => Order) public subscription;
    uint256 public subscriptionCount;
    address[] public subscribers;

    mapping(address => Order) public whitelist;
    uint256 public whitelistCount;
    address[] public buyerWhitelists;

    mapping(address => Order) public wins;
    address[] public winners;

    event OrdersBuyerEvent(
        uint256 amountRIR,
        uint256 amountBUSD,
        address indexed buyer,
        uint256 timestamp
    );

    bool public isSaleFunded;
    uint256 public startDate; /* Start Date  - https://www.epochconverter.com/ */
    uint256 public endDate; /* End Date  */
    uint256 public individualMinimumAmountBusd; /* Minimum Amount Per Address */
    uint256 public individualMaximumAmountBusd; /* Minimum Amount Per Address */
    uint256 public tokenPrice; /* Gia token theo USD */
    uint256 public tokensAllocated; /* Tokens Allocated */
    uint256 public tokensForSale; /* Tokens for Sale */
    uint256 public rate; /* 1 RIR = 100 BUSD */
    bool public unsoldTokensReedemed;
    address public ADDRESS_WITHDRAW;

    ERC20 public tokenAddress;
    ERC20 public bUSDAddress;
    ERC20 public rirAddress;

    modifier isFunded() {
        require(isSaleFunded, "Has to be funded");
        _;
    }

    function initialize(
        address _tokenAddress,
        address _bUSDAddress,
        address _rirAddress,
        uint256 _tokenPrice, // Price Token (Ex: 1 TOKEN = 0.01 BUSD)
        uint256 _tokensForSale,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _individualMinimumAmountBusd,
        uint256 _individualMaximumAmountBusd
    ) public initializer {
        __Context_init_unchained();
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

        require(_tokensForSale > 0, "Tokens for Sale should be > 0");

        require(
            _tokensForSale > _individualMinimumAmountBusd,
            "Tokens for Sale should be > Individual Minimum Amount"
        );

        require(
            _individualMaximumAmountBusd >= _individualMinimumAmountBusd,
            "Individual Maximim AMount should be > Individual Minimum Amount"
        );

        startDate = _startDate;
        endDate = _endDate;
        tokensForSale = _tokensForSale;
        tokenPrice = _tokenPrice;
        tokensAllocated = 0;
        subscriptionCount = 0;
        whitelistCount = 0;
        rate = 100;
        unsoldTokensReedemed = false;
        isSaleFunded = false;
        ADDRESS_WITHDRAW = 0x128392d27439F0E76b3612E9B94f5E9C072d74e0;
        individualMinimumAmountBusd = _individualMinimumAmountBusd;
        individualMaximumAmountBusd = _individualMaximumAmountBusd;

        tokenAddress = ERC20(_tokenAddress);
        bUSDAddress = ERC20(_bUSDAddress);
        rirAddress = ERC20(_rirAddress);
    }

    function tokensLeft() external view returns (uint256) {
        return tokensForSale - tokensAllocated;
    }

    function getBuyerInWhitelist(address _buyer) external view returns (Order memory) {
        return whitelist[_buyer];
    }

    function getSubscriber(address _buyer) external view returns (Order memory) {
        return subscription[_buyer];
    }

    function getWinners() external view returns (address[] memory) {
        return winners;
    }

    function getSubscribers() external view returns (address[] memory) {
        return subscribers;
    }

    function importWhitelist(address[] calldata _buyer, uint256[] calldata _amountToken, bool[] calldata isRir) external onlyOwner {

        for (uint256 i = 0; i < _buyer.length; i++) {

            require(!isBuyerAdded(_buyer[i], buyerWhitelists), 'Address Buyer already exist');

            require(_amountToken[i] > 0, "Amount has to be positive");

            uint256 _amount_rir = 0;
            uint256 _amount_Token = 0;
            uint256 _amount_busd = 0;

            if (isRir[i]) {
                _amount_rir = _amountToken[i].mul(tokenPrice).div(rate).div(1e18);

                require(_amount_rir > 0, "Amount has to be positive");
            }

            _amount_busd = _amountToken[i].mul(tokenPrice).div(1e18);

            require(_amount_busd > 0, "Amount has to be positive");

            Order memory _whitelist = Order(_amount_rir, _amount_busd, _amountToken[i]);

            whitelist[_buyer[i]] = _whitelist;

            buyerWhitelists.push(_buyer[i]);

            subscriptionCount += 1 ether;
        }
    }

    function isBuyerHasRIR(address buyer) external view returns (bool) {
        return rirAddress.balanceOf(buyer) > 0;
    }

    function createSubscription(uint256 _amountBusd, bool isRir) payable external {

        require(_amountBusd > 0, "Amount has to be positive");

        require(!isBuyerAdded(msg.sender, subscribers), "You was subscribe");

        require(individualMaximumAmountBusd >= _amountBusd, "Amount is overcome maximum");

        require(individualMinimumAmountBusd <= _amountBusd, "Amount is overcome minimum");

        uint256 _amountRIR = 0;

        if (isRir) {
            _amountRIR = _amountBusd.div(rate);

            require(_amountRIR > 0, "Amount has to be positive");

            require(rirAddress.balanceOf(msg.sender) >= _amountRIR, "You dont have enough RIR Token");

            require(rirAddress.transferFrom(msg.sender, address(this), _amountRIR), "Transfer RIR fail");

            subscription[msg.sender].amountRIR += _amountRIR;
        }

        require(bUSDAddress.balanceOf(msg.sender) >= _amountBusd, "You dont have enough Busd Token");

        require(bUSDAddress.transferFrom(msg.sender, address(this), _amountBusd), "Transfer BUSD fail");

        subscription[msg.sender].amountBUSD += _amountBusd;

        if (!isBuyerAdded(msg.sender, subscribers)) {
            subscribers.push(msg.sender);
            subscriptionCount += 1 ether;
        }

        emit OrdersBuyerEvent(_amountRIR, _amountBusd, msg.sender, block.timestamp);
    }

    function isBuyerAdded(address _addr_buyer, address[] memory data) internal view returns (bool) {
        uint i;
        while (i < data.length) {
            if (_addr_buyer == data[i]) {
                return true;
            }
            i++;
        }
        return false;
    }

    function sync() external payable onlyOwner {
        uint i = 0;
        while (i < subscribers.length) {
            address addrBuyer = subscribers[i];

            winners.push(addrBuyer);

            if (isBuyerAdded(addrBuyer, buyerWhitelists)) {
                require(subscription[addrBuyer].amountBUSD >= whitelist[addrBuyer].amountBUSD);
                require(subscription[addrBuyer].amountRIR >= whitelist[addrBuyer].amountRIR);
                require(whitelist[addrBuyer].amountBUSD >= individualMinimumAmountBusd);
                require(whitelist[addrBuyer].amountBUSD <= individualMaximumAmountBusd);

                wins[addrBuyer].amountRIR = subscription[addrBuyer].amountRIR - whitelist[addrBuyer].amountRIR;
                wins[addrBuyer].amountBUSD = subscription[addrBuyer].amountBUSD - whitelist[addrBuyer].amountBUSD;
                wins[addrBuyer].amountToken = whitelist[addrBuyer].amountToken;

                tokensAllocated += wins[addrBuyer].amountToken;
            } else {
                wins[addrBuyer] = subscription[addrBuyer];
                wins[addrBuyer].amountToken = 0;
            }
            i++;
        }
    }

    // Claim Token from Wallet Contract
    function claimToken() external payable isFunded {
        uint256 balanceBusd = wins[msg.sender].amountBUSD;
        require(this.availableBusd() >= balanceBusd, "Amount has to be positive");
        uint256 balanceRIR = wins[msg.sender].amountRIR;
        require(this.availableRIR() >= balanceRIR, "Amount has to be positive");
        uint256 balanceToken = wins[msg.sender].amountToken;
        require(this.availableTokens() >= balanceToken, "Amount has to be positive");
        require(bUSDAddress.transfer(msg.sender, balanceBusd), "ERC20 transfer failed");
        require(rirAddress.transfer(msg.sender, balanceRIR), "ERC20 transfer failed");
        require(tokenAddress.transfer(msg.sender, balanceToken), "ERC20 transfer failed");
        delete wins[msg.sender];
    }

    /* Admin withdraw */
    function withdrawBusdFunds() external onlyOwner {
        uint256 balanceBusd = bUSDAddress.balanceOf(address(this));
        bUSDAddress.transferFrom(msg.sender, ADDRESS_WITHDRAW, balanceBusd);
    }

    /* Admin withdraw unsold token */
    function withdrawUnsoldTokens() external onlyOwner {
        require(!unsoldTokensReedemed);
        uint256 unsoldTokens;
        unsoldTokens = tokensForSale.sub(tokensAllocated);
        if (unsoldTokens > 0) {
            unsoldTokensReedemed = true;
            require(
                tokenAddress.transfer(ADDRESS_WITHDRAW, unsoldTokens),
                "ERC20 transfer failed"
            );
        }
    }

    function fund() external onlyOwner {
        isSaleFunded = true;
    }

    function availableTokens() external view returns (uint256) {
        return tokenAddress.balanceOf(address(this));
    }

    function availableBusd() external view returns (uint256) {
        return bUSDAddress.balanceOf(address(this));
    }

    function availableRIR() external view returns (uint256) {
        return rirAddress.balanceOf(address(this));
    }

    function removeOtherERC20Tokens(address _tokenAddress, address _to) external onlyOwner {
        require(
            _tokenAddress != address(tokenAddress),
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
