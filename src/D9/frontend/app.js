// ==========================================
// 合约地址配置 (请在部署完成后将真实地址填写在此处)
// ==========================================
const CONFIG = {
    TOKEN_ADDRESS: "0x1759EF7ABa13E434D0cAF1f3B0Ca5aF4E6caF76A", // 部署后的 MyERC20 Token 地址
    BANK_ADDRESS: "0xf5ecFF3EaE9ec4b93043ee826407EcDC04313477"  // 部署后的 TokenBank 地址
};

// ==========================================
// 合约极简 ABI 定义
// ==========================================
const ERC20_ABI = [
    "function balanceOf(address owner) view returns (uint256)",
    "function allowance(address owner, address spender) view returns (uint256)",
    "function approve(address spender, uint256 value) returns (bool)",
    "function decimals() view returns (uint8)"
];

const BANK_ABI = [
    "function balanceOf(address user) view returns (uint256)",
    "function deposit(uint256 amount) public",
    "function withdraw(uint256 amount) external"
];

// ==========================================
// 全局状态变量
// ==========================================
let provider;
let signer;
let userAddress;
let tokenContract;
let bankContract;

// DOM 元素引用
const connectBtn = document.getElementById("connectBtn");
const walletBanner = document.getElementById("walletBanner");
const walletBalanceEl = document.getElementById("walletBalance");
const bankBalanceEl = document.getElementById("bankBalance");
const depositInput = document.getElementById("depositAmount");
const withdrawInput = document.getElementById("withdrawAmount");
const approveBtn = document.getElementById("approveBtn");
const depositBtn = document.getElementById("depositBtn");
const withdrawBtn = document.getElementById("withdrawBtn");
const tokenAddrText = document.getElementById("tokenAddressText");
const bankAddrText = document.getElementById("bankAddressText");

// 初始化页面合约文本展示
tokenAddrText.textContent = CONFIG.TOKEN_ADDRESS;
bankAddrText.textContent = CONFIG.BANK_ADDRESS;

// 连接钱包逻辑
async function connectWallet() {
    if (!window.ethereum) {
        alert("未检测到 MetaMask 钱包，请先安装！");
        return;
    }

    try {
        // 请求连接钱包账户
        const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
        userAddress = accounts[0];

        // 初始化 ethers 实例 (ethers v6 语法)
        provider = new ethers.BrowserProvider(window.ethereum);
        signer = await provider.getSigner();

        // 打印当前连接的链 ID，方便调试网络问题
        const network = await provider.getNetwork();
        console.log("MetaMask Chain ID:", network.chainId.toString());

        // 实例化合约
        tokenContract = new ethers.Contract(CONFIG.TOKEN_ADDRESS, ERC20_ABI, signer);
        bankContract = new ethers.Contract(CONFIG.BANK_ADDRESS, BANK_ABI, signer);

        // 更新 UI
        connectBtn.textContent = "已连接钱包";
        connectBtn.disabled = true;

        walletBanner.querySelector(".address-text").textContent = `已连接地址: ${userAddress}`;
        walletBanner.classList.remove("hidden");

        // 启用输入框和按钮监听
        depositInput.disabled = false;
        withdrawInput.disabled = false;

        // 加载链上余额
        await refreshBalances();

        // 监听输入金额变化以动态控制 Approve 和 Deposit 按钮状态
        depositInput.addEventListener("input", checkAllowance);

        // 监听钱包账户或网络切换
        window.ethereum.on("accountsChanged", (newAccs) => {
            if (newAccs.length === 0) {
                location.reload();
            } else {
                userAddress = newAccs[0];
                location.reload();
            }
        });

    } catch (error) {
        console.error("连接钱包失败:", error);
        alert("连接钱包失败: " + error.message);
    }
}

