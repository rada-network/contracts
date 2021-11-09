//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./common/Whitelist.sol";
import "./common/StatusContract.sol";
import "hardhat/console.sol";

contract LaunchPad is Pausable, Whitelist {
    using SafeMath for uint256;

    struct Wallet {
        address buyer;
        uint256 amountRIR;
        uint256 amountBUSD;
        uint256 amountToken;
    }

    struct Order {
        address buyer;
        uint256 amountBUSD;
        uint256 amountToken;
        StatusContract status;
    }

    mapping(uint256 => Order) public orders;
    mapping(address => Wallet) public wallets;

    uint256 public startDate; /* Start Date  - https://www.epochconverter.com/ */
    uint256 public endDate; /* End Date  */
    uint256 public individualMinimumAmount = 0; /* Minimum Amount Per Address */
    uint256 public individualMaximumAmount = 0; /* Minimum Amount Per Address */
    uint256 public tokenPrice; /* Gia token theo USD */
    uint256 public tokensAllocated = 0; /* Tokens Available for Allocation - Dynamic */
    uint256 public tokensForSale = 0; /* Tokens Available for Sale */
    uint256 public rate = 100; /* 1 RIR = 100 BUSD */

    ERC20 public tokenAddress;
    ERC20 public bUSDAddress;
    ERC20 public rirAddress;

    event OrderEvent(
        uint256 amount,
        address indexed buyer,
        uint256 timestamp
    );

    event WalletEvent(
        address buyer,
        uint256 amountRIR,
        uint256 amountBUSD,
        uint256 amountToken
    );

    constructor(
        address _tokenAddress,
        address _bUSDAddress,
        address _rirAddress,
    //        uint256 _tokenPrice, // Price Token (Ex: 1 TOKEN = 0.01 BUSD)
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
        //        tokenPrice = _tokenPrice;

        tokenAddress = ERC20(_tokenAddress);
        bUSDAddress = ERC20(_bUSDAddress);
        rirAddress = ERC20(_rirAddress);
    }

    function getOrder(uint256 _order_id) external view returns (address, uint256, uint256, StatusContract) {
        Order memory _order = orders[_order_id];
        return (
        _order.buyer,
        _order.amountBUSD,
        _order.amountToken,
        _order.status
        );
    }

    /* Admin withdraw */
    function withdrawFunds() external onlyOwner {

    }

    /* Admin withdraw unsold token */
    function withdrawUnsoldTokens() external onlyOwner {

    }

    function isBuyerHasPermissionBuy(address buyer) external view returns (bool) {
        require(rirAddress.balanceOf(buyer) > 0, "Buyer dont have permission buy token");
        return true;
    }

    function checkBuyerCanBuy(address buyer) external view returns (bool){
        uint256 rirAmount = rirAddress.balanceOf(msg.sender);
        uint256 busdAmount = bUSDAddress.balanceOf(msg.sender);
        bool canBuyToken = rirAmount.mul(100) <= busdAmount;
        bool hasRir = rirAmount > 0;
        bool hasBusd = busdAmount > 0;
        return canBuyToken && hasRir && hasBusd;
    }


    /* Swap Functions */
    function swap(uint256 _amount) external {

    }
}
