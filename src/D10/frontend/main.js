import { createAppKit } from '@reown/appkit';
import { sepolia } from '@reown/appkit/networks';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { getAccount, getPublicClient, getWalletClient, watchAccount } from '@wagmi/core';
import { parseUnits, formatUnits, encodeAbiParameters } from 'viem';

// 1. 合约配置信息 (Sepolia 链上地址)
const CONFIG = {
    PROJECT_ID: '239c6c816ae3b4ee5cb6932c218805dc', // Reown Cloud Project ID
    TOKEN_ADDRESS: '0x1759EF7ABa13E434D0cAF1f3B0Ca5aF4E6caF76A', // MyERC20 Token 地址
    YPNFT_ADDRESS: '0xf07d362d123ec786219930fB3dC8f53e47e80407', // YPNFT 智能合约地址
    MARKET_ADDRESS: '0xd7623DF10Fd0AaEC71f242eBB6Fe2F1E3C25a40F' // NFTMarket 智能合约地址
};

// 2. 极简 ABI 定义 (用于 Viem 交互)
const YPNFT_ABI = [
    { name: "ownerOf", type: "function", stateMutability: "view", inputs: [{ name: "tokenId", type: "uint256" }], outputs: [{ type: "address" }] },
    { name: "getApproved", type: "function", stateMutability: "view", inputs: [{ name: "tokenId", type: "uint256" }], outputs: [{ type: "address" }] },
    { name: "isApprovedForAll", type: "function", stateMutability: "view", inputs: [{ name: "owner", type: "address" }, { name: "operator", type: "address" }], outputs: [{ type: "bool" }] },
    { name: "approve", type: "function", stateMutability: "nonpayable", inputs: [{ name: "to", type: "address" }, { name: "tokenId", type: "uint256" }], outputs: [] },
    { name: "mint", type: "function", stateMutability: "nonpayable", inputs: [{ name: "to", type: "address" }, { name: "tokenURI", type: "string" }], outputs: [{ type: "uint256" }] },
    { name: "tokenURI", type: "function", stateMutability: "view", inputs: [{ name: "tokenId", type: "uint256" }], outputs: [{ type: "string" }] }
];

const TOKEN_ABI = [
    { name: "balanceOf", type: "function", stateMutability: "view", inputs: [{ name: "owner", type: "address" }], outputs: [{ type: "uint256" }] },
    { name: "allowance", type: "function", stateMutability: "view", inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }], outputs: [{ type: "uint256" }] },
    { name: "approve", type: "function", stateMutability: "nonpayable", inputs: [{ name: "spender", type: "address" }, { name: "value", type: "uint256" }], outputs: [{ type: "bool" }] },
    { name: "transferAndCall", type: "function", stateMutability: "nonpayable", inputs: [{ name: "to", type: "address" }, { name: "value", type: "uint256" }, { name: "data", type: "bytes" }], outputs: [{ type: "bool" }] }
];

const MARKET_ABI = [
    { name: "listings", type: "function", stateMutability: "view", inputs: [{ name: "", type: "uint256" }], outputs: [{ name: "seller", type: "address" }, { name: "price", type: "uint256" }] },
    { name: "list", type: "function", stateMutability: "nonpayable", inputs: [{ name: "tokenId", type: "uint256" }, { name: "price", type: "uint256" }], outputs: [] },
    { name: "buyNFT", type: "function", stateMutability: "nonpayable", inputs: [{ name: "tokenId", type: "uint256" }, { name: "amount", type: "uint256" }], outputs: [] }
];

// 3. 初始化 AppKit (通过 WagmiAdapter 以原生集成 Viem)
const networks = [sepolia];
const wagmiAdapter = new WagmiAdapter({
    networks,
    projectId: CONFIG.PROJECT_ID
});

// 帮助函数：将 ipfs:// 协议转换为 HTTP 浏览器网关 URL
function ipfsToGateway(ipfsUrl) {
    if (!ipfsUrl) return '';
    if (ipfsUrl.startsWith('ipfs://')) {
        return ipfsUrl.replace('ipfs://', 'https://ipfs.io/ipfs/');
    }
    return ipfsUrl;
}

const modal = createAppKit({
    adapters: [wagmiAdapter],
    networks,
    projectId: CONFIG.PROJECT_ID,
    metadata: {
        name: 'YPNFT Market',
        description: 'Viem + AppKit Powered NFT Market',
        url: window.location.origin,
        icons: []
    }
});

