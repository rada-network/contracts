//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./common/Whitelist.sol";
import "hardhat/console.sol";

contract LaunchPad is Pausable, Whitelist {
    using SafeMath for uint256;

    struct Order {
        uint256 amountRIR;
        uint256 amountBUSD;
        uint256 amountToken;
    }

    mapping(address => Order) public ordersBuyer;
    uint256 public ordersBuyerCount = 0;
    address[] public buyers;

    mapping(address => Order) public ordersImport;
    uint256 public ordersImportCount = 0;
    address[] public buyersImport;

    mapping(address => Order) public wallets;
    address[] public buyersWallets;

    event OrdersBuyerEvent(
        uint256 amountRIR,
        uint256 amountBUSD,
        address indexed buyer,
        uint256 timestamp
    );

    bool public isSaleFunded = false;
    uint256 public startDate; /* Start Date  - https://www.epochconverter.com/ */
    uint256 public endDate; /* End Date  */
    uint256 public individualMinimumAmountBusd = 0; /* Minimum Amount Per Address */
    uint256 public individualMaximumAmountBusd = 0; /* Minimum Amount Per Address */
    uint256 public tokenPrice = 0; /* Gia token theo USD */
    uint256 public tokensAllocated = 0; /* Tokens Allocated */
    uint256 public tokensForSale = 0; /* Tokens for Sale */
    uint256 public rate = 100; /* 1 RIR = 100 BUSD */
    bool public unsoldTokensReedemed = false;
    address public ADDRESS_WITHDRAW = 0x128392d27439F0E76b3612E9B94f5E9C072d74e0;

    ERC20 public tokenAddress;
    ERC20 public bUSDAddress;
    ERC20 public rirAddress;

    modifier isFunded() {
        require(isSaleFunded, "Has to be funded");
        _;
    }

    constructor(
        address _tokenAddress,
        address _bUSDAddress,
        address _rirAddress,
        uint256 _tokenPrice, // Price Token (Ex: 1 TOKEN = 0.01 BUSD)
        uint256 _tokensForSale,
    //        uint256 _startDate,
    //        uint256 _endDate,
        uint256 _individualMinimumAmountBusd,
        uint256 _individualMaximumAmountBusd,
        bool _hasWhitelisting
    ) Whitelist(_hasWhitelisting) {
        //        require(
        //            block.timestamp < _endDate,
        //            "End Date should be further than current date"
        //        );
        //
        //        require(
        //            block.timestamp < _startDate,
        //            "Start Date should be further than current date"
        //        );
        //
        //        require(_startDate < _endDate, "End Date higher than Start Date");
        //
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

        //        startDate = _startDate;
        //        endDate = _endDate;
        tokensForSale = _tokensForSale;
        tokenPrice = _tokenPrice;
        individualMinimumAmountBusd = _individualMinimumAmountBusd;
        individualMaximumAmountBusd = _individualMaximumAmountBusd;

        tokenAddress = ERC20(_tokenAddress);
        bUSDAddress = ERC20(_bUSDAddress);
        rirAddress = ERC20(_rirAddress);
    }

    function tokensLeft() external view returns (uint256) {
        return tokensForSale - tokensAllocated;
    }

    function addOrdersImport(address[] calldata _buyer, uint256[] calldata _amountToken, bool[] calldata isRir) external onlyOwner {

        for (uint256 i = 0; i < _buyer.length; i++) {

            require(!isOrderInData(_buyer[i], buyersImport), 'Address Buyer already exist');

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

            Order memory _orderImport = Order(_amount_rir, _amount_busd, _amountToken[i]);

            ordersImport[_buyer[i]] = _orderImport;

            buyersImport.push(_buyer[i]);

            ordersImportCount += 1 ether;
        }
    }

    function getOrderImport(address _buyer) external onlyOwner view returns (Order memory) {
        return ordersImport[_buyer];
    }

    function getOrderBuyer(address _buyer) external view returns (Order memory) {
        return ordersBuyer[_buyer];
    }

    function getBuyersWallets() external view returns (address[] memory) {
        return buyersWallets;
    }

    function getBuyers() external view returns (address[] memory) {
        return buyers;
    }

    function isBuyerHasRIR(address buyer) external view returns (bool) {
        return rirAddress.balanceOf(buyer) > 0;
    }

    function createOrder(uint256 _amountBusd, bool isRir) payable external {

        require(_amountBusd > 0, "Amount has to be positive");

        require(!isOrderInData(msg.sender, buyers),"You was subscribe");

        require(individualMaximumAmountBusd >= _amountBusd, "Amount is overcome maximum");

        require(individualMinimumAmountBusd <= _amountBusd, "Amount is overcome minimum");

        uint256 _amountRIR = 0;

        if (isRir) {
            _amountRIR = _amountBusd.div(rate);

            require(_amountRIR > 0, "Amount has to be positive");

            require(rirAddress.balanceOf(msg.sender) >= _amountRIR, "You dont have enough RIR Token");

            require(rirAddress.transferFrom(msg.sender, address(this), _amountRIR), "Transfer RIR fail");

            ordersBuyer[msg.sender].amountRIR += _amountRIR;
        }

        require(bUSDAddress.balanceOf(msg.sender) >= _amountBusd, "You dont have enough Busd Token");

        require(bUSDAddress.transferFrom(msg.sender, address(this), _amountBusd), "Transfer BUSD fail");

        ordersBuyer[msg.sender].amountBUSD += _amountBusd;

        if (!isOrderInData(msg.sender, buyers)) {
            buyers.push(msg.sender);
            ordersBuyerCount += 1 ether;
        }

        emit OrdersBuyerEvent(_amountRIR, _amountBusd, msg.sender, block.timestamp);
    }

    function isOrderInData(address _addr_buyer, address[] memory data) internal view returns (bool) {
        uint i;
        while (i < data.length) {
            if (_addr_buyer == data[i]) {
                return true;
            }
            i++;
        }
        return false;
    }

    function syncOrder() external payable onlyOwner {
        uint i;
        while (i < buyers.length) {
            address addrBuyer = buyers[i];

            buyersWallets.push(addrBuyer);

            if (isOrderInData(addrBuyer, buyersImport)) {
                require(ordersBuyer[addrBuyer].amountBUSD >= ordersImport[addrBuyer].amountBUSD);
                require(ordersBuyer[addrBuyer].amountRIR >= ordersImport[addrBuyer].amountRIR);
                require(ordersImport[addrBuyer].amountBUSD >= individualMinimumAmountBusd);
                require(ordersImport[addrBuyer].amountBUSD <= individualMaximumAmountBusd);

                wallets[addrBuyer].amountRIR = ordersBuyer[addrBuyer].amountRIR - ordersImport[addrBuyer].amountRIR;
                wallets[addrBuyer].amountBUSD = ordersBuyer[addrBuyer].amountBUSD - ordersImport[addrBuyer].amountBUSD;
                wallets[addrBuyer].amountToken = ordersImport[addrBuyer].amountToken;

                tokensAllocated += wallets[addrBuyer].amountToken;
            } else {
                wallets[addrBuyer] = ordersBuyer[addrBuyer];
                wallets[addrBuyer].amountToken = 0;
            }
            i++;
        }
    }

    // Claim Token from Wallet Contract
    function claimToken() external payable isFunded {
        uint256 balanceBusd = wallets[msg.sender].amountBUSD;
        require(this.availableBusd() >= balanceBusd,"Amount has to be positive");
        uint256 balanceRIR = wallets[msg.sender].amountRIR;
        require(this.availableRIR() >= balanceRIR,"Amount has to be positive");
        uint256 balanceToken = wallets[msg.sender].amountToken;
        require(this.availableTokens() >= balanceToken,"Amount has to be positive");
        require(bUSDAddress.transfer(msg.sender, balanceBusd), "ERC20 transfer failed");
        require(rirAddress.transfer(msg.sender, balanceRIR), "ERC20 transfer failed");
        require(tokenAddress.transfer(msg.sender, balanceToken), "ERC20 transfer failed");
        delete wallets[msg.sender];
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
        ); // Confirm tokens addresses are different from main sale one
        ERC20 erc20Token = ERC20(_tokenAddress);
        require(
            erc20Token.transfer(_to, erc20Token.balanceOf(address(this))),
            "ERC20 Token transfer failed"
        );
    }
}
