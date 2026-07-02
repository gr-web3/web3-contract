// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {TokenBank} from "../src/D5/TokenBank.sol";
import {ERC20WithCallback} from "../src/D5/ERC20WithCallback.sol";

contract TokenBankTest is Test {
    TokenBank public tokenBank;
    ERC20WithCallback public token;

    address public admin = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        // Deploy ERC20WithCallback as admin
        vm.startPrank(admin);
        token = new ERC20WithCallback("CallbackToken", "CBT", 1_000_000);

        // Deploy TokenBank as admin
        tokenBank = new TokenBank(address(token));

        // Transfer some tokens to user to test deposits
        token.transfer(user, 1000 * 10 ** token.decimals());
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(tokenBank.admin(), admin);
        assertEq(address(tokenBank.token()), address(token));
    }

    // 1. 测试传统存款方式：Approve + Deposit (transferFrom)
    function test_TraditionalDepositAndWithdraw() public {
        uint256 amount = 100 * 10 ** token.decimals();

        // Approve TokenBank to spend tokens
        vm.prank(user);
        token.approve(address(tokenBank), amount);

        // Deposit
        vm.prank(user);
        tokenBank.deposit(amount);

        assertEq(tokenBank.balanceOf(user), amount);
        assertEq(token.balanceOf(address(tokenBank)), amount);

        // Withdraw
        vm.prank(user);
        tokenBank.withdraw(amount);

        assertEq(tokenBank.balanceOf(user), 0);
        assertEq(token.balanceOf(address(tokenBank)), 0);
    }

    // 2. 测试回调存款方式一：使用标准的 transfer 自动触发回调存款
    function test_DepositViaTransferCallback() public {
        uint256 amount = 150 * 10 ** token.decimals();

        // 直接转账给 TokenBank 触发 tokensReceived 回调进行记账
        vm.prank(user);
        token.transfer(address(tokenBank), amount);

        // 验证 Token 成功转入合约，并且 TokenBank 内部为用户记录了存款
        assertEq(token.balanceOf(address(tokenBank)), amount);
        assertEq(tokenBank.balanceOf(user), amount);

        // 验证用户仍然可以正常提款
        vm.prank(user);
        tokenBank.withdraw(amount);
        assertEq(tokenBank.balanceOf(user), 0);
        assertEq(token.balanceOf(address(tokenBank)), 0);
    }

    // 3. 测试回调存款方式二：使用 transferAndCall 触发回调存款
    function test_DepositViaTransferAndCallCallback() public {
        uint256 amount = 200 * 10 ** token.decimals();

        // 使用 transferAndCall 显式调用回调存款
        vm.prank(user);
        token.transferAndCall(address(tokenBank), amount, "");

        // 验证 Token 成功转入合约，并且 TokenBank 内部为用户记录了存款
        assertEq(token.balanceOf(address(tokenBank)), amount);
        assertEq(tokenBank.balanceOf(user), amount);
    }

    // 4. 测试管理员全额提现
    function test_AdminWithdrawAll_Success() public {
        uint256 amount = 500 * 10 ** token.decimals();

        // 用户通过回调方式存入 500 个代币
        vm.prank(user);
        token.transfer(address(tokenBank), amount);

        assertEq(token.balanceOf(address(tokenBank)), amount);

        uint256 adminBalanceBefore = token.balanceOf(admin);

        // Admin 提取所有 Token
        vm.prank(admin);
        tokenBank.adminWithdrawAll();

        assertEq(token.balanceOf(address(tokenBank)), 0);
        assertEq(token.balanceOf(admin) - adminBalanceBefore, amount);
    }

    function test_AdminWithdrawAll_NotAdmin_Fails() public {
        uint256 amount = 500 * 10 ** token.decimals();

        // 用户存入 500 代币
        vm.prank(user);
        token.transfer(address(tokenBank), amount);

        // 非管理员尝试提取 -> 失败
        vm.prank(user);
        vm.expectRevert("TokenBank: only admin can withdraw all tokens");
        tokenBank.adminWithdrawAll();
    }
}