// 4. 获取 DOM 元素
const tokenBalanceEl = document.getElementById('tokenBalance');
const tokenAllowanceEl = document.getElementById('tokenAllowance');
const approveAmountInput = document.getElementById('approveAmount');
const approveTokenBtn = document.getElementById('approveTokenBtn');

const listTokenIdInput = document.getElementById('listTokenId');
const listPriceInput = document.getElementById('listPrice');
const approveNftBtn = document.getElementById('approveNftBtn');
const listNftBtn = document.getElementById('listNftBtn');

const mintTokenUriInput = document.getElementById('mintTokenUri');
const mintNftBtn = document.getElementById('mintNftBtn');

const listingsGrid = document.getElementById('listingsGrid');

// 5. 定义核心状态变量
let userAddress = null;
let isConnected = false;
let publicClient = null;

// 6. 核心链上信息加载逻辑
async function refreshState() {
    if (!isConnected || !userAddress || !publicClient) return;

    try {
        // 读取 ERC20 代币余额
        const balance = await publicClient.readContract({
            address: CONFIG.TOKEN_ADDRESS,
            abi: TOKEN_ABI,
            functionName: 'balanceOf',
            args: [userAddress]
        });
        tokenBalanceEl.textContent = parseFloat(formatUnits(balance, 18)).toFixed(2);

        // 读取授权给市场合约的额度
        const allowance = await publicClient.readContract({
            address: CONFIG.TOKEN_ADDRESS,
            abi: TOKEN_ABI,
            functionName: 'allowance',
            args: [userAddress, CONFIG.MARKET_ADDRESS]
        });
        tokenAllowanceEl.textContent = parseFloat(formatUnits(allowance, 18)).toFixed(2);
        approveTokenBtn.disabled = false;

        // 启用铸造按钮
        mintNftBtn.disabled = false;

        // 刷新上架中的 NFT 列表
        await loadMarketListings();
        
        // 动态验证当前输入框状态
        await checkListValidation();

    } catch (error) {
        console.error('加载链上状态出错:', error);
    }
}

// 7. 动态校验上架表单输入
async function checkListValidation() {
    const tokenIdVal = listTokenIdInput.value;
    const priceVal = listPriceInput.value;

    if (!tokenIdVal || !priceVal || parseFloat(priceVal) <= 0) {
        approveNftBtn.disabled = true;
        listNftBtn.disabled = true;
        return;
    }

    try {
        const tokenId = BigInt(tokenIdVal);
        
        // 验证用户是否确实拥有该 NFT
        const owner = await publicClient.readContract({
            address: CONFIG.YPNFT_ADDRESS,
            abi: YPNFT_ABI,
            functionName: 'ownerOf',
            args: [tokenId]
        });

        if (owner.toLowerCase() !== userAddress.toLowerCase()) {
            approveNftBtn.disabled = true;
            listNftBtn.disabled = true;
            console.warn('警告：你并非该 Token ID 的所有者！');
            return;
        }

        // 验证市场是否获得该 NFT 的授权
        const approvedAddress = await publicClient.readContract({
            address: CONFIG.YPNFT_ADDRESS,
            abi: YPNFT_ABI,
            functionName: 'getApproved',
            args: [tokenId]
        });

        const isApprovedForAll = await publicClient.readContract({
            address: CONFIG.YPNFT_ADDRESS,
            abi: YPNFT_ABI,
            functionName: 'isApprovedForAll',
            args: [userAddress, CONFIG.MARKET_ADDRESS]
        });

        const isApproved = approvedAddress.toLowerCase() === CONFIG.MARKET_ADDRESS.toLowerCase() || isApprovedForAll;

        if (isApproved) {
            approveNftBtn.disabled = true;
            listNftBtn.disabled = false;
        } else {
            approveNftBtn.disabled = false;
            listNftBtn.disabled = true;
        }

    } catch (error) {
        approveNftBtn.disabled = true;
        listNftBtn.disabled = true;
        console.error('上架检查出错 (可能是 NFT 不存在):', error);
    }
}

