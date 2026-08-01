# 第十四课：Meme 铭文铸造工厂合约 (Minimal Proxy Inscription Factory)

本目录包含第十四课关于基于 **EIP-1167 最小代理 (Minimal Proxy)** 实现 Meme 铭文代币工厂与公平铸造的代码、测试与文档说明。

---

## 1. 底层原理 (EIP-1167 & Clones)

### 1.1 为什么采用 Minimal Proxy 模式？
传统的代币创建通过 `new MemeToken(...)` 部署，每次部署都需要向链上写入完整的 ERC20 字节码，消耗数十万至上百万 Gas 费。

**EIP-1167 最小代理标准**：
- 事先部署一份共享的**模板合约** `MemeToken`（逻辑实现）。
- 每次创建新铭文代币时，通过 OpenZeppelin `Clones.clone(implementation)` 仅部署一个只有 **45 字节** 的内联汇编代理合约。
- 该代理合约通过 `delegatecall` 将所有操作转发给模板合约，但代币余额、铭文数量等状态保存在代理合约自身空间。
- **成果**：克隆部署新铭文的 Gas 降低 **90% 以上**！

---

## 2. 核心合约设计与接口

### 2.1 工厂合约 `MemeFactory.sol`

提供作业要求的两大核心接口：

#### 方法 1：`deployInscription`
```solidity
function deployInscription(
    string memory symbol,
    uint256 totalSupply,
    uint256 perMint
) external returns (address tokenAddr);
```
- **功能**：使用 `Clones.clone` 极低 Gas 部署一个全新的 Meme 铭文代理合约，并初始化其代币符号 `symbol`、发行总量 `totalSupply` 与单次铸造量 `perMint`。

#### 方法 2：`mintInscription`
```solidity
function mintInscription(address tokenAddr) external;
```
- **功能**：向指定的铭文代币代理合约发起铸造。校验未超过 `totalSupplyCap` 后，自动为 `msg.sender` 铸造 `perMint` 额度的代币。

---

### 2.2 铭文逻辑合约 `MemeToken.sol`

- 继承 `ERC20` 与 `Initializable`。
- `constructor()` 中调用 `_disableInitializers()` 封锁模板合约本身，防范未授权篡改。
- `initialize(...)` 仅可被克隆出来的代理合约调用 1 次。
- `mint(...)` 函数内置总量上限校验 `currentMinted + perMint <= totalSupplyCap`。

---

## 3. 测试与验证 (`MemeFactory.t.sol`)

运行 Foundry 单元测试命令：
```bash
forge test --match-path test/MemeFactory.t.sol -vvv
```

### 测试结果
```text
Ran 5 tests for test/MemeFactory.t.sol:MemeFactoryTest
[PASS] test_DeployInscription_Success()
[PASS] test_MintInscription_RevertExceedsCap()
[PASS] test_MintInscription_RevertInvalidTokenAddress()
[PASS] test_MintInscription_Success()
[PASS] test_RevertReinitialize()
Suite result: ok. 5 passed; 0 failed; 0 skipped
```

---

## 4. 文件路径结构

- 铭文逻辑合约模板：[MemeToken.sol](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D14/MemeToken.sol)
- 铭文工厂合约：[MemeFactory.sol](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D14/MemeFactory.sol)
- 单元测试文件：[MemeFactory.t.sol](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/test/MemeFactory.t.sol)
- 项目文档：[README.md](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D14/README.md)
