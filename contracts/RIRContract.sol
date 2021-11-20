//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";

contract RIRContract is ERC20PresetMinterPauserUpgradeable {

    function initialize(string memory name, string memory symbol) override public {
        initialize(name, symbol);
    }

}
