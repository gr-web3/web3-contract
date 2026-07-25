// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/D11/MultiSigWallet.sol";

contract TargetMock {
    uint256 public value;
    address public sender;

    event Called(address caller, uint256 val);

    function setValue(uint256 _val) external payable {
        value = _val;
        sender = msg.sender;
        emit Called(msg.sender, _val);
    }
}

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    TargetMock public targetMock;

    address public owner1 = address(0x1111);
    address public owner2 = address(0x2222);
    address public owner3 = address(0x3333);
    address public nonOwner = address(0x4444);
    address public recipient = address(0x5555);

    address[] public owners;
    uint256 public required = 2; // 2 out of 3 multisig

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed executor, uint256 indexed txIndex);

    function setUp() public {
        owners.push(owner1);
        owners.push(owner2);
        owners.push(owner3);

        wallet = new MultiSigWallet(owners, required);
        targetMock = new TargetMock();

        // Give wallet some funds
        vm.deal(address(wallet), 10 ether);
    }

    // --- Constructor Tests ---

    function test_Constructor_Success() public view {
        assertEq(wallet.required(), 2);
        assertEq(wallet.getOwners().length, 3);
        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));
    }

    function test_Constructor_RevertEmptyOwners() public {
        address[] memory emptyOwners = new address[](0);
        vm.expectRevert("owners required");
        new MultiSigWallet(emptyOwners, 1);
    }

    function test_Constructor_RevertInvalidRequired() public {
        vm.expectRevert("invalid number of required confirmations");
        new MultiSigWallet(owners, 0);

        vm.expectRevert("invalid number of required confirmations");
        new MultiSigWallet(owners, 4);
    }

    function test_Constructor_RevertZeroAddressOwner() public {
        address[] memory badOwners = new address[](2);
        badOwners[0] = owner1;
        badOwners[1] = address(0);
        vm.expectRevert("invalid owner");
        new MultiSigWallet(badOwners, 1);
    }

    function test_Constructor_RevertDuplicateOwner() public {
        address[] memory dupOwners = new address[](3);
        dupOwners[0] = owner1;
        dupOwners[1] = owner2;
        dupOwners[2] = owner1;
        vm.expectRevert("owner not unique");
        new MultiSigWallet(dupOwners, 2);
    }

    // --- Deposit Test ---

    function test_Deposit() public {
        vm.deal(nonOwner, 1 ether);
        vm.prank(nonOwner);
        (bool success, ) = address(wallet).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(wallet).balance, 11 ether);
    }

    // --- Submit Transaction Tests ---

    function test_SubmitTransaction_ByOwner() public {
        vm.prank(owner1);
        vm.expectEmit(true, true, true, true);
        emit SubmitTransaction(owner1, 0, recipient, 1 ether, "");
        uint256 txIndex = wallet.submitTransaction(recipient, 1 ether, "");

        assertEq(txIndex, 0);
        assertEq(wallet.getTransactionCount(), 1);

        (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        ) = wallet.getTransaction(0);

        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(data.length, 0);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
    }

    function test_SubmitTransaction_RevertNonOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.submitTransaction(recipient, 1 ether, "");
    }

    // --- Confirm Transaction Tests ---

    function test_ConfirmTransaction_Success() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        vm.expectEmit(true, true, false, true);
        emit ConfirmTransaction(owner1, 0);
        wallet.confirmTransaction(0);

        (, , , , uint256 numConfirmations) = wallet.getTransaction(0);
        assertEq(numConfirmations, 1);
        assertTrue(wallet.isConfirmed(0, owner1));
    }

    function test_ConfirmTransaction_RevertNonOwner() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(nonOwner);
        vm.expectRevert("not owner");
        wallet.confirmTransaction(0);
    }

    function test_ConfirmTransaction_RevertTxDoesNotExist() public {
        vm.prank(owner1);
        vm.expectRevert("tx does not exist");
        wallet.confirmTransaction(99);
    }

    function test_ConfirmTransaction_RevertAlreadyConfirmed() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("tx already confirmed");
        wallet.confirmTransaction(0);
    }

    // --- Revoke Confirmation Tests ---

    function test_RevokeConfirmation_Success() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectEmit(true, true, false, true);
        emit RevokeConfirmation(owner1, 0);
        wallet.revokeConfirmation(0);

        (, , , , uint256 numConfirmations) = wallet.getTransaction(0);
        assertEq(numConfirmations, 0);
        assertFalse(wallet.isConfirmed(0, owner1));
    }

    function test_RevokeConfirmation_RevertNotConfirmed() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        vm.expectRevert("tx not confirmed");
        wallet.revokeConfirmation(0);
    }

    // --- Execute Transaction Tests ---

    function test_ExecuteTransaction_RevertInsufficientConfirmations() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        // Only 1 confirmation (required is 2)
        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner1);
        vm.expectRevert("cannot execute tx: insufficient confirmations");
        wallet.executeTransaction(0);
    }

    function test_ExecuteTransaction_ByAnyoneWhenThresholdMet() public {
        // 1. owner1 submits transaction
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 2 ether, "");

        // 2. owner1 & owner2 confirm transaction
        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner2);
        wallet.confirmTransaction(0);

        uint256 recipientBalBefore = recipient.balance;
        uint256 walletBalBefore = address(wallet).balance;

        // 3. nonOwner (ANYONE) executes the transaction
        vm.prank(nonOwner);
        vm.expectEmit(true, true, false, true);
        emit ExecuteTransaction(nonOwner, 0);
        wallet.executeTransaction(0);

        // Verify recipient received ETH & transaction state is executed
        assertEq(recipient.balance, recipientBalBefore + 2 ether);
        assertEq(address(wallet).balance, walletBalBefore - 2 ether);

        (, , , bool executed, uint256 numConfirmations) = wallet.getTransaction(0);
        assertTrue(executed);
        assertEq(numConfirmations, 2);
    }

    function test_ExecuteTransaction_WithContractCall() public {
        bytes memory data = abi.encodeWithSelector(TargetMock.setValue.selector, 888);

        vm.prank(owner1);
        wallet.submitTransaction(address(targetMock), 0.5 ether, data);

        vm.prank(owner1);
        wallet.confirmTransaction(0);

        vm.prank(owner3);
        wallet.confirmTransaction(0);

        // Execute by anyone
        vm.prank(nonOwner);
        wallet.executeTransaction(0);

        // Verify TargetMock contract state
        assertEq(targetMock.value(), 888);
        assertEq(targetMock.sender(), address(wallet));
        assertEq(address(targetMock).balance, 0.5 ether);
    }

    function test_ExecuteTransaction_RevertAlreadyExecuted() public {
        vm.prank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");

        vm.prank(owner1);
        wallet.confirmTransaction(0);
        vm.prank(owner2);
        wallet.confirmTransaction(0);

        wallet.executeTransaction(0);

        vm.expectRevert("tx already executed");
        wallet.executeTransaction(0);
    }
}
