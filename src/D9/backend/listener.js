import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { createPublicClient, http, formatUnits } from 'viem';
import { sepolia } from 'viem/chains';
import dotenv from 'dotenv';

// 1. 初始化环境变量 (指向项目根目录下的 .env)
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });

const RPC_URL = process.env.RPC_URL;
const NFT_MARKET_ADDRESS = process.env.NFT_MARKET_ADDRESS || "0x9606309B3dD8826cEc36384537Fd4f19c0e5F49b"; // 可通过环境变量配置

if (!RPC_URL) {
    console.error("❌ 错误: 未能在环境变量或 .env 中找到 RPC_URL，请检查配置！");
    process.exit(1);
}

// 2. 加载编译生成的 NFTMarket.json 以动态获取合约 ABI
const artifactPath = path.resolve(__dirname, '../../../out/NFTMarket.sol/NFTMarket.json');
let abi;
try {
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
    abi = artifact.abi;
} catch (error) {
    console.error(`❌ 错误: 无法加载 NFTMarket ABI，请确保运行过 forge build。路径: ${artifactPath}`);
    process.exit(1);
}

// 3. 创建 Viem 公共客户端连接区块链节点
console.log("正在初始化 Viem 监听器...");
console.log(`- 节点地址 (RPC): ${RPC_URL}`);
console.log(`- 市场合约地址:   ${NFT_MARKET_ADDRESS}`);

const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(RPC_URL),
});

// 4. 监听上架事件 (NFTListed)
const unwatchList = publicClient.watchContractEvent({
    address: NFT_MARKET_ADDRESS,
    abi: abi,
    eventName: 'NFTListed',
    poll: true,              // 开启轮询模式，防止公共节点 HTTP Filter 状态超时被清除导致的网络连接重置
    pollingInterval: 4000,   // 每 4 秒轮询一次
    onLogs: (logs) => {
        logs.forEach((log) => {
            const { tokenId, seller, price } = log.args;
            // 假设代币 decimals = 18 格式化显示价格
            const formattedPrice = formatUnits(price, 18);
            console.log("\n================ [🔔 NFT 上架事件] ================");
            console.log(`- Token ID:   #${tokenId.toString()}`);
            console.log(`- 卖家地址:   ${seller}`);
            console.log(`- 上架价格:   ${formattedPrice} Token`);
            console.log("=================================================");
        });
    },
    onError: (error) => {
        console.error("❌ 监听 NFTListed 事件出错:", error);
    }
});

// 5. 监听购买事件 (NFTSold)
const unwatchSold = publicClient.watchContractEvent({
    address: NFT_MARKET_ADDRESS,
    abi: abi,
    eventName: 'NFTSold',
    poll: true,              // 开启轮询模式
    pollingInterval: 4000,   // 每 4 秒轮询一次
    onLogs: (logs) => {
        logs.forEach((log) => {
            const { tokenId, buyer, seller, price } = log.args;
            const formattedPrice = formatUnits(price, 18);
            console.log("\n================ [🎉 NFT 交易成功] ================");
            console.log(`- Token ID:   #${tokenId.toString()}`);
            console.log(`- 买家地址:   ${buyer}`);
            console.log(`- 卖家地址:   ${seller}`);
            console.log(`- 成交价格:   ${formattedPrice} Token`);
            console.log("=================================================");
        });
    },
    onError: (error) => {
        console.error("❌ 监听 NFTSold 事件出错:", error);
    }
});

console.log("\n🚀 后台事件监听已就绪！正在实时监听链上上架与购买记录...");

// 优雅退出处理
process.on('SIGINT', () => {
    console.log("\n正在关闭监听服务...");
    unwatchList();
    unwatchSold();
    process.exit(0);
});
