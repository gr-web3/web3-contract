// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../D3/Bank.sol";

contract BigBank is Bank {
    modifier minDepositLimit() {
        require(msg.value > 0.001 ether, "not big bank");
        _;
    }

    // 优化：重写内部存款逻辑处理函数，无需分别重写 deposit() 和 receive()
    function _handleDeposit() internal override minDepositLimit {
        super._handleDeposit();
    }
}
