// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IPermit2.sol";

/**
 * @title TokenBankPermit2
 * @dev 具备 Uniswap Permit2 签名授权存款功能的 TokenBank 合约（第十二课作业）
 */
contract TokenBankPermit2 {
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event AdminWithdraw(address indexed admin, uint256 amount);

    address public immutable admin;
    IERC20 public immutable token;
    address public immutable permit2;

    mapping(address => uint256) public tokenNum;

    /**
     * @dev 构造函数，设定关联代币与 Permit2 合约地址
     * @param _token 绑定的 ERC20 代币地址
     * @param _permit2 Uniswap Permit2 合约地址 (如 0x000000000022D473030F116dDEE9F6B43aC78BA3)
     */
    constructor(address _token, address _permit2) {
        require(_token != address(0), "TokenBank: token address cannot be zero");
        require(_permit2 != address(0), "TokenBank: permit2 address cannot be zero");
        admin = msg.sender;
        token = IERC20(_token);
        permit2 = _permit2;
    }

    /**
     * @dev 普通存款：需先调用 token.approve(address(this), amount)
     */
    function deposit(uint256 _amount) public {
        require(_amount > 0, "TokenBank: amount must be greater than zero");
        require(token.balanceOf(msg.sender) >= _amount, "TokenBank: insufficient token balance");

        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "TokenBank: transfer failed");

        tokenNum[msg.sender] += _amount;
        emit Deposit(msg.sender, _amount);
    }

    /**
     * @dev 使用 Uniswap Permit2 签名授权存款
     * @param amount 存款代币数量
     * @param nonce 签名随机数/唯一标识
     * @param deadline 签名过期时间戳
     * @param signature 用户 EIP-712 结构化数据签名
     */
    function depositWithPermit2(
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external {
        require(amount > 0, "TokenBank: amount must be greater than zero");

        // 1. 构造 PermitTransferFrom 结构体
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permissions: IPermit2.TokenPermissions({
                token: address(token),
                amount: amount
            }),
            nonce: nonce,
            deadline: deadline
        });

        // 2. 构造 SignatureTransferDetails 结构体
        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
            to: address(this),
            requestedAmount: amount
        });

        // 3. 调用 Permit2 合约拉取代币转入 TokenBank
        IPermit2(permit2).permitTransferFrom(
            permit,
            transferDetails,
            msg.sender,
            signature
        );

        // 4. 更新存款账目并触发事件
        tokenNum[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev 取出 Token
     */
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "TokenBank: withdraw amount must be greater than zero");
        require(tokenNum[msg.sender] >= _amount, "TokenBank: insufficient deposit balance");

        tokenNum[msg.sender] -= _amount;

        bool success = token.transfer(msg.sender, _amount);
        require(success, "TokenBank: transfer failed");

        emit Withdraw(msg.sender, _amount);
    }

    /**
     * @dev 管理员提取所有代币
     */
    function adminWithdrawAll() external {
        require(msg.sender == admin, "TokenBank: only admin can withdraw all tokens");
        uint256 totalBalance = token.balanceOf(address(this));
        require(totalBalance > 0, "TokenBank: no tokens to withdraw");

        bool success = token.transfer(admin, totalBalance);
        require(success, "TokenBank: admin transfer failed");

        emit AdminWithdraw(admin, totalBalance);
    }

    /**
     * @dev 查询用户存款余额
     */
    function balanceOf(address _user) external view returns (uint256) {
        return tokenNum[_user];
    }
}
