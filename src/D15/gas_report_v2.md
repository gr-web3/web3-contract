# Gas Report v2 (优化后 - NFTMarketOptimized)

本报告记录了对 `NFTMarket` 进行全面 Gas 优化后生成的 `NFTMarketOptimized` 合约 Gas 消耗数据，以及优化前后（v1 vs v2）的对比分析说明。

## 优化前后测试用例 Gas 对比

| 测试用例名称 | v1 (Original) Gas | v2 (Optimized) Gas | 节省 Gas 数量 | 优化百分比 |
| :--- | :--- | :--- | :--- | :--- |
| `test_ListNFT()` | 199,344 | 175,384 | **-23,960** | **-12.02%** |
| `test_BuyNFT_Traditional()` | 312,774 | 294,190 | **-18,584** | **-5.94%** |
| `test_BuyNFT_Callback()` | 265,238 | 240,617 | **-24,621** | **-9.28%** |
| `test_BuyNFT_Callback_WithRefund()` | 306,516 | 281,783 | **-24,733** | **-8.07%** |

## 优化前后合约部署与函数 Gas 对比

### 合约部署（Deployment）对比

| 指标 | v1 (Original) | v2 (Optimized) | 节省数量 | 优化百分比 |
| :--- | :--- | :--- | :--- | :--- |
| **Deployment Cost** | 1,363,111 Gas | 1,111,593 Gas | **-251,518 Gas** | **-18.45%** |
| **Deployment Size** | 6,849 Bytes | 5,519 Bytes | **-1,330 Bytes** | **-19.42%** |

### 函数 Gas 消耗对比

| 函数名称 | v1 Max Gas | v2 Max Gas | Max 节省 Gas | Max 优化比例 | 核心优化因素 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `list` | 78,752 | 57,009 | **-21,743** | **-27.61%** | 结构体单 Slot 打包 (`SSTORE`) + Custom Error |
| `listings` | 5,126 | 3,217 | **-1,909** | **-37.24%** | 结构体单 Slot 打包 (`SLOAD` 从 2 次减少为 1 次) |
| `transferAndCall` (回调买) | 119,960 | 115,972 | **-3,988** | **-3.32%** | Assembly `calldataload` + Custom Error + Unchecked 退款 |

---

## 核心 Gas 优化点详细说明

### 1. 结构体存储打包 (Storage Struct Packing)
- **原理**：Solidity 存储以 32 字节 (256 bits) 为一个 Slot。
- **优化前**：
  ```solidity
  struct Listing {
      address seller; // 160 bits (占用 Slot 0)
      uint256 price;  // 256 bits (占用 Slot 1)
  }
  ```
  每次 `list` 写入和 `buyNFT` 读取都需要 **2 次 SSTORE / SLOAD** 操作。
- **优化后**：
  ```solidity
  struct Listing {
      address seller; // 160 bits
      uint96 price;   // 96 bits -> 160 + 96 = 256 bits (合并占用 Slot 0)
  }
  ```
  `seller` 与 `price` 紧凑打包在同一 32 字节槽中。`list` 上架写入时从 2 次 SSTORE 降低为 1 次 SSTORE；查询 `listings` 时从 2 次 SLOAD 降低为 1 次 SLOAD；上架删除 `delete listings[tokenId]` 释放槽位时亦仅需重置 1 个槽位。**`listings` 查询 Gas 暴降 37.24%**。

### 2. 自定义异常 (Custom Errors 替代 string require)
- **原理**：带有描述字符串的 `require("NFTMarket: ...")` 会将大量字符串保存在合约 Bytecode 中，增加 ABI 编码与解码的 Runtime 开销。
- **优化前**：使用多个 `require(condition, "NFTMarket: error string")`。
- **优化后**：定义 `error PriceZero()`, `error MarketNotApproved()` 等 Selector。
- **效果**：合约部署体积从 **6,849 Bytes 骤降至 5,519 Bytes**（缩减 1,330 字节），部署成本直接降低 **251,518 Gas (-18.45%)**。

### 3. 汇编 Calldata 直接提取 (Assembly `calldataload`)
- **原理**：在 `tokensReceived` 回调中，原本使用 `abi.decode(data, (uint256))` 会引入内存分配及完整的 ABI 解码循环。
- **优化前**：`uint256 tokenId = abi.decode(data, (uint256));`
- **优化后**：
  ```solidity
  uint256 tokenId;
  assembly {
      tokenId := calldataload(data.offset)
  }
  ```
  直接从 calldata 的偏移位置读取 32 字节的 `tokenId`，大幅减少 EVM 指令数及 Memory 拓展开销。

### 4. 无溢出运算 `unchecked` 块
- **原理**：Solidity 0.8+ 默认开启整型溢出检查。在逻辑上已经过 `if (amount > price)` 判断的地方，`amount - price` 绝不会发生下溢。
- **优化后**：使用 `unchecked { uint256 refund = amount - price; }`，省略编译器自动插入的溢出检查指令。

---

## 优化后 Output 明细

```text
Ran 4 tests for test/D15_NFTMarket.t.sol:D15_NFTMarketOptimizedTest
[PASS] test_BuyNFT_Callback() (gas: 240617)
[PASS] test_BuyNFT_Callback_WithRefund() (gas: 281783)
[PASS] test_BuyNFT_Traditional() (gas: 294190)
[PASS] test_ListNFT() (gas: 175384)
Suite result: ok. 4 passed; 0 failed; 0 skipped; finished in 1.00ms (894.21µs CPU time)

╭------------------------------------------------------------+-----------------+-------+--------+-------+---------╮
| src/D15/NFTMarketOptimized.sol:NFTMarketOptimized Contract |                 |       |        |       |         |
+=================================================================================================================+
| Deployment Cost                                            | Deployment Size |       |        |       |         |
|------------------------------------------------------------+-----------------+-------+--------+-------+---------|
|                                                    1111593 |            5519 |       |        |       |         |
|------------------------------------------------------------+-----------------+-------+--------+-------+---------|
|                                                            |                 |       |        |       |         |
|------------------------------------------------------------+-----------------+-------+--------+-------+---------|
| Function Name                                              | Min             | Avg   | Median | Max   | # Calls |
|------------------------------------------------------------+-----------------+-------+--------+-------+---------|
| buyNFT                                                     |           98537 | 98537 |  98537 | 98537 |       1 |
|------------------------------------------------------------+-----------------+-------+--------+-------+---------|
| list                                                       |           36542 | 52915 |  57009 | 57009 |       5 |
|------------------------------------------------------------+-----------------+-------+--------+-------+---------|
| listings                                                   |            3217 |  3217 |   3217 |  3217 |       2 |
╰------------------------------------------------------------+-----------------+-------+--------+-------+---------╯
```
