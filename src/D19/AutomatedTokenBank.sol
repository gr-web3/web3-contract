// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title AutomationCompatibleInterface (Chainlink Automation 标准接口)
 */
interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}

/**
 * @title AutomatedTokenBank
 * @notice 支持 ERC20 授权存款与 Chainlink Automation / Gelato 自动化工作流的银行合约
 */
contract AutomatedTokenBank is Ownable, ReentrancyGuard, AutomationCompatibleInterface {
    // 基础事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    // 自动化工作流触发事件
    event AutomationExecuted(address indexed recipient, uint256 transferredAmount, uint256 remainingBalance);
    event ThresholdUpdated(uint256 newThreshold);
    event RecipientUpdated(address newRecipient);

    IERC20 public immutable token;

    // 用户存款账本
    mapping(address => uint256) public tokenNum;

    // 自动化触发阈值 x (以代币最小单位计)
    uint256 public thresholdX;

    // 自动划转的目标接收地址 (如 Owner)
    address public recipient;

    constructor(address _tokenAddress, uint256 _thresholdX, address _recipient) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_recipient != address(0), "Invalid recipient address");
        require(_thresholdX > 0, "Threshold must be > 0");

        token = IERC20(_tokenAddress);
        thresholdX = _thresholdX;
        recipient = _recipient;
    }

    /**
     * @notice ERC20 授权存款 (转账前需先进行 token.approve 授权)
     * @param amount 存入的代币数量
     */
    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Deposit amount must be > 0");

        // 从用户账户划转代币到本合约 (需先 approve)
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transferFrom failed");

        // 记入用户存款账本
        tokenNum[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice 用户提取各自存入的代币
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Withdraw amount must be > 0");
        require(tokenNum[msg.sender] >= amount, "Insufficient deposit balance");

        // 遵循 CEI 范式，先扣减账本
        tokenNum[msg.sender] -= amount;

        bool success = token.transfer(msg.sender, amount);
        require(success, "Token transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    // =========================================================================
    //                    Chainlink Automation 离线检测与触发接口
    // =========================================================================

    /**
     * @notice Chainlink Automation 离线节点轮询调用的静态检查函数 (不消耗 Gas)
     * @dev 当合约持有的代币总余额 >= thresholdX 时返回 true
     */
    function checkUpkeep(bytes calldata /* checkData */)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 totalBalance = token.balanceOf(address(this));
        upkeepNeeded = (totalBalance >= thresholdX);
        performData = abi.encode(totalBalance);
    }

    /**
     * @notice Chainlink Automation 节点发起的链上执行函数
     * @dev 自动将银行合约中 50% 的代币划转至指定 recipient 地址
     */
    function performUpkeep(bytes calldata /* performData */) external override nonReentrant {
        uint256 totalBalance = token.balanceOf(address(this));

        // 防御性二次检查，防止不符合条件时误触发
        require(totalBalance >= thresholdX, "Automation condition not met");

        // 计算 50% 的划转金额
        uint256 halfAmount = totalBalance / 2;
        require(halfAmount > 0, "Half amount is zero");

        // 划转 50% 代币至指定接收地址
        bool success = token.transfer(recipient, halfAmount);
        require(success, "Automation transfer failed");

        uint256 remainingBalance = token.balanceOf(address(this));
        emit AutomationExecuted(recipient, halfAmount, remainingBalance);
    }

    // =========================================================================
    //                        Gelato Web3 Functions 兼容接口
    // =========================================================================

    /**
     * @notice Gelato 平台专属离线检查接口
     */
    function checker() external view returns (bool canExec, bytes memory execPayload) {
        uint256 totalBalance = token.balanceOf(address(this));
        canExec = (totalBalance >= thresholdX);
        execPayload = abi.encodeWithSelector(this.performUpkeep.selector, abi.encode(totalBalance));
    }

    // =========================================================================
    //                            管理员配置方法
    // =========================================================================

    function setThresholdX(uint256 _newThreshold) external onlyOwner {
        require(_newThreshold > 0, "Threshold must be > 0");
        thresholdX = _newThreshold;
        emit ThresholdUpdated(_newThreshold);
    }

    function setRecipient(address _newRecipient) external onlyOwner {
        require(_newRecipient != address(0), "Invalid recipient");
        recipient = _newRecipient;
        emit RecipientUpdated(_newRecipient);
    }

    function balanceOf(address user) external view returns (uint256) {
        return tokenNum[user];
    }
}