// 刷新用户的所有代币与存入余额
async function refreshBalances() {
    if (!userAddress || !tokenContract || !bankContract) return;

    try {
        // 读取钱包 ERC20 余额
        const walletBalRaw = await tokenContract.balanceOf(userAddress);
        const walletDecimals = await tokenContract.decimals();
        const walletBal = ethers.formatUnits(walletBalRaw, walletDecimals);
        walletBalanceEl.textContent = parseFloat(walletBal).toFixed(4);

        // 读取 TokenBank 中的存款余额
        const bankBalRaw = await bankContract.balanceOf(userAddress);
        const bankBal = ethers.formatUnits(bankBalRaw, walletDecimals);
        bankBalanceEl.textContent = parseFloat(bankBal).toFixed(4);

        // 控制 Withdraw 按钮状态
        if (parseFloat(bankBal) > 0) {
            withdrawBtn.disabled = false;
        } else {
            withdrawBtn.disabled = true;
        }

        // 刷新一次授权额度校验
        await checkAllowance();

    } catch (error) {
        console.error("刷新余额出错:", error);
    }
}

// 校验授权额度，动态显示 Approve 或 Deposit 按钮
async function checkAllowance() {
    const amountVal = depositInput.value;
    if (!amountVal || parseFloat(amountVal) <= 0) {
        approveBtn.disabled = true;
        depositBtn.disabled = true;
        return;
    }

    try {
        const amountWei = ethers.parseEther(amountVal);
        const allowance = await tokenContract.allowance(userAddress, CONFIG.BANK_ADDRESS);

        if (allowance >= amountWei) {
            // 已授权，可以直接存款
            approveBtn.disabled = true;
            depositBtn.disabled = false;
        } else {
            // 授权额度不足，需要先授权
            approveBtn.disabled = false;
            depositBtn.disabled = true;
        }
    } catch (error) {
        console.error("校验 allowance 失败:", error);
    }
}

// 执行授权操作 (Approve)
async function handleApprove() {
    const amountVal = depositInput.value;
    if (!amountVal || parseFloat(amountVal) <= 0) return;

    approveBtn.disabled = true;
    approveBtn.textContent = "授权中 (Approve)...";

    try {
        const amountWei = ethers.parseEther(amountVal);
        const tx = await tokenContract.approve(CONFIG.BANK_ADDRESS, amountWei);
        console.log("授权交易已发送:", tx.hash);

        // 等待交易打包
        await tx.wait(1);
        alert("授权代币成功！现在可以点击第二步执行存款了。");

        // 重新刷新额度检查
        await checkAllowance();
    } catch (error) {
        console.error("授权失败:", error);
        alert("授权失败: " + error.message);
    } finally {
        approveBtn.textContent = "1. 授权代币 (Approve)";
    }
}

// 执行存款操作 (Deposit)
async function handleDeposit() {
    const amountVal = depositInput.value;
    if (!amountVal || parseFloat(amountVal) <= 0) return;

    depositBtn.disabled = true;
    depositBtn.textContent = "存入中 (Deposit)...";

    try {
        const amountWei = ethers.parseEther(amountVal);
        const tx = await bankContract.deposit(amountWei);
        console.log("存款交易已发送:", tx.hash);

        await tx.wait(1);
        alert(`成功向 TokenBank 存入 ${amountVal} ME20！`);

        depositInput.value = "";
        await refreshBalances();
    } catch (error) {
        console.error("存款失败:", error);
        alert("存款失败: " + error.message);
    } finally {
        depositBtn.textContent = "2. 确认存入 (Deposit)";
    }
}

// 执行取款操作 (Withdraw)
async function handleWithdraw() {
    const amountVal = withdrawInput.value;
    if (!amountVal || parseFloat(amountVal) <= 0) {
        alert("请输入有效的取出数量！");
        return;
    }

    withdrawBtn.disabled = true;
    withdrawBtn.textContent = "取款中 (Withdraw)...";

    try {
        const amountWei = ethers.parseEther(amountVal);
        const tx = await bankContract.withdraw(amountWei);
        console.log("取款交易已发送:", tx.hash);

        await tx.wait(1);
        alert(`成功从 TokenBank 取出 ${amountVal} ME20 到钱包！`);

        withdrawInput.value = "";
        await refreshBalances();
    } catch (error) {
        console.error("取款失败:", error);
        alert("取款失败: " + error.message);
    } finally {
        withdrawBtn.textContent = "确认取出 (Withdraw)";
    }
}

// 绑定页面按钮事件监听器
connectBtn.addEventListener("connectWalletClick", connectWallet); // 保持语义化事件绑定或直接 click
connectBtn.onclick = connectWallet;
approveBtn.onclick = handleApprove;
depositBtn.onclick = handleDeposit;
withdrawBtn.onclick = handleWithdraw;
