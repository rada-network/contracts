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
        uint256 _tokensForSale,
        uint256 _startDate,
        uint256 _endDate,
        uint256 _individualMinimumAmount,
        uint256 _individualMaximumAmount,
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
            _tokensForSale > _individualMinimumAmount,
            "Tokens for Sale should be > Individual Minimum Amount"
        );

        require(
            _individualMaximumAmount >= _individualMinimumAmount,
            "Individual Maximim AMount should be > Individual Minimum Amount"
        );

        startDate = _startDate;
        endDate = _endDate;
        tokensForSale = _tokensForSale;
        tokenPrice = _tokenPrice;
        individualMinimumAmount = _individualMinimumAmount;
        individualMaximumAmount = _individualMaximumAmount;

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

    function isBuyerHasRIR(address buyer) external view returns (bool) {
        return rirAddress.balanceOf(buyer) > 0;
    }


    function createOrder(uint256 _amount_rir, uint256 _amount_busd) payable external {

        require(_amount_rir > 0, "Amount has to be positive");

        require(_amount_busd > 0, "Amount has to be positive");

        require(rirAddress.balanceOf(msg.sender) >= _amount_rir, "You dont have enough RIR Token");

        require(bUSDAddress.balanceOf(msg.sender) >= _amount_busd, "You dont have enough RIR Token");

        uint256 _amountToken = _amount_busd.div(tokenPrice).mul(1e18);

        require(
            _amountToken <= tokensLeft(),
            "Amount is less than tokens available"
        );

        Order memory _orderImport = Order(_amount_rir, _amount_busd, _amountToken, StatusOrder.PENDING);
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
