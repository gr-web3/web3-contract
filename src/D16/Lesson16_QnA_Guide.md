# 第十六课：AirdropMerkleNFTMarket 核心技术与 Q&A 问答指南

本文档总结了第十六课 **默克尔树白名单与 Multicall 结合（AirdropMerkleNFTMarket）** 的核心架构、代码详解以及针对关键技术点的 Q&A 问答。

---

## 一、 整体架构与交易时序

`AirdropMerkleNFTMarket` 通过融合 **Multicall (`delegatecall`)**、**ERC20 Permit (EIP-2612 签名)** 与 **Merkle Tree (白名单证明)**，实现了用户在**零链上预授权 + 单笔以太坊交易**中完成 100 Token 扣款与 NFT 优惠交付。

### 交易时序流程图 (ASCII Sequence Diagram)

```text
 ┌──────────┐                     ┌───────────────────────────┐                    ┌──────────────┐
 │  用 户   │                     │ AirdropMerkleNFTMarket    │                    │  ERC20Token  │
 └────┬─────┘                     └─────────────┬─────────────┘                    └──────┬───────┘
      │ 1. 链下签名 EIP-712 Permit (授权100Token)│                                         │
      │    链下生成 Merkle Proof 白名单证明      │                                         │
      │ ───────────────────────────────────────>│                                         │
      │                                         │                                         │
      │ 2. 发送单笔交易: multicall([Call1, Call2])│                                        │
      │ ───────────────────────────────────────>│                                         │
      │                                         │ 3. 执行 Call 1: permitPrePay()          │
      │                                         │ ───────────────────────────────────────>│
      │                                         │    调用 token.permit(User, Market, 100) │
      │                                         │<────────────────────────────────────────│
      │                                         │    (额度 100 Token 授权成功)            │
      │                                         │                                         │
      │                                         │ 4. 执行 Call 2: claimNFT()              │
      │                                         │ ┌─────────────────────────────────────┐ │
      │                                         │ │ (1) MerkleProof 校验 User 白名单    │ │
      │                                         │ │ (2) 检查 hasClaimed[User] 防重领      │ │
      │                                         │ └─────────────────────────────────────┘ │
      │                                         │                                         │
      │                                         │ 5. transferFrom(User, Market, 100)     │
      │                                         │ ───────────────────────────────────────>│
      │                                         │<────────────────────────────────────────│
      │                                         │    (扣除 100 Token)                     │
      │                                         │                                         │
      │ 6. 划转并交付 NFT 给用户                │                                         │
      │<────────────────────────────────────────│                                         │
 ┌────┴─────┐                     ┌─────────────┴─────────────┐                    └──────┴───────┘
 │  用 户   │                     │ AirdropMerkleNFTMarket    │                    │  ERC20Token  │
 └──────────┘                     └───────────────────────────┘                    └──────────────┘
```

---

## 二、 关键技术 Q&A 问答总结

### Q1：函数声明中的 `external` 关键字有什么用？两侧语法怎么理解？

**回答**：
1. **语法结构**：Solidity 的标准顺序为 `function 函数名(入参) [visibility] [state-mutability] { 函数体 }`。`external` 紧跟在输入参数括号 `)` 的右侧。
2. **Gas 优化原理**：
   - `public` 函数的参数会被强行复制到 `memory` 中；
   - `external` 函数只能从外部（或通过 `Multicall` 的 `delegatecall`）调用，其参数保留在只读的 **`calldata`** 中，不需要进行内存分配，**性能更高、Gas 更低**。

---

### Q2：`AirdropToken.sol` 的构造函数为什么长这样？

```solidity
contract AirdropToken is ERC20, ERC20Permit {
    constructor() ERC20("AirdropToken", "ADT") ERC20Permit("AirdropToken") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}
```

