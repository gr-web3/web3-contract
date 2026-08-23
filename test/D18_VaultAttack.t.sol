// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {VulnerableVault, SecureVault} from "../src/D18/Vault.sol";
import {VaultAttacker} from "../src/D18/VaultAttacker.sol";

contract D18_VaultAttackTest is Test {
    VulnerableVault public vulnerableVault;
    SecureVault public secureVault;
    VaultAttacker public attackerContract;

    address public victim1 = makeAddr("victim1");
    address public victim2 = makeAddr("victim2");
    address public attacker = makeAddr("attacker");

    function setUp() public {
        vulnerableVault = new VulnerableVault();
        secureVault = new SecureVault();

        // 注入测试资金
        vm.deal(victim1, 5 ether);
        vm.deal(victim2, 5 ether);
        vm.deal(attacker, 1 ether);

        // 受害者在漏洞 Vault 中存入 ETH (合计 10 ETH)
        vm.prank(victim1);
        vulnerableVault.deposit{value: 5 ether}();

        vm.prank(victim2);
        vulnerableVault.deposit{value: 5 ether}();

        // 部署攻击合约
        vm.prank(attacker);
        attackerContract = new VaultAttacker(address(vulnerableVault));
    }

    function test_ReentrancyAttackExploit() public {
        console.log(unicode"=== 攻击前 Vault 余额 ===", vulnerableVault.getBalance());
        assertEq(vulnerableVault.getBalance(), 10 ether);

        // 攻击者使用 1 ETH 发起重入攻击
        vm.prank(attacker);
        attackerContract.attack{value: 1 ether}();

        console.log(unicode"=== 攻击后 Vault 余额 ===", vulnerableVault.getBalance());
        console.log(unicode"=== 攻击合约盗取资金 ===", attackerContract.getBalance());

        // 验证 Vault 资产已被盗空 (余额为 0)
        assertEq(vulnerableVault.getBalance(), 0);
        // 攻击者本金 1 ETH + 盗取的 10 ETH = 11 ETH
        assertEq(attackerContract.getBalance(), 11 ether);
    }

    function test_SecureVaultDefendsReentrancy() public {
        // 给受害者重新注入 ETH 并存入安全 Vault (合计 10 ETH)
        vm.deal(victim1, 5 ether);
        vm.deal(victim2, 5 ether);

        vm.prank(victim1);
        secureVault.deposit{value: 5 ether}();
        vm.prank(victim2);
        secureVault.deposit{value: 5 ether}();

        // 部署针对 SecureVault 的攻击合约
        vm.prank(attacker);
        VaultAttacker secureAttacker = new VaultAttacker(address(secureVault));

        // 试图针对 SecureVault 发起攻击，预期调用被重入锁拦截或 CEI 拦截并回滚
        vm.prank(attacker);
        vm.expectRevert();
        secureAttacker.attack{value: 1 ether}();
    }
}
