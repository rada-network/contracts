//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.2;

contract StatusContract {
    enum StatusOrder{ PENDING, PAYMENT, COMPLETE }
    StatusOrder status;
    StatusOrder constant defaultStatus = StatusOrder.PENDING;

    function getChoice() public view returns (StatusOrder) {
        return status;
    }
    function getDefaultStatus() public pure returns (uint) {
        return uint(defaultStatus);
    }
}
