// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BigBank} from "../src/D4/BigBank.sol";
import {Admin} from "../src/D4/Admin.sol";
import {Bank} from "../src/D3/Bank.sol";

contract BigBankTest is Test {
    BigBank public bigBank;
    Admin public adminContract;

    address public user = address(0x9999);
    address public attacker = address(0xbad);

    function setUp() public {
        bigBank = new BigBank();
        adminContract = new Admin();
        
        vm.deal(user, 10 ether);
        vm.deal(attacker, 10 ether);
    }

    function test_InitialAdmin() public view {
        // Initial admin of bigBank should be this test contract (deployer)
        assertEq(bigBank.admin(), address(this));
    }

    function test_DepositLimit() public {
        // 1. Deposit exactly 0.001 ether -> should revert
        vm.prank(user);
        vm.expectRevert("not big bank");
        bigBank.deposit{value: 0.001 ether}();

        // 2. Deposit 0.0005 ether -> should revert
        vm.prank(user);
        vm.expectRevert("not big bank");
        bigBank.deposit{value: 0.0005 ether}();

        // 3. Deposit 0.0011 ether -> should succeed
        vm.prank(user);
        bigBank.deposit{value: 0.0011 ether}();
        assertEq(bigBank.deposits(user), 0.0011 ether);

        // 4. Deposit 1 ether via receive() -> should succeed
        vm.prank(user);
        (bool success, ) = address(bigBank).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(bigBank.deposits(user), 1.0011 ether);
    }

    function test_TransferAdminAndWithdraw() public {
        // 1. User deposits some ether into bigBank
        vm.prank(user);
        bigBank.deposit{value: 5 ether}();
        assertEq(address(bigBank).balance, 5 ether);

        // 2. Transfer admin to Admin contract
        bigBank.transferAdmin(address(adminContract));
        assertEq(bigBank.admin(), address(adminContract));

        // 3. Try withdrawing directly from bigBank as the old admin -> should fail
        vm.expectRevert(Bank.NotAdmin.selector);
        bigBank.withdraw();

        // 4. Try calling Admin contract's withdrawFromBank as non-owner (attacker) -> should fail
        vm.prank(attacker);
        vm.expectRevert("Only owner can call");
        adminContract.withdrawFromBank(payable(address(bigBank)));

        // 5. Withdraw via Admin contract (as owner) -> should succeed
        uint256 adminContractBalanceBefore = address(adminContract).balance;
        adminContract.withdrawFromBank(payable(address(bigBank)));

        assertEq(address(bigBank).balance, 0);
        assertEq(address(adminContract).balance - adminContractBalanceBefore, 5 ether);

        // 6. Withdraw from Admin contract to owner
        uint256 ownerBalanceBefore = address(this).balance;
        adminContract.withdrawSelf();
        assertEq(address(adminContract).balance, 0);
        assertEq(address(this).balance - ownerBalanceBefore, 5 ether);
    }

    // Required to receive ether when adminContract.withdrawSelf() is called
    receive() external payable {}
}
