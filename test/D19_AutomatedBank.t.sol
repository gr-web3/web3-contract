// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {AutomatedTokenBank} from "../src/D19/AutomatedTokenBank.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock ERC20 Token", "MTK") {
        _mint(msg.sender, 100_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract D19_AutomatedBankTest is Test {
    AutomatedTokenBank public bank;
    MockToken public token;

    address public owner = makeAddr("owner");
    address public recipient = makeAddr("recipient");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public constant THRESHOLD_X = 1000 * 10 ** 18; // 1000 Token

    function setUp() public {
        vm.startPrank(owner);
        token = new MockToken();
        bank = new AutomatedTokenBank(address(token), THRESHOLD_X, recipient);
        vm.stopPrank();

        // 给用户分发测试代币
        token.mint(user1, 5000 * 10 ** 18);
        token.mint(user2, 5000 * 10 ** 18);
    }

    function test_DepositWithApprove_Success() public {
        uint256 depositAmount = 400 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);
        vm.stopPrank();

        assertEq(bank.tokenNum(user1), depositAmount);
        assertEq(token.balanceOf(address(bank)), depositAmount);
    }

    function test_CheckUpkeep_ReturnsFalseWhenUnderThreshold() public {
        uint256 depositAmount = 800 * 10 ** 18; // 低于 1000 阈值

        vm.startPrank(user1);
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);
        vm.stopPrank();

        (bool upkeepNeeded, ) = bank.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeep_ReturnsTrueWhenThresholdMet() public {
        uint256 depositAmount = 1200 * 10 ** 18; // 超过 1000 阈值

        vm.startPrank(user1);
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);
        vm.stopPrank();

        (bool upkeepNeeded, bytes memory performData) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);
        
        uint256 reportedBalance = abi.decode(performData, (uint256));
        assertEq(reportedBalance, depositAmount);
    }

    function test_PerformUpkeep_ExecutesAutomatedTransfer() public {
        uint256 deposit1 = 600 * 10 ** 18;
        uint256 deposit2 = 600 * 10 ** 18;
        uint256 totalDeposit = deposit1 + deposit2; // 1200 Token >= 1000

        // 用户 1 存款
        vm.startPrank(user1);
        token.approve(address(bank), deposit1);
        bank.deposit(deposit1);
        vm.stopPrank();

        // 用户 2 存款
        vm.startPrank(user2);
        token.approve(address(bank), deposit2);
        bank.deposit(deposit2);
        vm.stopPrank();

        assertEq(token.balanceOf(address(bank)), totalDeposit);

        // 验证 checkUpkeep 触发
        (bool upkeepNeeded, bytes memory performData) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // 记录划转前接收者余额
        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        // 模拟 Chainlink Automation 节点触发 performUpkeep
        bank.performUpkeep(performData);

        uint256 expectedHalf = totalDeposit / 2; // 600 Token
        uint256 expectedRemaining = totalDeposit - expectedHalf; // 600 Token

        // 断言接收者收到了 50% 划转
        assertEq(token.balanceOf(recipient), recipientBalanceBefore + expectedHalf);
        // 断言银行剩余 50%
        assertEq(token.balanceOf(address(bank)), expectedRemaining);
    }

    function test_PerformUpkeep_RevertsWhenUnderThreshold() public {
        uint256 depositAmount = 500 * 10 ** 18; // 低于阈值

        vm.startPrank(user1);
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);
        vm.stopPrank();

        vm.expectRevert("Automation condition not met");
        bank.performUpkeep("");
    }

    function test_GelatoCheckerCompatibility() public {
        uint256 depositAmount = 1500 * 10 ** 18;

        vm.startPrank(user1);
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);
        vm.stopPrank();

        (bool canExec, bytes memory execPayload) = bank.checker();
        assertTrue(canExec);
        assertTrue(execPayload.length > 0);
    }

    function test_AdminConfig() public {
        uint256 newThreshold = 2000 * 10 ** 18;
        address newRecipient = makeAddr("newRecipient");

        vm.startPrank(owner);
        bank.setThresholdX(newThreshold);
        bank.setRecipient(newRecipient);
        vm.stopPrank();

        assertEq(bank.thresholdX(), newThreshold);
        assertEq(bank.recipient(), newRecipient);
    }
}