**回答**：
1. **多重继承初始化**：`AirdropToken` 同时继承了 `ERC20` 和 `ERC20Permit`。在 Solidity 中，必须在构造函数头显式调用两个父类的构造函数。
2. **`ERC20("AirdropToken", "ADT")`**：初始化代币全称 (Name) 与交易符号 (Symbol)。
3. **`ERC20Permit("AirdropToken")`**：初始化 EIP-712 签名中的 **`DOMAIN_SEPARATOR`（域分割符）** 的名称。前端链下对 `permit` 消息签名时，EIP-712 中的 `name` 必须与该字符串**完全一致**。
4. **`1_000_000`**：下划线是 Solidity 0.8+ 支持的千分位分隔符，等同于 `1000000`。

---

### Q3：`claimNFT` 函数的具体逻辑与安全细节是怎样的？

```solidity
function claimNFT(uint256 tokenId, bytes32[] calldata proof) external {
    if (hasClaimed[msg.sender]) revert AlreadyClaimed();

    // 二次哈希规避 64 字节二次原像攻击
    bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
    if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidProof();

    // 遵循 CEI 模式：先改状态防重入
    hasClaimed[msg.sender] = true;

    // 扣除 100 Token 优惠价
    bool success = token.transferFrom(msg.sender, address(this), DISCOUNT_PRICE);
    if (!success) revert TransferFailed();

    // 交付 NFT
    address seller = nft.ownerOf(tokenId);
    nft.safeTransferFrom(seller, msg.sender, tokenId);

    emit NFTSold(tokenId, msg.sender, DISCOUNT_PRICE);
}
```

**核心步骤解析**：
1. **防重领检查**：查 `hasClaimed` 映射，保证每个白名单地址仅能优惠购买 1 次。
2. **二次哈希白名单验证**：`bytes.concat(keccak256(...))` 属于 OpenZeppelin 推荐标准，防止默克尔树的 64 字节中间节点冒充叶子节点攻击。
3. **CEI 模式**：在转移 Token / NFT 之前先设置 `hasClaimed[msg.sender] = true`，杜绝重入攻击。
4. **扣款与交付**：利用前一步 `permitPrePay` 设置好的 Allowance 完成扣款并交付 NFT。

---

### Q4：Allowance 是什么？

**回答**：
- **定义**：Allowance 是 ERC20 标准中的 **授权额度 / 信用额度**。
- **数据结构**：ERC20 合约内部维护着 `mapping(address owner => mapping(address spender => uint256)) public allowance;`
- **传统方式**：用户发送 `token.approve(market, amount)` 链上交易设置 Allowance。
- **Permit 零 Gas 方式**：用户在链下对消息签名 `(v, r, s)` $\rightarrow$ 市场合约提交 `permit` 签名 $\rightarrow$ 代币合约校验无误后**自动将 `allowance[user][market]` 设为 100 Token**。

---

### Q5：代码中把 Token 转给了 `address(this)`，不应该转给 NFT 持有人吗？

**回答**：
这取决于**业务模式**：
1. **项目方官方白名单 Sale / Airdrop（当前代码模式）**：NFT 由项目方统一售卖，买家支付的 100 Token 作为**项目方/协议收入**，因此统一转入市场合约 `address(this)`（后续由管理员提取）。市场合约本身就是 Seller。
2. **C2C 自由交易市场**：买家从散户卖家手人购买 NFT。资金应直接转给真正的卖家 `seller = nft.ownerOf(tokenId)`。
- **通用写法**：使用 `token.transferFrom(msg.sender, seller, DISCOUNT_PRICE);` 可同时兼容上述两种场景。

---

### Q6：Permit 零 Gas 授权具体是在哪里做、怎么实现的？

**回答**：
1. **代码调用位置**：在 `AirdropMerkleNFTMarket.sol` 的 `permitPrePay` 中：
   `IERC20Permit(address(token)).permit(owner, spender, value, deadline, v, r, s);`
2. **代币合约内部实现 (OpenZeppelin ERC20Permit 源码)**：
   - 检查 `block.timestamp <= deadline`。
   - 重新在链上根据参数组装 EIP-712 结构化哈希 `hash`。
   - 调用 EVM 底层 `ECDSA.recover(hash, v, r, s)` **还原出签名者地址 `signer`**。
   - 校验 `require(signer == owner)`。
   - 验证成功后，代币合约内部直接执行 `_allowances[owner][spender] = value;` 写入物理存储！
