// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {AssemblyOwner} from "../src/D15/AssemblyOwner.sol";

contract D15_AssemblyOwnerTest is Test {
    AssemblyOwner public target;
    address public admin = address(0x1111);
    address public newAdmin = address(0x2222);
    address public stranger = address(0x3333);

    function setUp() public {
        vm.prank(admin);
        target = new AssemblyOwner();
    }

    function test_GetOwnerSlot() public view {
        // 1. 验证 owner 变量所在的 Slot 编号确实为 0
        uint256 slot = target.getOwnerSlot();
        assertEq(slot, 0, "Owner slot should be 0");
    }

    function test_ReadOwnerWithAssembly() public view {
        // 2. 验证内联汇编读取的地址与 Solidity getter `owner()` 返回的地址一致
        address ownerFromSolidity = target.owner();
        address ownerFromAssembly = target.getOwnerWithAssembly();

        assertEq(ownerFromSolidity, admin);
        assertEq(ownerFromAssembly, admin);
        assertEq(ownerFromAssembly, ownerFromSolidity);
    }

    function test_WriteOwnerWithAssembly() public {
        // 3. 验证通过内联汇编修改 owner 成功
        vm.prank(admin);
        target.setOwnerWithAssembly(newAdmin);

        assertEq(target.owner(), newAdmin);
        assertEq(target.getOwnerWithAssembly(), newAdmin);
    }

    function test_RevertWhen_NonOwnerCallsSetOwner() public {
        // 非 Owner 调用修改应当 revert
        vm.prank(stranger);
        vm.expectRevert(AssemblyOwner.OnlyOwner.selector);
        target.setOwnerWithAssembly(newAdmin);
    }

    function test_VerifyWithFoundryCheatcodes() public {
        // 4. 使用 Foundry Cheatcode `vm.load` 读取 Slot 0 进行双重校验
        bytes32 slot0Data = vm.load(address(target), bytes32(uint256(0)));
        address ownerFromVmLoad = address(uint160(uint256(slot0Data)));
        assertEq(ownerFromVmLoad, admin);

        // 5. 使用 Foundry Cheatcode `vm.store` 直接修改合约 Slot 0 进行双重校验
        vm.store(address(target), bytes32(uint256(0)), bytes32(uint256(uint160(newAdmin))));

        assertEq(target.owner(), newAdmin);
        assertEq(target.getOwnerWithAssembly(), newAdmin);
    }
}
