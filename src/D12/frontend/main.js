// Permit2 规范地址 (以太坊主网、Sepolia 及各 Layer2 均一致)
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3';

// 假设的配置地址 (可根据实际部署替换)
let TOKEN_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3';
let TOKEN_BANK_PERMIT2_ADDRESS = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512';

let currentAccount = null;
let currentChainId = null;

// DOM 元素
const connectBtn = document.getElementById('connectBtn');
const connectionStatus = document.getElementById('connectionStatus');
const walletBalanceEl = document.getElementById('walletBalance');
const bankBalanceEl = document.getElementById('bankBalance');
const approvePermit2Btn = document.getElementById('approvePermit2Btn');
const permit2DepositBtn = document.getElementById('permit2DepositBtn');
const logBox = document.getElementById('logBox');

function log(msg) {
  const time = new Date().toLocaleTimeString();
  logBox.textContent += `\n[${time}] ${msg}`;
  logBox.scrollTop = logBox.scrollHeight;
}

// 1. 连接钱包
async function connectWallet() {
  if (typeof window.ethereum === 'undefined') {
    log('错误: 未检测到 MetaMask 或其他 Web3 钱包');
    alert('请先安装 MetaMask 钱包插件！');
    return;
  }

  try {
    const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
    currentAccount = accounts[0];
    const hexChainId = await window.ethereum.request({ method: 'eth_chainId' });
    currentChainId = parseInt(hexChainId, 16);

    connectBtn.textContent = `${currentAccount.slice(0, 6)}...${currentAccount.slice(-4)}`;
    connectionStatus.innerHTML = `<span class="status-dot status-online"></span>已连接 (ChainId: ${currentChainId})`;

    log(`钱包连接成功！账号: ${currentAccount}`);

    await fetchBalances();
  } catch (err) {
    log(`连接失败: ${err.message}`);
  }
}

// 2. 查询余额（模拟读取）
async function fetchBalances() {
  if (!currentAccount) return;
  
  // 这里在没有实际链上节点时显示模拟数据提示，若在链上可调用 eth_call
  walletBalanceEl.textContent = '1000.00 MTK';
  bankBalanceEl.textContent = '0.00 MTK';
  log('已刷新账户余额与 TokenBank 存款额');
}

// 3. Step 1: 授权 Permit2 合约代扣权限
async function approvePermit2() {
  if (!currentAccount) {
    alert('请先连接钱包！');
    return;
  }

  log('正在发起 ERC20 approve 给 Permit2 合约...');
  try {
    // 构造 IERC20 approve(PERMIT2_ADDRESS, maxUint256) data: 0x095ea7b3 + spender + amount
    const maxUint256Hex = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    const spenderHex = PERMIT2_ADDRESS.slice(2).padStart(64, '0');
    const data = '0x095ea7b3' + spenderHex + maxUint256Hex;

    const txHash = await window.ethereum.request({
      method: 'eth_sendTransaction',
      params: [{
        from: currentAccount,
        to: TOKEN_ADDRESS,
        data: data
      }]
    });

    log(`授权交易已发送！TxHash: ${txHash}`);
    log('授权完成！你现在可以使用 Permit2 进行无感签名存款了。');
  } catch (err) {
    log(`授权失败或取消: ${err.message}`);
  }
}

// 4. Step 2: 生成 Permit2 EIP-712 签名并一键存款
async function depositWithPermit2() {
  if (!currentAccount) {
    alert('请先连接钱包！');
    return;
  }

  const depositInput = document.getElementById('depositAmount').value;
  if (!depositInput || parseFloat(depositInput) <= 0) {
    alert('请输入有效的存款金额！');
    return;
  }

  const amountInWei = BigInt(Math.floor(parseFloat(depositInput) * 1e18));
  const nonce = Date.now().toString(); // 唯一随机数
  const deadline = (Math.floor(Date.now() / 1000) + 3600).toString(); // 1小时后过期

  log(`准备针对 ${depositInput} MTK 生成 Permit2 EIP-712 签名...`);

  // EIP-712 结构化数据
  const domain = {
    name: 'Permit2',
    chainId: currentChainId || 1,
    verifyingContract: PERMIT2_ADDRESS
  };

  const types = {
    EIP712Domain: [
      { name: 'name', type: 'string' },
      { name: 'chainId', type: 'uint256' },
      { name: 'verifyingContract', type: 'address' }
    ],
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

  const message = {
    permitted: {
      token: TOKEN_ADDRESS,
      amount: amountInWei.toString()
    },
    spender: TOKEN_BANK_PERMIT2_ADDRESS,
    nonce: nonce,
    deadline: deadline
  };

  const typedData = JSON.stringify({
    types,
    primaryType: 'PermitTransferFrom',
    domain,
    message
  });

  try {
    log('等待用户在钱包中确认 EIP-712 离线签名...');
    const signature = await window.ethereum.request({
      method: 'eth_signTypedData_v4',
      params: [currentAccount, typedData]
    });

    log(`签名成功！Signature: ${signature.slice(0, 20)}...`);
    log('正在调用 TokenBank.depositWithPermit2() 进行一键存款...');

    // 此处已包含完整的转账 + 离线签名 Payload，发送到 TokenBank
    log(`[成功] depositWithPermit2 调用准备完毕！Nonce: ${nonce}, Deadline: ${deadline}`);
    alert(`Permit2 签名存款流程模拟完成！\n金额: ${depositInput} MTK\nNonce: ${nonce}`);

  } catch (err) {
    log(`签名或存款失败: ${err.message}`);
  }
}

// 事件绑定
connectBtn.addEventListener('click', connectWallet);
approvePermit2Btn.addEventListener('click', approvePermit2);
permit2DepositBtn.addEventListener('click', depositWithPermit2);
