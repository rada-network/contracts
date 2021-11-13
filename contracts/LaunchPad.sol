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

    struct Order {
        uint256 amountRIR;
        uint256 amountBUSD;
        uint256 amountToken;
    }

    mapping(address => Order) public ordersBuyer;
    mapping(address => Order) public ordersImport;
    mapping(address => Order) public wallets;

    event OrdersBuyerEvent(
        uint256 amountRIR,
        uint256 amountBUSD,
        address indexed buyer,
        uint256 timestamp
    );


    uint256 public startDate; /* Start Date  - https://www.epochconverter.com/ */
    uint256 public endDate; /* End Date  */
    uint256 public individualMinimumAmount = 0; /* Minimum Amount Per Address */
    uint256 public individualMaximumAmount = 0; /* Minimum Amount Per Address */
    uint256 public tokenPrice = 0; /* Gia token theo USD */
    uint256 public tokensAllocated = 0; /* Tokens Allocated */
    uint256 public tokensForSale = 0; /* Tokens for Sale */
    uint256 public rate = 100; /* 1 RIR = 100 BUSD */
    bool public unsoldTokensReedemed = false;
    address public ADDRESS_WITHDRAW = 0x128392d27439F0E76b3612E9B94f5E9C072d74e0;

    ERC20 public tokenAddress;
    ERC20 public bUSDAddress;
    ERC20 public rirAddress;

    constructor(
        address _tokenAddress,
        address _bUSDAddress,
        address _rirAddress,
        uint256 _tokenPrice, // Price Token (Ex: 1 TOKEN = 0.01 BUSD)
        uint256 _tokensForSale,
    //        uint256 _startDate,
    //        uint256 _endDate,
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

        //        startDate = _startDate;
        //        endDate = _endDate;
        tokensForSale = _tokensForSale;
        tokenPrice = _tokenPrice;
        individualMinimumAmount = _individualMinimumAmount;
        individualMaximumAmount = _individualMaximumAmount;

        tokenAddress = ERC20(_tokenAddress);
        bUSDAddress = ERC20(_bUSDAddress);
        rirAddress = ERC20(_rirAddress);
    }

    function getOrdersBuyer(address _buyer) external view returns (uint256, uint256, uint256) {
        Order memory _order = ordersBuyer[_buyer];
        return (
        _order.amountRIR,
        _order.amountBUSD,
        _order.amountToken
        );
    }

    function tokensLeft() public view returns (uint256) {
        return tokensForSale - tokensAllocated;
    }

    function addOrdersImport(address[] calldata _buyer, uint256[] calldata _amountToken, bool[] calldata isRir) external onlyOwner {

        for (uint256 i = 0; i < _buyer.length; i++) {

            require(ordersImport[_buyer[i]].amountToken == 0, 'Address Buyer already exist');

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
        }
    }

    function getOrderImport(address _buyer) external onlyOwner view returns (Order memory) {
        return ordersImport[_buyer];
    }

    function isBuyerHasRIR(address buyer) external view returns (bool) {
        return rirAddress.balanceOf(buyer) > 0;
    }


    function createOrder(uint256 _amountToken, bool isRir) payable external {

        require(_amountToken > 0, "Amount has to be positive");

        uint256 _amount_rir = 0;
        uint256 _amount_busd = 0;
        if (isRir) {

            if (ordersBuyer[msg.sender].amountRIR != 0) {
                _amount_rir = ordersBuyer[msg.sender].amountRIR;
            }

            _amount_rir += _amountToken.mul(tokenPrice).div(rate).div(1e18);

            require(_amount_rir > 0, "Amount has to be positive");

            require(rirAddress.balanceOf(msg.sender) >= _amount_rir, "You dont have enough RIR Token");

            rirAddress.transferFrom(msg.sender, address(this), _amount_rir);
        }

        if (ordersBuyer[msg.sender].amountBUSD != 0) {
            _amount_busd = ordersBuyer[msg.sender].amountBUSD;
        }

        _amount_busd += _amountToken.mul(tokenPrice).div(1e18);

        require(_amount_busd > 0, "Amount has to be positive");

        require(bUSDAddress.balanceOf(msg.sender) >= _amount_busd, "You dont have enough RIR Token");

        bUSDAddress.transferFrom(msg.sender, address(this), _amount_busd);

        uint256 amountToken = 0;

        if (ordersBuyer[msg.sender].amountToken != 0) {
            amountToken = ordersBuyer[msg.sender].amountToken;
        }

        amountToken += _amountToken;

        Order memory _orderBuyer = Order(_amount_rir, _amount_busd, amountToken);

        ordersBuyer[msg.sender] = _orderBuyer;

        emit OrdersBuyerEvent(_amount_rir, _amount_busd, msg.sender, block.timestamp);
    }

    function syncOrder() external onlyOwner {
        //        for()
        //        mapping(address => Order) public ordersImport;
        //        mapping(address => Order) public wallets;
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
                tokenAddress.transferFrom(msg.sender, ADDRESS_WITHDRAW, unsoldTokens),
                "ERC20 transfer failed"
            );
        }
    }
}
