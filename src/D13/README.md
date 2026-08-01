# 第十三课：转账记录索引与展示 (Transfer Record Indexing & Display)

本目录包含第十三课关于 Web3 事件索引服务（Indexer）、后端 RESTful API 及前端转账记录仪表盘的代码与实践说明。

---

## 1. 架构原理 (Architecture Overview)

```text
+-----------------------+              监听/解析 Event Log           +-----------------------+
|  以太坊链上 ERC20 合约 | -----------------------------------------> |  后端 Indexer 索引引擎  |
+-----------------------+                                            +-----------------------+
                                                                                 |
                                                                                 | 去重写入
                                                                                 v
+-----------------------+        HTTP GET /api/transfers/:address    +-----------------------+
|  前端 Dashboard UI    | <----------------------------------------- |  SQLite / JSON 数据库  |
+-----------------------+                                            +-----------------------+
```

### 为什么需要事件索引器 (Indexer)？
1. **直接查链节点效率低**：如果每次用户进入页面都去向以太坊 RPC 节点查询过去的数万个区块，查询极慢且极易触发 RPC 限流。
2. **数据无法组合筛选**：节点只支持按区块高度查 Logs，不支持“按某钱包地址作为发送方或接收方”进行快速 SQL 模糊分页检索。
3. **Indexer 的核心作用**：后台持续拉取并解析 `Transfer(from, to, value)` 事件，存入高效的后端数据库，并暴露标准的 RESTful API 给前端消费。

---

## 2. API 接口规范

后端基于端口 `3001` 提供 RESTful 服务：

### 2.1 查询特定地址的转账记录
- **请求方式**：`GET /api/transfers/:address`
- **响应示例**：
```json
{
  "success": true,
  "address": "0x1111111111111111111111111111111111111111",
  "count": 4,
  "data": [
    {
      "id": 4,
      "hash": "0xd4e5f678901234567890abcdef...",
      "blockNumber": 19500600,
      "from": "0x1111111111111111111111111111111111111111",
      "to": "0x3333333333333333333333333333333333333333",
      "value": "120000000000000000000",
      "formattedValue": "120.00",
      "tokenSymbol": "MTK",
      "timestamp": 1785027796
    }
  ]
}
```

### 2.2 查询所有转账记录
- **请求方式**：`GET /api/transfers`

### 2.3 提交新转账记录
- **请求方式**：`POST /api/transfers`
- **Body**：`{ "hash": "0x...", "blockNumber": 19500700, "from": "0x...", "to": "0x...", "value": "1000000000000000000" }`

---

## 3. 快速运行说明

### 启动后端 API 服务
```bash
node src/D13/backend/server.js
```
运行后服务监听在 `http://localhost:3001`。

### 验证 API
```bash
curl http://localhost:3001/api/transfers/0x1111111111111111111111111111111111111111
```

### 启动前端 UI 界面
```bash
cd src/D13/frontend
npm run dev
```

---

## 4. 文件路径结构

- 后端数据库管理器：[db.js](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D13/backend/db.js)
- 后端索引器逻辑：[indexer.js](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D13/backend/indexer.js)
- RESTful API 服务器：[server.js](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D13/backend/server.js)
- 前端源码目录：[src/D13/frontend/](file:///Users/a33445566/Developer/project/w3/solidity-rel/upchain_2026/src/D13/frontend/)
