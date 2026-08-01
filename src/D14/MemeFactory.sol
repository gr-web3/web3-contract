// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./MemeToken.sol";

/**
 * @title MemeFactory
 * @dev Meme 铭文铸造工厂合约（第十四课作业）
 * 使用 EIP-1167 最小代理 (Minimal Proxy) 快速部署与铸造 Meme 铭文代币
 */
contract MemeFactory {
    // 逻辑实现合约模板地址
    address public immutable tokenImplementation;

    // 所有已部署的铭文代理合约数组
    address[] public allInscriptions;
    
    // 校验某地址是否为本工厂部署的铭文代币
    mapping(address => bool) public isInscription;

    // 事件定义
    event InscriptionDeployed(
        address indexed tokenAddr,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        address indexed creator
    );
    
    event InscriptionMinted(
        address indexed tokenAddr,
        address indexed minter,
        uint256 amount
    );

    /**
     * @dev 构造函数：预先部署单例的逻辑实现合约模板
     */
    constructor() {
        tokenImplementation = address(new MemeToken());
    }

    /**
     * @dev 方法 1：部署一个全新的 Meme 铭文代币（使用 EIP-1167 最小代理）
     * @param symbol 代币符号 (如 "DOGE")
     * @param totalSupply 总发行上限
     * @param perMint 单次铸造额度
     * @return tokenAddr 克隆部署出的代理合约地址
     */
    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint
    ) external returns (address tokenAddr) {
        // 1. 使用 Clones 极低 Gas 部署 45 字节的 Minimal Proxy 代理合约
        tokenAddr = Clones.clone(tokenImplementation);

        // 2. 调用代理合约的 initialize 方法设定铭文参数
        MemeToken(tokenAddr).initialize(
            symbol,
            totalSupply,
            perMint,
            address(this)
        );

        // 3. 记录已部署合约状态
        allInscriptions.push(tokenAddr);
        isInscription[tokenAddr] = true;

        // 4. 触发部署事件
        emit InscriptionDeployed(
            tokenAddr,
            symbol,
            totalSupply,
            perMint,
            msg.sender
        );
    }

    /**
     * @dev 方法 2：铸造指定 Meme 铭文代币
     * @param tokenAddr 要铸造的铭文代币代理合约地址
     */
    function mintInscription(address tokenAddr) external {
        require(isInscription[tokenAddr], "MemeFactory: invalid inscription token");

        // 调用对应铭文代币代理合约的 mint 方法给调用者铸造代币
        bool success = MemeToken(tokenAddr).mint(msg.sender);
        require(success, "MemeFactory: mint failed");

        emit InscriptionMinted(
            tokenAddr,
            msg.sender,
            MemeToken(tokenAddr).perMint()
        );
    }

    /**
     * @dev 获取所有已部署的铭文代币数量
     */
    function getInscriptionCount() external view returns (uint256) {
        return allInscriptions.length;
    }

    /**
     * @dev 获取所有已部署的铭文代币地址列表
     */
    function getAllInscriptions() external view returns (address[] memory) {
        return allInscriptions;
    }
}
