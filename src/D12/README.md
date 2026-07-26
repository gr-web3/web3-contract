# 第十二课：Permit2 签名授权存款 (Permit2 Deposit Practice)

本目录包含第十二课关于 Uniswap `Permit2` 签名授权转账存款的代码、测试与前端演示。

---

## 1. 什么是 Uniswap Permit2？

在以太坊传统的 ERC20 代币设计中，用户要向合约存入代币通常有两种机制：
1. **传统的 `approve` + `transferFrom`**：
   - 缺点：每次向新合约存款前，必须先在链上发起一笔 `approve` 交易（消耗 Gas 且体验割裂）。
2. **ERC2612 扩展 `permit`**：
   - 优点：支持 EIP-712 签名授权，免去 `approve` 的 Gas。
   - 缺点：必须在代币合约编写时显式继承支持，无法兼容已部署的老旧 ERC20 代币（如 USDT, WBTC）。

**Uniswap `Permit2` 的突破性解决方案**：
- Uniswap 在主网及各 EVM 链上部署了 Canonical `Permit2` 智能合约（固定地址：`0x000000000022D473030F116dDEE9F6B43aC78BA3`）。
- 用户只需对 `Permit2` 合约授权一次（无限额度授权），之后所有集成了 `Permit2` 的第三方应用（如 `TokenBank`）均可通过**链下 EIP-712 签名**直接拉取代币，**无需代币本身原生支持 ERC2612**。

---

## 2. 合约设计 (`TokenBankPermit2.sol`)

### 2.1 关键方法 `depositWithPermit2`

```solidity
function depositWithPermit2(
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
) external {
    require(amount > 0, "TokenBank: amount must be greater than zero");

    // 1. 构造 PermitTransferFrom 结构体
    IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
        permissions: IPermit2.TokenPermissions({
            token: address(token),
            amount: amount
        }),
        nonce: nonce,
        deadline: deadline
    });

    // 2. 构造 SignatureTransferDetails 结构体
    IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
        to: address(this),
        requestedAmount: amount
    });

    // 3. 调用 Permit2 合约拉取代币转入 TokenBank
    IPermit2(permit2).permitTransferFrom(
        permit,
        transferDetails,
        msg.sender,
        signature
    );

    // 4. 记账并触发 Deposit 事件
    tokenNum[msg.sender] += amount;
    emit Deposit(msg.sender, amount);
}
```

---

## 3. 前端 EIP-712 签名数据结构

在前端（如 `main.js`），针对 `Permit2` 的签名格式如下：

### Domain 结构
```javascript
const domain = {
  name: 'Permit2',
  chainId: currentChainId,
  verifyingContract: '0x000000000022D473030F116dDEE9F6B43aC78BA3'
};
```

### Types 格式
```javascript
const types = {
  PermitTransferFrom: [
    { name: 'permitted', type: 'TokenPermissions' },
    { name: 'spender', type: 'address' },
    { name: 'nonce', type: 'uint256' },
    { name: 'deadline', type: 'uint256' }
  ],
  TokenPermissions: [
    { name: 'token', type: 'address' },
    { name: 'amount', type: 'uint256' }
  ]
};
```

### 消息内容 (Message)
```javascript
const message = {
  permitted: {
    token: TOKEN_ADDRESS,
    amount: amountInWei.toString()
  },
  spender: TOKEN_BANK_PERMIT2_ADDRESS,
  nonce: nonce,
  deadline: deadline
};
```

---

## 4. 测试与验证 (`TokenBankPermit2.t.sol`)

运行 Foundry 单元测试命令：
```bash
forge test --match-path test/TokenBankPermit2.t.sol -vvv
```

测试覆盖：
1. `test_StandardDepositAndWithdraw`：标准转账存款与提款。
2. `test_DepositWithPermit2_Success`：使用 Permit2 签名授权存款成功。
3. `test_DepositWithPermit2_RevertExpiredDeadline`：过期签名拦截。
4. `test_DepositWithPermit2_RevertNonceReused`：重复 Nonce 签名拦截。
5. `test_AdminWithdrawAll`：管理员一键提取所有资产。

---

## 5. 目录结构

- 接口定义：[IPermit2.sol](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D12/IPermit2.sol)
- 核心合约：[TokenBankPermit2.sol](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D12/TokenBankPermit2.sol)
- 测试模拟：[MockPermit2.sol](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/test/mocks/MockPermit2.sol)
- 单元测试：[TokenBankPermit2.t.sol](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/test/TokenBankPermit2.t.sol)
- 前端源码：[src/D12/frontend/](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D12/frontend/)
