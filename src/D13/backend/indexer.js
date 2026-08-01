import { createPublicClient, http, parseAbiItem, formatUnits } from 'viem';
import { sepolia } from 'viem/chains';
import { insertBatchTransfers, insertTransfer, getAllTransfers } from './db.js';

// ERC20 Transfer(address,address,uint256) 事件签名定义
const TRANSFER_EVENT_ABI = parseAbiItem('event Transfer(address indexed from, address indexed to, uint256 value)');

// 默认的目标 ERC20 Token 合约地址（可以在这里换成你自己发行的代币地址）
export const TARGET_TOKEN_ADDRESS = process.env.TOKEN_ADDRESS || '0x776b6fC2eD15D68d538B52E84976796c8Cd2932B'; // 示例/测试 ERC20 地址
export const RPC_URL = process.env.RPC_URL || 'https://ethereum-sepolia-rpc.publicnode.com';

// 建立 Viem 公共客户端与区块链 RPC 建立连接
export const client = createPublicClient({
  chain: sepolia,
  transport: http(RPC_URL)
});

/**
 * 1. 链上历史事件拉取与索引 (getLogs)
 */
export async function syncChainEvents(tokenAddress = TARGET_TOKEN_ADDRESS, fromBlock = 0n) {
  console.log(`[Indexer] 开始向链上 RPC (${RPC_URL}) 拉取 Token [${tokenAddress}] 的 Transfer 事件...`);
  try {
    const logs = await client.getLogs({
      address: tokenAddress,
      event: TRANSFER_EVENT_ABI,
      fromBlock: fromBlock > 0n ? fromBlock : 'earliest',
      toBlock: 'latest'
    });

    console.log(`[Indexer] 链上成功扫描到 ${logs.length} 条 Transfer 日志`);

    const formattedRecords = logs.map(log => ({
      hash: log.transactionHash,
      blockNumber: Number(log.blockNumber),
      from: log.args.from,
      to: log.args.to,
      value: log.args.value.toString(),
      formattedValue: (Number(log.args.value) / 1e18).toFixed(4),
      tokenSymbol: 'MTK',
      timestamp: Math.floor(Date.now() / 1000)
    }));

    const addedCount = insertBatchTransfers(formattedRecords);
    console.log(`[Indexer] 写入数据库成功，新增加载 ${addedCount} 条日志记录`);
    return addedCount;
  } catch (err) {
    console.warn(`[Indexer] 链上日志拉取提示: ${err.message}`);
    return 0;
  }
}

/**
 * 2. 链上实时事件监听器 (watchContractEvent)
 * 只要链上有新转账产生，立即捕获并落库！
 */
export function startLiveIndexer(tokenAddress = TARGET_TOKEN_ADDRESS) {
  console.log(`[Indexer] 🚀 已开启链上实时监听服务 (watchContractEvent)，监听合约: ${tokenAddress}`);
  
  try {
    const unwatch = client.watchContractEvent({
      address: tokenAddress,
      abi: [TRANSFER_EVENT_ABI],
      eventName: 'Transfer',
      onLogs: (logs) => {
        logs.forEach(log => {
          console.log(`[Indexer 🔴 实时捕获新转账!] Tx: ${log.transactionHash}, From: ${log.args.from}, To: ${log.args.to}`);
          insertTransfer({
            hash: log.transactionHash,
            blockNumber: Number(log.blockNumber),
            from: log.args.from,
            to: log.args.to,
            value: log.args.value.toString(),
            formattedValue: (Number(log.args.value) / 1e18).toFixed(4),
            tokenSymbol: 'MTK',
            timestamp: Math.floor(Date.now() / 1000)
          });
        });
      },
      onError: (error) => {
        console.error('[Indexer 实时监听错误]', error.message);
      }
    });

    return unwatch;
  } catch (err) {
    console.warn('[Indexer 实时监听初始化提示]', err.message);
    return null;
  }
}

/**
 * 3. 预置种子模拟数据（保证无网络或本地测试时展示完整）
 */
const SEED_TRANSFERS = [
  {
    hash: '0xa1b2c3d4e5f678901234567890abcdef1234567890abcdef1234567890abcdef',
    blockNumber: 19500100,
    from: '0x0000000000000000000000000000000000000000',
    to: '0x1111111111111111111111111111111111111111',
    value: '1000000000000000000000',
    formattedValue: '1000.00',
    tokenSymbol: 'MTK',
    timestamp: Math.floor(Date.now() / 1000) - 86400 * 3
  },
  {
    hash: '0xb2c3d4e5f678901234567890abcdef1234567890abcdef1234567890abcdef01',
    blockNumber: 19500250,
    from: '0x1111111111111111111111111111111111111111',
    to: '0x2222222222222222222222222222222222222222',
    value: '250000000000000000000',
    formattedValue: '250.00',
    tokenSymbol: 'MTK',
    timestamp: Math.floor(Date.now() / 1000) - 86400 * 2
  }
];

export function seedInitialData() {
  const existing = getAllTransfers();
  if (existing.length === 0) {
    insertBatchTransfers(SEED_TRANSFERS);
  }
}