// 8. 载入市场上的 NFT
async function loadMarketListings() {
    listingsGrid.innerHTML = '<div class="loading-state">正在同步 Sepolia 链上在售列表...</div>';
    
    try {
        const activeListings = [];
        const promises = [];

        // 默认扫描 Token ID 0 ~ 15
        for (let i = 0; i < 16; i++) {
            promises.push(
                publicClient.readContract({
                    address: CONFIG.MARKET_ADDRESS,
                    abi: MARKET_ABI,
                    functionName: 'listings',
                    args: [BigInt(i)]
                }).then(([seller, price]) => {
                    if (seller !== '0x0000000000000000000000000000000000000000') {
                        activeListings.push({
                            tokenId: i,
                            seller,
                            price
                        });
                    }
                }).catch(() => {
                    // 忽略单个查询错误
                })
            );
        }

        await Promise.all(promises);

        listingsGrid.innerHTML = '';
        
        // 并行加载所有在售 NFT 的元数据 JSON 和图片
        const cardPromises = activeListings.map(async item => {
            const formattedPrice = formatUnits(item.price, 18);
            const shortSeller = `${item.seller.substring(0, 6)}...${item.seller.substring(38)}`;

            let imageUrl = '';
            let nftName = `YPNFT #${item.tokenId}`;
            
            try {
                // 1. 读取 tokenURI
                const tokenURI = await publicClient.readContract({
                    address: CONFIG.YPNFT_ADDRESS,
                    abi: YPNFT_ABI,
                    functionName: 'tokenURI',
                    args: [BigInt(item.tokenId)]
                });

                if (tokenURI) {
                    const gatewayUrl = ipfsToGateway(tokenURI);
                    // 默认先将 tokenURI 自身作为图片地址（万一它是个直接的图片链接，或者后面的 fetch 因跨域/超时被阻断）
                    imageUrl = gatewayUrl;
                    
                    try {
                        // 2. 发起网络请求尝试解析为 JSON 元数据
                        const response = await fetch(gatewayUrl);
                        const metadata = await response.json();
                        if (metadata) {
                            if (metadata.image) {
                                imageUrl = ipfsToGateway(metadata.image);
                            }
                            if (metadata.name) {
                                nftName = metadata.name;
                            }
                        }
                    } catch (fetchOrJsonError) {
                        // 无论是跨域报错、网络超时还是 JSON 解析失败，我们都保留使用原始的 gatewayUrl 作为图片渲染
                        console.log(`无法获取 JSON 元数据，将 tokenURI 视为直接图片渲染:`, gatewayUrl);
                    }
                }
            } catch (err) {
                console.warn(`读取 NFT #${item.tokenId} 元数据失败:`, err);
            }

            const card = document.createElement('div');
            card.className = 'nft-card';
            
            // 如果成功解析出图片，渲染 img；否则显示 Emoji 占位
            const imgHtml = imageUrl 
                ? `<img src="${imageUrl}" alt="${nftName}" style="width:100%; height:100%; object-fit:cover;" />`
                : `<div class="nft-img-placeholder">🖼️</div>`;

            card.innerHTML = `
                <div class="nft-img-container">
                    <span class="nft-tag">YPNFT</span>
                    ${imgHtml}
                </div>
                <div class="nft-info">
                    <div class="nft-name">${nftName}</div>
                    <div class="nft-seller" title="${item.seller}">卖家: ${shortSeller}</div>
                </div>
                <div class="nft-price-box">
                    <span class="nft-price-lbl">售价</span>
                    <span class="nft-price-val">${parseFloat(formattedPrice).toFixed(2)} ME20</span>
                </div>
                <div class="nft-actions">
                    <button class="nft-btn nft-btn-buy" data-id="${item.tokenId}" data-price="${item.price}">传统购买 (Approve+Buy)</button>
                    <button class="nft-btn nft-btn-callback" data-id="${item.tokenId}" data-price="${item.price}">极速购买 (transferAndCall)</button>
                </div>
            `;

            // 传统购买事件
            card.querySelector('.nft-btn-buy').addEventListener('click', () => handleBuyNFT(item.tokenId, item.price));
            // 回调一键购买事件
            card.querySelector('.nft-btn-callback').addEventListener('click', () => handleBuyNFTCallback(item.tokenId, item.price));

            return card;
        });

        const cards = await Promise.all(cardPromises);
        cards.forEach(card => listingsGrid.appendChild(card));

    } catch (error) {
        listingsGrid.innerHTML = '<div class="loading-state">❌ 获取市场列表失败</div>';
        console.error(error);
    }
}

