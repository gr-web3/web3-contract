// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title AssemblyOwner
 * @notice 演示使用 Solidity 内联汇编 (Inline Assembly / Yul) 确定、读取及修改 Owner Slot 的合约
 */
contract AssemblyOwner {
    // 状态变量声明在首位，默认分配在 Storage Slot 0
    address public owner;

    // 自定义 Error 节约 Gas
    error OnlyOwner();
    error ZeroAddress();

    event OwnerChanged(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
    }

    /**
     * @dev 获取 owner 变量在存储槽中的索引编号
     */
    function getOwnerSlot() external pure returns (uint256 slot) {
        assembly {
            slot := owner.slot
        }
    }

    /**
     * @dev 使用内联汇编 (sload) 读取 owner Slot 的地址值
     */
    function getOwnerWithAssembly() external view returns (address ownerAddress) {
        assembly {
            // sload 从指定 slot (owner.slot即0号槽) 读取 32 字节数据
            // EVM 自动将 32 字节中的低 20 字节 (160 bits) 截取为 address 类型
            ownerAddress := sload(owner.slot)
        }
    }

    /**
     * @dev 使用内联汇编 (sstore) 修改/更新 owner Slot 的地址值
     * @param newOwner 新的 Owner 地址
     */
    function setOwnerWithAssembly(address newOwner) external {
        if (msg.sender != owner) revert OnlyOwner();
        if (newOwner == address(0)) revert ZeroAddress();

        address oldOwner = owner;

        assembly {
            // sstore 将 32 字节数据写入指定 slot (owner.slot即0号槽)
            sstore(owner.slot, newOwner)
        }

        emit OwnerChanged(oldOwner, newOwner);
    }
}
