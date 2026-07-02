// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./BigBank.sol";

contract Admin {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    // 调用 BigBank 的 withdraw()
    function withdrawFromBank(address payable bankAddress) external onlyOwner {
        BigBank(bankAddress).withdraw();
    }

    // 提现 Admin 合约自身的资金到 owner
    function withdrawSelf() external onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = owner.call{value: balance}("");
        require(success, "Transfer failed");
    }

    // 接收从 BigBank 转来的 Ether
    receive() external payable {}
}