// 9. 链上写入操作 (Write Operations)

// 授权 NFT 给市场合约
async function handleApproveNft() {
    const tokenIdVal = listTokenIdInput.value;
    if (!tokenIdVal) return;

    try {
        approveNftBtn.disabled = true;
        approveNftBtn.textContent = '等待签名...';
        
        const walletClient = await getWalletClient(wagmiAdapter.wagmiConfig);
        const hash = await walletClient.writeContract({
            address: CONFIG.YPNFT_ADDRESS,
            abi: YPNFT_ABI,
            functionName: 'approve',
            args: [CONFIG.MARKET_ADDRESS, BigInt(tokenIdVal)],
            account: userAddress
        });

        approveNftBtn.textContent = '打包中...';
        await publicClient.waitForTransactionReceipt({ hash });
        
        alert('NFT 授权成功！');
        await refreshState();
    } catch (error) {
        console.error(error);
        alert(`授权失败: ${error.message || error}`);
    } finally {
        approveNftBtn.textContent = '1. 授权 NFT (Approve)';
        approveNftBtn.disabled = false;
    }
}

// 铸造 NFT
async function handleMintNft() {
    const tokenUriVal = mintTokenUriInput.value;
    if (!tokenUriVal) return;

    try {
        mintNftBtn.disabled = true;
        mintNftBtn.textContent = '等待签名...';

        const walletClient = await getWalletClient(wagmiAdapter.wagmiConfig);
        const hash = await walletClient.writeContract({
            address: CONFIG.YPNFT_ADDRESS,
            abi: YPNFT_ABI,
            functionName: 'mint',
            args: [userAddress, tokenUriVal],
            account: userAddress
        });

        mintNftBtn.textContent = '打包中...';
        const receipt = await publicClient.waitForTransactionReceipt({ hash });

        // 提取 Transfer 事件中的 tokenId
        const transferTopic = '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';
        const log = receipt.logs.find(l => 
            l.topics[0] === transferTopic && 
            l.address.toLowerCase() === CONFIG.YPNFT_ADDRESS.toLowerCase()
        );

        if (log && log.topics[3]) {
            const tokenId = BigInt(log.topics[3]);
            alert(`🎉 NFT 铸造成功！Token ID 为 #${tokenId.toString()}`);
            listTokenIdInput.value = tokenId.toString(); // 自动填入上架 Token ID 输入框，方便上架
        } else {
            alert('NFT 铸造成功，但未能自动解析出 Token ID，请检查交易记录。');
        }

        await refreshState();
    } catch (error) {
        console.error(error);
        alert(`铸造失败: ${error.message || error}`);
    } finally {
        mintNftBtn.textContent = '确认铸造 (Mint NFT)';
        mintNftBtn.disabled = false;
    }
}

// 上架 NFT
async function handleListNft() {
    const tokenIdVal = listTokenIdInput.value;
    const priceVal = listPriceInput.value;
    if (!tokenIdVal || !priceVal) return;

    try {
        listNftBtn.disabled = true;
        listNftBtn.textContent = '等待签名...';

        const walletClient = await getWalletClient(wagmiAdapter.wagmiConfig);
        const hash = await walletClient.writeContract({
            address: CONFIG.MARKET_ADDRESS,
            abi: MARKET_ABI,
            functionName: 'list',
            args: [BigInt(tokenIdVal), parseUnits(priceVal, 18)],
            account: userAddress
        });

        listNftBtn.textContent = '打包中...';
        await publicClient.waitForTransactionReceipt({ hash });

        alert('NFT 上架成功！');
        listTokenIdInput.value = '';
        listPriceInput.value = '';
        await refreshState();
    } catch (error) {
        console.error(error);
        alert(`上架失败: ${error.message || error}`);
    } finally {
        listNftBtn.textContent = '2. 确认上架 (List)';
        listNftBtn.disabled = false;
    }
}

