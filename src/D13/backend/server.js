import express from 'express';
import cors from 'cors';
import { getTransfersByAddress, getAllTransfers, insertTransfer } from './db.js';
import { seedInitialData, syncChainEvents, startLiveIndexer, TARGET_TOKEN_ADDRESS } from './indexer.js';

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// 1. 初始化种子基础数据
seedInitialData();

// 2. 启动链上历史事件拉取与实时监听器！
(async () => {
  try {
    // 拉取历史事件
    await syncChainEvents(TARGET_TOKEN_ADDRESS);
    // 开启实时监听
    startLiveIndexer(TARGET_TOKEN_ADDRESS);
  } catch (err) {
    console.warn('[Server] 链上同步初始化提示:', err.message);
  }
})();

// GET /api/transfers/:address -> 查询特定钱包地址的转账记录
app.get('/api/transfers/:address', (req, res) => {
  const { address } = req.params;
  if (!address) {
    return res.status(400).json({ error: '请提供有效的钱包地址' });
  }

  const records = getTransfersByAddress(address);
  res.json({
    success: true,
    address: address.toLowerCase(),
    count: records.length,
    data: records
  });
});

// GET /api/transfers -> 查询所有转账记录
app.get('/api/transfers', (req, res) => {
  const records = getAllTransfers();
  res.json({
    success: true,
    count: records.length,
    data: records
  });
});

// POST /api/transfers -> 添加新转账记录
app.post('/api/transfers', (req, res) => {
  const { hash, blockNumber, from, to, value, tokenSymbol } = req.body;

  if (!hash || !from || !to || !value) {
    return res.status(400).json({ error: '缺少必需参数 (hash, from, to, value)' });
  }

  const success = insertTransfer({
    hash,
    blockNumber: blockNumber || 19500000,
    from,
    to,
    value,
    tokenSymbol: tokenSymbol || 'MTK',
    timestamp: Math.floor(Date.now() / 1000)
  });

  res.json({
    success,
    message: success ? '转账记录已成功入库' : '交易哈希已存在，跳过插入'
  });
});

// POST /api/sync -> 手动触发链上同步
app.post('/api/sync', async (req, res) => {
  const { tokenAddress } = req.body;
  const addedCount = await syncChainEvents(tokenAddress || TARGET_TOKEN_ADDRESS);
  res.json({
    success: true,
    addedCount,
    message: `同步完成，新增 ${addedCount} 条记录`
  });
});

// GET /api/stats -> 节点与索引状态
app.get('/api/stats', (req, res) => {
  const all = getAllTransfers();
  res.json({
    status: 'online',
    totalRecords: all.length,
    targetToken: TARGET_TOKEN_ADDRESS,
    service: 'Viem ERC20 Transfer Live Indexer Service',
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, () => {
  console.log(`==================================================`);
  console.log(`🚀 Viem 链上事件实时索引服务已成功启动！`);
  console.log(`🔗 REST API 访问地址: http://localhost:${PORT}`);
  console.log(`📌 目标代币合约: ${TARGET_TOKEN_ADDRESS}`);
  console.log(`📌 查询接口: GET http://localhost:${PORT}/api/transfers/:address`);
  console.log(`==================================================`);
});
