// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ERC20WithCallback.sol";

contract TokenBank is IERC20Receiver {
    // 声明事件，方便前端监听和解决原代码中未声明 Withdraw 事件的编译错误
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event AdminWithdraw(address indexed admin, uint256 amount);

    address public immutable admin;
    IERC20 public immutable token;

    mapping(address => uint) public tokenNum;

    constructor(address tokenAddress){
        require(tokenAddress != address(0), "TokenBank: token address cannot be zero");
        admin = msg.sender;
        token = IERC20(tokenAddress);
    }

    // 存入token
    function deposit(uint _amount) public{
        // 检查存入金额是否大于0
        require(_amount > 0, "TokenBank: amount must be greater than zero");

        // 检查用户是否有足够的代币
        require(token.balanceOf(msg.sender) >= _amount, "TokenBank: insufficient token balance");

        // 将代币从用户转移到合约
        // 注意：用户需要先调用token.approve(tokenBank地址, 金额)来授权TokenBank合约
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "TokenBank: transfer failed");

        // 记录每位用户存入的token量
        tokenNum[msg.sender] += _amount;
        emit Deposit(msg.sender, _amount);
    }  

    // 取出token
    // 提取代币
    function withdraw(uint256 _amount) external {
        // 检查金额是否大于0
        require(_amount > 0, "TokenBank: withdraw amount must be greater than zero");
        
        // 检查用户是否有足够的存款
        require(tokenNum[msg.sender] >= _amount, "TokenBank: insufficient deposit balance");
        
        // 更新用户的存款记录（先减少记录，再转账，防止重入攻击）
        tokenNum[msg.sender] -= _amount;
        
        // 将代币从合约转移回用户
        bool success = token.transfer(msg.sender, _amount);
        require(success, "TokenBank: transfer failed");
        
        // 触发提款事件
        emit Withdraw(msg.sender, _amount);
    }

    // 管理员提取所有的 Token
    function adminWithdrawAll() external {
        // 只有管理员可以提取
        require(msg.sender == admin, "TokenBank: only admin can withdraw all tokens");

        // 获取合约当前的 Token 余额
        uint256 totalBalance = token.balanceOf(address(this));
        require(totalBalance > 0, "TokenBank: no tokens to withdraw");

        // 转账给管理员
        bool success = token.transfer(admin, totalBalance);
        require(success, "TokenBank: admin transfer failed");

        // 触发管理员提款事件
        emit AdminWithdraw(admin, totalBalance);
    }
    
    // 接收转账并回调时的处理逻辑，自动将代币计入用户存款
    function tokensReceived(
        address sender,
        uint256 amount,
        bytes calldata /* data */
    ) external override returns (bool) {
        // 安全检查：只有关联的 Token 合约发起的调用才被接受
        require(msg.sender == address(token), "TokenBank: only accept callbacks from the designated token");
        
        // 记录用户存款余额
        tokenNum[sender] += amount;

        // 触发存款事件
        emit Deposit(sender, amount);

        return true;
    }
    
    // 查询用户在银行中的存款余额
    function balanceOf(address _user) external view returns (uint256) {
        return tokenNum[_user];
    }
}