# 第十一课：多签钱包实践 (Multi-Signature Wallet Practice)

本目录包含第十一课关于多签钱包实践的代码与文档说明。

---

## 1. Safe 多签钱包学习与实践

### 1.1 什么是 Safe 多签钱包？
[Safe](https://safe.global/) (原 Gnosis Safe) 是以太坊及 EVM 链上最受欢迎、经受过最严苛安全审计的多签智能合约钱包。

相比传统的单私钥账户 (EOA)，Safe 钱包本质上是一个智能合约账户，采用 **M-of-N 多重签名** 控制逻辑：
- **多持有人 (Owners)**：指定 N 个 EOA 地址作为多签持有人。
- **签名门槛 (Threshold)**：设定至少需要 M 个持有人的签名授权才能执行一笔交易 (例如 2-of-3、3-of-5)。
- **安全防护**：防范单点故障（如私钥泄露或丢失）、内部作恶以及恶意巨额转账。

---

### 1.2 Safe 的基本使用流程
1. **创建 Safe 多签钱包**：
   - 连接 EOA 钱包（如 MetaMask），在 Safe 界面指定多签持有人地址列表（如 `Owner A`, `Owner B`, `Owner C`）。
   - 设置签名门槛（如 `2` 人确认）。
   - Safe 工厂合约为其部署专用的 Proxy 代理合约。

2. **提交与签名交易 (Propose & Sign)**：
   - 任意多签持有人可发起一笔待执行的交易（如转账 ETH/ERC20 或调用 DeFi 合约）。
   - 发起者通过 EOA 离线签名（EIP-712 签名），Safe 后端服务器将收集并广播该待确认交易。
   - 其他多签持有人登录 Safe 界面，查看交易 Payload 并进行 EIP-712 签名。

3. **执行交易 (Execute)**：
   - 当离线签名数量达到设置的 Threshold (门槛) 时，**任何人**（包含自动化 Bot 或任意持有人）均可在链上发送 `execTransaction` 交易，将打包好的多签签名数组一次性提交给 Safe 合约校验并执行底层调用。

---

## 2. 简易多签钱包合约设计 (`MultiSigWallet.sol`)

为了深刻理解 Safe 的底层核心机制，我们实现了一个符合作业要求的简单多签钱包合约：

### 2.1 核心功能与规则

1. **构造初始化 (`constructor`)**：
   - 传入持有人数组 `owners` 及确认门槛 `required`。
   - 校验：门槛数 $0 < required \le owners.length$，且持有人地址不能为零地址或重复。

2. **持有人提交交易 (`submitTransaction`)**：
   - 仅限持有人 (`onlyOwner`) 调用。
   - 保存交易目标地址 `to`、金额 `value`、数据 `data` 到 `transactions` 数组中。

3. **持有人确认交易 (`confirmTransaction`)**：
   - 仅限持有人 (`onlyOwner`) 调用。
   - 通过链上交易方式确认，每人每笔交易只能确认一次 (`notConfirmed`)。

4. **持有人撤销确认 (`revokeConfirmation`)**：
   - 在交易未执行前，已确认的持有人可以撤销自己的确认。

5. **达到门槛后执行交易 (`executeTransaction`)**：
   - **任何人均可调用**（无需 `onlyOwner` 修饰器）。
   - 校验 `transaction.numConfirmations >= required` 且 `!executed`。
   - 使用底层低级调用 `(bool success, ) = transaction.to.call{value: transaction.value}(transaction.data)` 执行具体交易。

---

## 3. 测试与验证 (`MultiSigWallet.t.sol`)

使用 Foundry 框架对合约进行了 18 个测试用例的全方位验证：

### 运行测试命令
```bash
forge test --match-path test/MultiSigWallet.t.sol -vvv
```

### 测试结果
```text
Ran 18 tests for test/MultiSigWallet.t.sol:MultiSigWalletTest
[PASS] test_ConfirmTransaction_RevertAlreadyConfirmed()
[PASS] test_ConfirmTransaction_RevertNonOwner()
[PASS] test_ConfirmTransaction_RevertTxDoesNotExist()
[PASS] test_ConfirmTransaction_Success()
[PASS] test_Constructor_RevertDuplicateOwner()
[PASS] test_Constructor_RevertEmptyOwners()
[PASS] test_Constructor_RevertInvalidRequired()
[PASS] test_Constructor_RevertZeroAddressOwner()
[PASS] test_Constructor_Success()
[PASS] test_Deposit()
[PASS] test_ExecuteTransaction_ByAnyoneWhenThresholdMet()
[PASS] test_ExecuteTransaction_RevertAlreadyExecuted()
[PASS] test_ExecuteTransaction_RevertInsufficientConfirmations()
[PASS] test_ExecuteTransaction_WithContractCall()
[PASS] test_RevokeConfirmation_RevertNotConfirmed()
[PASS] test_RevokeConfirmation_Success()
[PASS] test_SubmitTransaction_ByOwner()
[PASS] test_SubmitTransaction_RevertNonOwner()
Suite result: ok. 18 passed; 0 failed; 0 skipped
```

重点验证了作业要求的 **"达到多签门槛后，任何人都可以执行该交易"** (`test_ExecuteTransaction_ByAnyoneWhenThresholdMet`)。

---

## 4. 文件路径结构

- 核心合约：[MultiSigWallet.sol](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D11/MultiSigWallet.sol)
- 测试用例：[MultiSigWallet.t.sol](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/test/MultiSigWallet.t.sol)
- 实践文档：[README.md](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D11/README.md)
