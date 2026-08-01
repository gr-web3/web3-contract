const BACKEND_API_BASE = 'http://localhost:3001/api';

let currentAccount = null;

// DOM 元素
const connectBtn = document.getElementById('connectBtn');
const addressInput = document.getElementById('addressInput');
const searchBtn = document.getElementById('searchBtn');
const totalCountEl = document.getElementById('totalCount');
const inCountEl = document.getElementById('inCount');
const outCountEl = document.getElementById('outCount');
const tableBody = document.getElementById('transferTableBody');

// 工具函数：缩短地址格式
function formatAddress(addr) {
  if (!addr) return '';
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

// 1. 连接钱包
async function connectWallet() {
  if (typeof window.ethereum === 'undefined') {
    alert('请先安装 MetaMask 或 Web3 钱包扩展！');
    return;
  }

  try {
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    currentAccount = accounts[0];
    connectBtn.textContent = formatAddress(currentAccount);
    addressInput.value = currentAccount;

    console.log(`钱包已连接: ${currentAccount}`);
    await fetchTransfers(currentAccount);
  } catch (err) {
    console.error('连接失败:', err);
  }
}

// 2. 从后端 REST API 获取转账履历数据
async function fetchTransfers(address) {
  if (!address) return;
  const targetAddress = address.trim();

  tableBody.innerHTML = `<tr><td colspan="6" class="empty-state">正在从后端 API 加载数据...</td></tr>`;

  try {
    const res = await fetch(`${BACKEND_API_BASE}/transfers/${targetAddress}`);
    const result = await res.json();

    if (!result.success || !result.data) {
      tableBody.innerHTML = `<tr><td colspan="6" class="empty-state">未查询到相关转账记录</td></tr>`;
      totalCountEl.textContent = '0';
      inCountEl.textContent = '0';
      outCountEl.textContent = '0';
      return;
    }

    renderTable(result.data, targetAddress.toLowerCase());
  } catch (err) {
    console.error('获取转账记录失败:', err);
    tableBody.innerHTML = `
      <tr>
        <td colspan="6" class="empty-state" style="color: var(--danger-color);">
          后端 API 连接失败！请确保 node server.js 已在端口 3001 启动。
        </td>
      </tr>
    `;
  }
}

// 3. 渲染数据表格
function renderTable(transfers, userAddress) {
  if (transfers.length === 0) {
    tableBody.innerHTML = `<tr><td colspan="6" class="empty-state">该地址暂无转账历史记录</td></tr>`;
    totalCountEl.textContent = '0';
    inCountEl.textContent = '0';
    outCountEl.textContent = '0';
    return;
  }

  let inCount = 0;
  let outCount = 0;

  totalCountEl.textContent = transfers.length;

  const rowsHtml = transfers.map(tx => {
    const isReceive = tx.to.toLowerCase() === userAddress;
    if (isReceive) inCount++;
    else outCount++;

    const badgeClass = isReceive ? 'in' : 'out';
    const badgeText = isReceive ? '🟢 收到 (IN)' : '🔴 转出 (OUT)';

    return `
      <tr>
        <td><span class="tx-badge ${badgeClass}">${badgeText}</span></td>
        <td><span class="addr-link" title="${tx.from}">${formatAddress(tx.from)}</span></td>
        <td><span class="addr-link" title="${tx.to}">${formatAddress(tx.to)}</span></td>
        <td style="font-weight: 600; color: ${isReceive ? 'var(--success-color)' : 'var(--danger-color)'}">
          ${isReceive ? '+' : '-'}${tx.formattedValue} ${tx.tokenSymbol || 'MTK'}
        </td>
        <td>#${tx.blockNumber}</td>
        <td><span class="addr-link" title="${tx.hash}">${formatAddress(tx.hash)}</span></td>
      </tr>
    `;
  }).join('');

  inCountEl.textContent = inCount;
  outCountEl.textContent = outCount;
  tableBody.innerHTML = rowsHtml;
}

// 事件绑定
connectBtn.addEventListener('click', connectWallet);
searchBtn.addEventListener('click', () => {
  fetchTransfers(addressInput.value);
});

// 页面首次载入时默认查询初始测试地址
fetchTransfers(addressInput.value);
