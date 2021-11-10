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
    enum StatusOrder{PENDING, ACCEPT, COMPLETE}

    struct Wallet {
        uint256 amountRIR;
        uint256 amountBUSD;
        uint256 amountToken;
    }

    struct Order {
        uint256 amountRIR;
        uint256 amountBUSD;
        uint256 amountToken;
        StatusOrder status;
    }

    mapping(address => Order) public orders;
    mapping(address => Order) public ordersImport;
    mapping(address => Wallet) public wallets;

    uint256 public startDate; /* Start Date  - https://www.epochconverter.com/ */
    uint256 public endDate; /* End Date  */
    uint256 public individualMinimumAmount = 0; /* Minimum Amount Per Address */
    uint256 public individualMaximumAmount = 0; /* Minimum Amount Per Address */
    uint256 public tokenPrice = 0; /* Gia token theo USD */
    uint256 public tokensAllocated = 0; /* Tokens Allocated */
    uint256 public tokensForSale = 0; /* Tokens for Sale */
    uint256 public rate = 100; /* 1 RIR = 100 BUSD */

    ERC20 public tokenAddress;
    ERC20 public bUSDAddress;
    ERC20 public rirAddress;

    constructor(
        address _tokenAddress,
        address _bUSDAddress,
        address _rirAddress,
        uint256 _tokenPrice, // Price Token (Ex: 1 TOKEN = 0.01 BUSD)
    //        uint256 _tokensForSale,
    //        uint256 _startDate,
    //        uint256 _endDate,
    //        uint256 _individualMinimumAmount,
    //        uint256 _individualMaximumAmount,
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
        //        require(_tokensForSale > 0, "Tokens for Sale should be > 0");
        //
        //        require(
        //            _tokensForSale > _individualMinimumAmount,
        //            "Tokens for Sale should be > Individual Minimum Amount"
        //        );
        //
        //        require(
        //            _individualMaximumAmount >= _individualMinimumAmount,
        //            "Individual Maximim AMount should be > Individual Minimum Amount"
        //        );
        //
        //        startDate = _startDate;
        //        endDate = _endDate;
        //        tokensForSale = _tokensForSale;
        tokenPrice = _tokenPrice;

        tokenAddress = ERC20(_tokenAddress);
        bUSDAddress = ERC20(_bUSDAddress);
        rirAddress = ERC20(_rirAddress);
    }

    function getOrder(address _buyer) external view returns (uint256, uint256, uint256, StatusOrder) {
        Order memory _order = orders[_buyer];
        return (
        _order.amountRIR,
        _order.amountBUSD,
        _order.amountToken,
        _order.status
        );
    }

    function tokensLeft() public view returns (uint256) {
        return tokensForSale - tokensAllocated;
    }

    function isBuyerHasPermissionBuy(address buyer) external view returns (bool) {
        return rirAddress.balanceOf(buyer) > 0;
    }

    function checkBuyerCanBuy(address buyer) external view returns (bool){
        uint256 rirAmount = rirAddress.balanceOf(buyer);
        uint256 busdAmount = bUSDAddress.balanceOf(buyer);
        bool canBuyToken = rirAmount.mul(rate) <= busdAmount;
        bool hasRir = rirAmount > 0;
        bool hasBusd = busdAmount > 0;
        return canBuyToken && hasRir && hasBusd;
    }


    function addOrdersImport(address[] calldata _buyer, uint256[] calldata _amountBUSD) external onlyOwner {
        for (uint256 i = 0; i < _buyer.length; i++) {
            uint256 _amountToken = _amountBUSD[i].div(tokenPrice).mul(1e18);
            Order memory _orderImport = Order(0, _amountBUSD[i], _amountToken, StatusOrder.PENDING);
            ordersImport[_buyer[i]] = _orderImport;
        }
    }

    function getOrderImport(address _buyer) external onlyOwner view returns (Order memory) {
        return ordersImport[_buyer];
    }

    function createOrder(uint256 _amount) external {
        /* Confirm Amount is positive */
        require(_amount > 0, "Amount has to be positive");

        if (this.isBuyerHasPermissionBuy(msg.sender)) {
            createOrderByPassWhiteList(_amount);
        } else {
            createOrderNormal(_amount);
        }
    }

    function createOrderNormal(uint256 _amount) internal onlyWhitelisted {

    }

    function createOrderByPassWhiteList(uint256 _amount) internal {
        uint256 rirAmount = _amount.div(rate);
        uint256 busdAmount = _amount;

        require(this.checkBuyerCanBuy(msg.sender), "You are not enough RIR Token and BUSD Token");

        require(rirAmount <= rirAddress.balanceOf(msg.sender), "You are not enough RIR Token");

        require(busdAmount <= bUSDAddress.balanceOf(msg.sender), "You are not enough BUSD Token");

        
    }


    //    /* Admin withdraw */
    //    function withdrawFunds() external onlyOwner {
    //
    //    }
    //
    //    /* Admin withdraw unsold token */
    //    function withdrawUnsoldTokens() external onlyOwner {
    //
    //    }
}
