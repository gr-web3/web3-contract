// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {PrivateVault} from "../src/D15/PrivateVault.sol";

contract D15_PrivateVaultTest is Test {
    PrivateVault public vault;

    uint256 public expectedPassword = 987654321;
    address public expectedAdmin = address(0xAAAA);
    uint96 public expectedVaultId = 88888;

    address public user = address(0xBBBB);
    uint256 public expectedReward = 5000 * 10 ** 18;
    uint256 public expectedCode1 = 112233;
    uint256 public expectedCode2 = 445566;

    function setUp() public {
        vault = new PrivateVault(expectedPassword, expectedAdmin, expectedVaultId);

        vm.prank(expectedAdmin);
        vault.initializeData(user, expectedReward, expectedCode1, expectedCode2);
    }

    /**
     * @dev 1. 读取 Slot 0：独立的 uint256 标量私有变量 (secretPassword)
     */
    function test_ReadPrivateScalar_Slot0() public view {
        bytes32 slot0Data = vm.load(address(vault), bytes32(uint256(0)));
        uint256 readPassword = uint256(slot0Data);

        assertEq(readPassword, expectedPassword, "Password from Slot 0 mismatch");
    }

    /**
     * @dev 2. 读取 Slot 1：紧凑打包存储的私有变量 (admin 与 vaultId)
     * admin (160 bits, 低位) + vaultId (96 bits, 高位)
     */
    function test_ReadPrivatePacked_Slot1() public view {
        bytes32 slot1Data = vm.load(address(vault), bytes32(uint256(1)));
        uint256 rawValue = uint256(slot1Data);

        // 低 160 位为 address admin
        address readAdmin = address(uint160(rawValue));

        // 右移 160 位获取高 96 位的 uint96 vaultId
        uint96 readVaultId = uint96(rawValue >> 160);

        assertEq(readAdmin, expectedAdmin, "Admin from Slot 1 mismatch");
        assertEq(readVaultId, expectedVaultId, "VaultId from Slot 1 mismatch");
    }

    /**
     * @dev 3. 读取 Slot 2：私有映射变量 (userRewards)
     * 计算公式: keccak256(abi.encode(key, slot_index))
     */
    function test_ReadPrivateMapping_Slot2() public view {
        uint256 mappingSlotIndex = 2;

        // 计算 key 在 mapping 中对应的物理 Slot
        bytes32 targetSlot = keccak256(abi.encode(user, mappingSlotIndex));
        bytes32 slotData = vm.load(address(vault), targetSlot);

        uint256 readReward = uint256(slotData);

        assertEq(readReward, expectedReward, "User reward from mapping mismatch");
    }

    /**
     * @dev 4. 读取 Slot 3：私有动态数组变量 (secretCodes)
     * - Slot 3 存储数组长度 length
     * - 元素起止 Slot 计算公式: keccak256(abi.encode(slot_index)) + element_index
     */
    function test_ReadPrivateArray_Slot3() public view {
        uint256 arraySlotIndex = 3;

        // 1. 读取 Slot 3 本身获取数组长度
        bytes32 lengthData = vm.load(address(vault), bytes32(arraySlotIndex));
        uint256 arrayLength = uint256(lengthData);

        assertEq(arrayLength, 2, "Array length from Slot 3 mismatch");

        // 2. 计算数组第 0 个和第 1 个元素的起始物理 Slot
        bytes32 startSlot = keccak256(abi.encode(arraySlotIndex));

        bytes32 code1Data = vm.load(address(vault), bytes32(uint256(startSlot) + 0));
        bytes32 code2Data = vm.load(address(vault), bytes32(uint256(startSlot) + 1));

        uint256 readCode1 = uint256(code1Data);
        uint256 readCode2 = uint256(code2Data);

        assertEq(readCode1, expectedCode1, "Array element [0] mismatch");
        assertEq(readCode2, expectedCode2, "Array element [1] mismatch");
    }
}
