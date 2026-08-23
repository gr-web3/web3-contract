# 第二十课 ERC20 代币线性释放 (TokenVesting) - 操作指南与原理解析

本文档包含 **第二十课 (代币锁仓与线性释放 Vesting)** 的核心智能合约架构、数学公式推导、Foundry 时间模拟 (`vm.warp`) 测试以及操作说明。

---

## 一、 合约功能与 Vesting 释放规则

在 Web3 项目代币经济学（Tokenomics）中，为了防止团队与早期投资人解锁后砸盘，通常会设计 **Vesting (代币锁仓与线性解锁)** 机制。

### 参数配置与计算公式
- **受益人 (`beneficiary`)**：解锁代币的接收地址。
- **锁定的 ERC20 代币 (`token`)**：支持任意 ERC20 代币资产（部署时注入 100 万 Token）。
- **起点时间 (`startTimestamp`)**：部署/起始时刻。
- **悬崖期 (`CLIFF_DURATION`)**：**12 个月** (360 天)。在前 12 个月内，解锁代币数量为 `0`。
- **线性释放期 (`VESTING_DURATION`)**：**接下来的 24 个月** (720 天)。从第 13 个月起开始每月解锁 $\frac{1}{24}$ 的代币资产。
- **总释放时长 (`TOTAL_DURATION`)**：36 个月 (1080 天)。36 个月到达后，100% 代币完全解锁。

### 解锁计算算术逻辑 (Math Formula)

设合约在任意时间戳 $t$ 时的状态如下：
- $T_{\text{total}} = \text{token.balanceOf(address(this))} + \text{released}$（总分配代币量，包含历史已释放部分）
- 截至时间戳 $t$ 时的累计解禁总量 $V(t)$ 计算如下：

$$
V(t) = 
\begin{cases} 
0 & t < \text{start} + \text{CLIFF\_DURATION} \quad (\text{前 12 个月悬崖期}) \\
T_{\text{total}} & t \ge \text{start} + \text{TOTAL\_DURATION} \quad (\text{36 个月满额}) \\
\frac{T_{\text{total}} \times (t - (\text{start} + \text{CLIFF\_DURATION}))}{\text{VESTING\_DURATION}} & \text{start} + \text{CLIFF\_DURATION} \le t < \text{start} + \text{TOTAL\_DURATION}
\end{cases}
$$

- **每次可提现金额**：$\text{releasable}() = V(\text{block.timestamp}) - \text{released}$。

---

## 二、 解锁时间线图示 (Vesting Curve Timeline)

```
 解锁比例 (%)
  100% │                                                       ┌───────────── (36个月满额 100%)
       │                                                     ┌─┘
       │                                                   ┌─┘
   50% │                                                 ┌─┘ (第24个月 50%)
       │                                               ┌─┘
  1/24 │                                             ┌─┘ (第13个月解锁 1/24)
    0% └─── 悬崖期 (12个月) ──────────────────────────┴───────────────────────────── Time (时间轴)
        Month 0                                  Month 12   Month 13            Month 36
```

---

## 三、 Foundry 时间模拟测试 (`test/D20_TokenVesting.t.sol`)

Foundry 提供了极强的 cheatcode `vm.warp(timestamp)` 用于模拟以太坊区块链时间的流逝：

```bash
forge test --match-contract D20_TokenVestingTest -vvv
```

### 测试结果
```
Ran 7 tests for test/D20_TokenVesting.t.sol:D20_TokenVestingTest
[PASS] test_CliffEnd_Month12_ReturnsZero() (gas: 28399)
[PASS] test_CliffPeriod_6Months_ReturnsZero() (gas: 33691)
[PASS] test_InitialState() (gas: 24526)
[PASS] test_Month13_UnlocksOneTwentyFourth() (gas: 101510)
[PASS] test_Month24_UnlocksFiftyPercent() (gas: 89313)
[PASS] test_Month36_UnlocksOneHundredPercent() (gas: 88297)
[PASS] test_MultiplePartialReleases() (gas: 118473)
Suite result: ok. 7 passed; 0 failed; 0 skipped
```

- **`test_CliffPeriod_6Months_ReturnsZero`**：第 6 个月提取触发 Revert。
- **`test_Month13_UnlocksOneTwentyFourth`**：第 13 个月准确解锁全额资产的 $\frac{1}{24}$ ($41,666.66 \text{ Token}$)。
- **`test_Month24_UnlocksFiftyPercent`**：第 24 个月准确解锁 50% 资产 ($500,000 \text{ Token}$)。
- **`test_Month36_UnlocksOneHundredPercent`**：第 36 个月准确解锁 100% 资产 ($1,000,000 \text{ Token}$)。
