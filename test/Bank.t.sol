// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Bank} from "../src/D3/Bank.sol";

contract BankTest is Test {
    Bank public bank;

    address public userA = address(0x1111);
    address public userB = address(0x2222);
    address public userC = address(0x3333);
    address public userD = address(0x4444);

    // Re-declare events for testing expectEmit
    event Deposited(address indexed user, uint256 amount);
    event TopThreeUpdated(address[3] newTopThree);
    event AdminWithdrawn(address indexed admin, uint256 amount);

    function setUp() public {
        // The test contract deploys Bank, so Bank's admin is BankTest (this contract)
        bank = new Bank();
        // Give users some ether to deposit
        vm.deal(userA, 100 ether);
        vm.deal(userB, 100 ether);
        vm.deal(userC, 100 ether);
        vm.deal(userD, 100 ether);
    }

    function test_InitialState() public view {
        assertEq(bank.admin(), address(this));
        assertEq(bank.topThreeAddress(0), address(0));
        assertEq(bank.topThreeAddress(1), address(0));
        assertEq(bank.topThreeAddress(2), address(0));
    }

    function test_DepositZeroFails() public {
        vm.prank(userA);
        vm.expectRevert(Bank.DepositAmountZero.selector);
        bank.deposit{value: 0}();
    }

    function test_ReceivePayableFallback() public {
        // Direct transfer to trigger receive()
        vm.prank(userA);
        (bool success, ) = address(bank).call{value: 5 ether}("");
        assertTrue(success);

        assertEq(bank.deposits(userA), 5 ether);
        assertEq(bank.topThreeAddress(0), userA);
    }

    function test_EventsEmitted() public {
        // Expect Deposited event
        // 1st param: true (indexed user), 2nd: false, 3rd: false, 4th: true (data: value)
        vm.expectEmit(true, false, false, true);
        emit Deposited(userA, 10 ether);

        // Expect TopThreeUpdated event
        // 1st: false, 2nd: false, 3rd: false, 4th: true (data: address[3] array)
        address[3] memory expectedRank = [userA, address(0), address(0)];
        vm.expectEmit(false, false, false, true);
        emit TopThreeUpdated(expectedRank);

        vm.prank(userA);
        bank.deposit{value: 10 ether}();
    }

    function test_DepositRankingSequence() public {
        // 1. UserA deposits 10 ether -> [UserA, 0x0, 0x0]
        vm.prank(userA);
        bank.deposit{value: 10 ether}();
        assertEq(bank.topThreeAddress(0), userA);
        assertEq(bank.topThreeAddress(1), address(0));
        assertEq(bank.topThreeAddress(2), address(0));

        // 2. UserB deposits 5 ether -> [UserA, UserB, 0x0]
        vm.prank(userB);
        bank.deposit{value: 5 ether}();
        assertEq(bank.topThreeAddress(0), userA);
        assertEq(bank.topThreeAddress(1), userB);
        assertEq(bank.topThreeAddress(2), address(0));

        // 3. UserC deposits 8 ether -> [UserA, UserC, UserB]
        vm.prank(userC);
        bank.deposit{value: 8 ether}();
        assertEq(bank.topThreeAddress(0), userA);
        assertEq(bank.topThreeAddress(1), userC);
        assertEq(bank.topThreeAddress(2), userB);

        // 4. UserB deposits 10 ether (total 15) -> [UserB, UserA, UserC]
        vm.prank(userB);
        bank.deposit{value: 10 ether}();
        assertEq(bank.topThreeAddress(0), userB);
        assertEq(bank.topThreeAddress(1), userA);
        assertEq(bank.topThreeAddress(2), userC);

        // 5. UserC deposits 4 ether (total 12) -> [UserB, UserC, UserA]
        vm.prank(userC);
        bank.deposit{value: 4 ether}();
        assertEq(bank.topThreeAddress(0), userB);
        assertEq(bank.topThreeAddress(1), userC);
        assertEq(bank.topThreeAddress(2), userA);

        // 6. UserD deposits 20 ether -> [UserD, UserB, UserC]
        vm.prank(userD);
        bank.deposit{value: 20 ether}();
        assertEq(bank.topThreeAddress(0), userD);
        assertEq(bank.topThreeAddress(1), userB);
        assertEq(bank.topThreeAddress(2), userC);

        // 7. UserC deposits 5 ether (total 17) -> [UserD, UserC, UserB]
        vm.prank(userC);
        bank.deposit{value: 5 ether}();
        assertEq(bank.topThreeAddress(0), userD);
        assertEq(bank.topThreeAddress(1), userC);
        assertEq(bank.topThreeAddress(2), userB);
    }

    function test_Withdrawal_Success() public {
        // Users deposit ether
        vm.prank(userA);
        bank.deposit{value: 10 ether}();
        vm.prank(userB);
        bank.deposit{value: 15 ether}();

        uint256 contractBalanceBefore = address(bank).balance;
        assertEq(contractBalanceBefore, 25 ether);

        uint256 adminBalanceBefore = address(this).balance;

        // Expect AdminWithdrawn event
        vm.expectEmit(true, false, false, true);
        emit AdminWithdrawn(address(this), 25 ether);

        // Admin call withdraw
        bank.withdraw();

        assertEq(address(bank).balance, 0);
        assertEq(address(this).balance - adminBalanceBefore, 25 ether);
    }

    function test_Withdrawal_NotAdmin_Fails() public {
        vm.prank(userA);
        bank.deposit{value: 10 ether}();

        // userB (non-admin) tries to withdraw
        vm.prank(userB);
        vm.expectRevert(Bank.NotAdmin.selector);
        bank.withdraw();
    }

    function test_Withdrawal_NoBalance_Fails() public {
        // Admin calls withdraw when balance is 0
        vm.expectRevert(Bank.NoBalanceToWithdraw.selector);
        bank.withdraw();
    }

    // Required for the test contract to receive ether from Bank when calling withdraw
    receive() external payable {}
}
