# 读取以太坊私有变量 (Private Variables) 理论与实践指南

本指南记录了第十五课 15.3 节关于**如何通过分析以太坊存储布局 (Storage Layout) 物理读取合约中私有变量**的完整理论、算式推导与代码实践。

---

## 一、 核心概念与理论

1. **可见性 (Visibility) vs 物理隐私 (Privacy)**
   Solidity 中的 `private` 关键字**仅作用于编译期的访问权限控制**，阻止其他合约通过代码直接访问，并不自动生成公共 Getter。
   然而，在以太坊区块链上，**所有存入节点磁盘（LevelDB / PebbleDB）的状态数据都是 100% 透明公开的**。

2. **存储槽 (Storage Slot) 概念**
   - EVM 状态存储划分为独立的 32 字节 (256 bits) 槽位，编号从 `0` 递增。
   - 只要能够推算出目标私有变量所在的 **Slot 编号** 与 **Offset 偏移量**，即可通过底层 JSON-RPC (`eth_getStorageAt`) 或测试工具 (`vm.load`) 物理解密读取。

---

## 二、 4 大不同类型私有变量的 Slot 计算公式

基于 `src/D15/PrivateVault.sol` 合约的实际布局：

```text
╭----------------+-----------------------------+------+--------+-------+
| Name           | Type                        | Slot | Offset | Bytes |
+======================================================================+
| secretPassword | uint256                     | 0    | 0      | 32    |
| admin          | address                     | 1    | 0      | 20    |
| vaultId        | uint96                      | 1    | 20     | 12    |
| userRewards    | mapping(address => uint256) | 2    | 0      | 32    |
| secretCodes    | uint256[]                   | 3    | 0      | 32    |
╰----------------+-----------------------------+------+--------+-------+
```

### 1. 独立标量私有变量 (`secretPassword`)
- **位置**：Slot 0，独占 32 字节。
- **读取代码**：
  ```solidity
  bytes32 slot0Data = vm.load(targetAddress, bytes32(uint256(0)));
  uint256 secretPassword = uint256(slot0Data);
  ```

### 2. 紧凑打包的私有变量 (`admin` + `vaultId`)
- **位置**：Slot 1。
  - `admin` (160 bits)：位于低位 (Offset 0)。
  - `vaultId` (96 bits)：位于高位 (Offset 20 字节 = 160 bits)。
- **读取代码**：
  ```solidity
  bytes32 slot1Data = vm.load(targetAddress, bytes32(uint256(1)));
  uint256 rawValue = uint256(slot1Data);

  // 截取低 160 位获取 address
  address admin = address(uint160(rawValue));

  // 右移 160 位截取高 96 位获取 uint96
  uint96 vaultId = uint96(rawValue >> 160);
  ```

### 3. 映射类型私有变量 (`userRewards`)
- **位置**：Slot 2 仅作为映射标识占位。
- **物理计算公式**：
  $$\text{TargetSlot} = \text{keccak256}(\text{abi.encode}(\text{key}, \text{mappingSlotIndex}))$$
- **读取代码**：
  ```solidity
  bytes32 rewardSlot = keccak256(abi.encode(userAddress, uint256(2)));
  bytes32 rewardData = vm.load(targetAddress, rewardSlot);
  uint256 userReward = uint256(rewardData);
  ```

### 4. 动态数组私有变量 (`secretCodes`)
- **位置**：Slot 3 存储数组的**当前长度 length**。
- **物理计算公式**：
  - 起始元素物理 Slot：$\text{StartSlot} = \text{keccak256}(\text{abi.encode}(\text{arraySlotIndex}))$
  - 第 $i$ 个元素物理 Slot：$\text{StartSlot} + i$
- **读取代码**：
  ```solidity
  // 1. 读取数组长度
  bytes32 lengthData = vm.load(targetAddress, bytes32(uint256(3)));
  uint256 length = uint256(lengthData);

  // 2. 读取第 i 个元素
  bytes32 startSlot = keccak256(abi.encode(uint256(3)));
  bytes32 element0Data = vm.load(targetAddress, bytes32(uint256(startSlot) + 0));
  uint256 code0 = uint256(element0Data);
  ```

---

## 三、 测试用例验证结果

命令：
```bash
forge test --match-contract D15_PrivateVaultTest -vv
```

运行输出：
```text
Ran 4 tests for test/D15_PrivateVault.t.sol:D15_PrivateVaultTest
[PASS] test_ReadPrivateArray_Slot3() (gas: 12897)
[PASS] test_ReadPrivateMapping_Slot2() (gas: 10527)
[PASS] test_ReadPrivatePacked_Slot1() (gas: 8372)
[PASS] test_ReadPrivateScalar_Slot0() (gas: 7933)
Suite result: ok. 4 passed; 0 failed; 0 skipped
```

---

## 四、 结论与安全启示

1. **绝对不要将敏感私有数据（如明文密码、API Key、私钥等）保存在以太坊状态变量中**，即使加上了 `private` 限制。
2. 链上数据的隐私必须建立在零知识证明（Zero-Knowledge Proofs）或链外安全同态加密/机密计算之上。
