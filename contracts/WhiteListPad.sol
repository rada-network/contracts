//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.5;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./LaunchPad.sol";
import "./common/Whitelist.sol";

contract WhiteListPad is LaunchPad, Whitelist {
    using SafeMathUpgradeable for uint256;

    function createSubscription(
        uint256 _amountBusd,
        uint256 _amountRIR,
        address _referer
    ) external payable override onlyWhitelisted {

    }

    function importWinners(
        address[] calldata _buyer,
        uint256[] calldata _approvedBusd
    ) external virtual override onlyOwner winEmpty {}

    function sync(uint256 _amount) internal override {}

    function commitWinners() external payable override onlyOwner onlyUncommit {}
}
