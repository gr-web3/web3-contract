import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DB_PATH = path.join(__dirname, 'transfers_db.json');

// 初始化数据库文件
function initDB() {
  if (!fs.existsSync(DB_PATH)) {
    fs.writeFileSync(DB_PATH, JSON.stringify([], null, 2), 'utf-8');
  }
}

// 读取所有记录
export function getAllTransfers() {
  initDB();
  try {
    const data = fs.readFileSync(DB_PATH, 'utf-8');
    return JSON.parse(data || '[]');
  } catch (err) {
    console.error('读取数据库失败:', err);
    return [];
  }
}

// 保存所有记录
function saveAllTransfers(transfers) {
  fs.writeFileSync(DB_PATH, JSON.stringify(transfers, null, 2), 'utf-8');
}

// 插入单条转账记录（去重）
export function insertTransfer(record) {
  const transfers = getAllTransfers();
  const exists = transfers.some(t => t.hash.toLowerCase() === record.hash.toLowerCase());
  if (!exists) {
    transfers.push({
      id: transfers.length + 1,
      hash: record.hash.toLowerCase(),
      blockNumber: record.blockNumber,
      from: record.from.toLowerCase(),
      to: record.to.toLowerCase(),
      value: record.value,
      formattedValue: record.formattedValue || (parseFloat(record.value) / 1e18).toFixed(2),
      tokenSymbol: record.tokenSymbol || 'MTK',
      timestamp: record.timestamp || Math.floor(Date.now() / 1000)
    });
    saveAllTransfers(transfers);
    return true;
  }
  return false;
}

// 批量插入转账记录
export function insertBatchTransfers(records) {
  let count = 0;
  records.forEach(r => {
    if (insertTransfer(r)) count++;
  });
  return count;
}

// 根据地址检索转账记录（包含转出与转入）
export function getTransfersByAddress(address) {
  if (!address) return [];
  const normalizedAddr = address.toLowerCase();
  const transfers = getAllTransfers();
  
  return transfers
    .filter(t => t.from === normalizedAddr || t.to === normalizedAddr)
    .sort((a, b) => b.timestamp - a.timestamp); // 按时间倒序
}