// 授权代币给市场合约
async function handleApproveToken() {
    const amountVal = approveAmountInput.value;
    if (!amountVal) return;

    try {
        approveTokenBtn.disabled = true;
        approveTokenBtn.textContent = '等待签名...';

        const walletClient = await getWalletClient(wagmiAdapter.wagmiConfig);
        const hash = await walletClient.writeContract({
            address: CONFIG.TOKEN_ADDRESS,
            abi: TOKEN_ABI,
            functionName: 'approve',
            args: [CONFIG.MARKET_ADDRESS, parseUnits(amountVal, 18)],
            account: userAddress
        });

        approveTokenBtn.textContent = '打包中...';
        await publicClient.waitForTransactionReceipt({ hash });

        alert('代币授权成功！');
        approveAmountInput.value = '';
        await refreshState();
    } catch (error) {
        console.error(error);
        alert(`授权代币失败: ${error.message || error}`);
    } finally {
        approveTokenBtn.textContent = '确认授权代币 (Approve Token)';
        approveTokenBtn.disabled = false;
    }
}

// 传统方式购买 (BuyNFT)
async function handleBuyNFT(tokenId, price) {
    try {
        // 先检查授权额度是否充足
        const allowance = await publicClient.readContract({
            address: CONFIG.TOKEN_ADDRESS,
            abi: TOKEN_ABI,
            functionName: 'allowance',
            args: [userAddress, CONFIG.MARKET_ADDRESS]
        });

        if (allowance < price) {
            alert('当前授权给市场的 ME20 代币额度不足，请先进行“代币授权操作”！');
            approveAmountInput.value = formatUnits(price, 18);
            approveAmountInput.focus();
            return;
        }

        const walletClient = await getWalletClient(wagmiAdapter.wagmiConfig);
        const hash = await walletClient.writeContract({
            address: CONFIG.MARKET_ADDRESS,
            abi: MARKET_ABI,
            functionName: 'buyNFT',
            args: [BigInt(tokenId), price],
            account: userAddress
        });

        alert('交易已提交！正在等待打包...');
        await publicClient.waitForTransactionReceipt({ hash });
        alert('🎉 购买成功！NFT 已发送至你的钱包。');
        await refreshState();

    } catch (error) {
        console.error(error);
        alert(`交易失败: ${error.message || error}`);
    }
}

// 极速方式购买 (transferAndCall)
async function handleBuyNFTCallback(tokenId, price) {
    try {
        // 编码 tokenId 作为 bytes 参数
        const data = encodeAbiParameters(
            [{ type: 'uint256' }],
            [BigInt(tokenId)]
        );

        const walletClient = await getWalletClient(wagmiAdapter.wagmiConfig);
        const hash = await walletClient.writeContract({
            address: CONFIG.TOKEN_ADDRESS,
            abi: TOKEN_ABI,
            functionName: 'transferAndCall',
            args: [CONFIG.MARKET_ADDRESS, price, data],
            account: userAddress
        });

        alert('transferAndCall 一键购买交易已提交，正在等待打包...');
        await publicClient.waitForTransactionReceipt({ hash });
        alert('🎉 极速购买成功！一键扣款与 NFT 划转已顺利完成。');
        await refreshState();

    } catch (error) {
        console.error(error);
        alert(`极速购买失败: ${error.message || error}`);
    }
}

// 10. 事件注册与状态监听
listTokenIdInput.addEventListener('input', checkListValidation);
listPriceInput.addEventListener('input', checkListValidation);

approveNftBtn.addEventListener('click', handleApproveNft);
listNftBtn.addEventListener('click', handleListNft);
approveTokenBtn.addEventListener('click', handleApproveToken);
mintNftBtn.addEventListener('click', handleMintNft);

// 监听 AppKit 连接账户变化
watchAccount(wagmiAdapter.wagmiConfig, {
    onChange(data) {
        userAddress = data.address;
        isConnected = data.isConnected;
        
        if (isConnected && userAddress) {
            publicClient = getPublicClient(wagmiAdapter.wagmiConfig);
            refreshState();
        } else {
            userAddress = null;
            isConnected = false;
            publicClient = null;
            // 清理 UI 显示
            tokenBalanceEl.textContent = '0.00';
            tokenAllowanceEl.textContent = '0.00';
            approveNftBtn.disabled = true;
            listNftBtn.disabled = true;
            approveTokenBtn.disabled = true;
            mintNftBtn.disabled = true;
            listingsGrid.innerHTML = '<div class="loading-state">请先连接钱包并载入 Sepolia 链上数据...</div>';
        }
    }
});
