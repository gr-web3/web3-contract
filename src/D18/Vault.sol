// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title VulnerableVault
 * @notice 含有经典重入攻击漏洞的 Vault 合约
 */
contract VulnerableVault {
    mapping(address => uint256) public balances;

    // 存款方法
    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be > 0");
        balances[msg.sender] += msg.value;
    }

    // 存在重入漏洞的取款方法
    function withdraw() external {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        // 漏洞产生点：先向外部地址发送 ETH（触发回退函数），后更新状态
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "ETH transfer failed");

        // 状态更新靠后，重入发生时此行代码尚未执行！
        balances[msg.sender] = 0;
    }

    // 获取合约 ETH 余额
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

/**
 * @title SecureVault
 * @notice 采用 CEI 范式修补漏洞的安全 Vault 合约
 */
contract SecureVault {
    mapping(address => uint256) public balances;
    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be > 0");
        balances[msg.sender] += msg.value;
    }

    // 使用 CEI 范式 + 重入锁双重防护
    function withdraw() external nonReentrant {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        // 1. 先更新状态 (Effects)
        balances[msg.sender] = 0;

        // 2. 后进行外部交互 (Interactions)
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "ETH transfer failed");
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
