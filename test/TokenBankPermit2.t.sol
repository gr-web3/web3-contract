// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/D12/TokenBankPermit2.sol";
import "./mocks/MockPermit2.sol";

contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1_000_000 * 10 ** 18);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TokenBankPermit2Test is Test {
    MockToken public token;
    MockPermit2 public permit2;
    TokenBankPermit2 public bank;

    address public user = address(0x1234);
    address public admin = address(this);

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event AdminWithdraw(address indexed admin, uint256 amount);

    function setUp() public {
        token = new MockToken();
        permit2 = new MockPermit2();
        bank = new TokenBankPermit2(address(token), address(permit2));

        // 给 user 1000 个代币
        token.transfer(user, 1000 * 10 ** 18);
    }

    function test_InitialState() public view {
        assertEq(address(bank.token()), address(token));
        assertEq(bank.permit2(), address(permit2));
        assertEq(bank.admin(), admin);
    }

    function test_StandardDepositAndWithdraw() public {
        uint256 depositAmount = 100 * 10 ** 18;

        vm.startPrank(user);
        token.approve(address(bank), depositAmount);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user, depositAmount);
        bank.deposit(depositAmount);

        assertEq(bank.balanceOf(user), depositAmount);
        assertEq(token.balanceOf(address(bank)), depositAmount);

        // 取款
        vm.expectEmit(true, false, false, true);
        emit Withdraw(user, depositAmount);
        bank.withdraw(depositAmount);

        assertEq(bank.balanceOf(user), 0);
        assertEq(token.balanceOf(address(bank)), 0);
        vm.stopPrank();
    }

    function test_DepositWithPermit2_Success() public {
        uint256 amount = 200 * 10 ** 18;
        uint256 nonce = 1;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory mockSignature = hex"1234567890abcdef";

        vm.startPrank(user);
        // 用户只需授权 Permit2 合约
        token.approve(address(permit2), amount);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user, amount);

        bank.depositWithPermit2(amount, nonce, deadline, mockSignature);
        vm.stopPrank();

        assertEq(bank.balanceOf(user), amount);
        assertEq(token.balanceOf(address(bank)), amount);
    }

    function test_DepositWithPermit2_RevertExpiredDeadline() public {
        uint256 amount = 100 * 10 ** 18;
        uint256 nonce = 1;
        uint256 deadline = block.timestamp - 1; // 已过期
        bytes memory mockSignature = hex"1234";

        vm.startPrank(user);
        token.approve(address(permit2), amount);

        vm.expectRevert("Permit2: expired");
        bank.depositWithPermit2(amount, nonce, deadline, mockSignature);
        vm.stopPrank();
    }

    function test_DepositWithPermit2_RevertNonceReused() public {
        uint256 amount = 100 * 10 ** 18;
        uint256 nonce = 99;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory mockSignature = hex"1234";

        vm.startPrank(user);
        token.approve(address(permit2), amount * 2);

        // 第一次成功
        bank.depositWithPermit2(amount, nonce, deadline, mockSignature);

        // 第二次重复 nonce 失败
        vm.expectRevert("Permit2: nonce already used");
        bank.depositWithPermit2(amount, nonce, deadline, mockSignature);
        vm.stopPrank();
    }

    function test_AdminWithdrawAll() public {
        uint256 depositAmount = 500 * 10 ** 18;

        vm.startPrank(user);
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);
        vm.stopPrank();

        uint256 adminBalBefore = token.balanceOf(admin);

        vm.expectEmit(true, false, false, true);
        emit AdminWithdraw(admin, depositAmount);
        bank.adminWithdrawAll();

        assertEq(token.balanceOf(admin), adminBalBefore + depositAmount);
        assertEq(token.balanceOf(address(bank)), 0);
    }
}
