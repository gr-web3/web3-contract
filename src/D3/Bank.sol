// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Bank {
    // 定义自定义错误，节省 Gas
    error DepositAmountZero();
    error NotAdmin();
    error NoBalanceToWithdraw();
    error TransferFailed();

    // 定义事件，便于前端监听和日志索引
    event Deposited(address indexed user, uint256 amount);
    event TopThreeUpdated(address[3] newTopThree);
    event AdminWithdrawn(address indexed admin, uint256 amount);

    // 记录每个地址的存款金额
    mapping(address => uint256) public deposits;

    uint8 private constant TOP_N = 3;

    // 记录存款金额前3名
    address[TOP_N] public topThreeAddress;

    // 存储谁是admin
    address public admin; 

    constructor() {       
        admin = msg.sender;
    }

    receive() external payable virtual {
        _handleDeposit();
    }

    // 存款函数
    function deposit() external payable virtual {
        _handleDeposit();
    }

    // 转移管理员权限
    function transferAdmin(address newAdmin) external {
        if (admin != msg.sender) revert NotAdmin();
        admin = newAdmin;
    }

    function _handleDeposit() internal virtual {
        // 1. 防御性检查：不允许 0 金额存款
        if (msg.value == 0) revert DepositAmountZero();

        // 更新用户存款金额
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);

        // 更新存款前三名
        _updateTopThree();
    }

    function _updateTopThree() internal {
        address user = msg.sender;
        uint256 userDeposit = deposits[user];

        // 优化：将 storage 数组载入 memory 运算，大幅节省 SLOAD/SSTORE Gas
        address[TOP_N] memory tempTopThree = topThreeAddress;
        bool isUpdated = false;

        // 1. 查找 user 当前在内存排行榜中的位置
        int8 existingIndex = -1;
        for (uint8 i = 0; i < TOP_N; i++) {
            if (tempTopThree[i] == user) {
                existingIndex = int8(i);
                break;
            }
        }

        // 2. 找到 user 应该插入/更新的正确排名位置
        uint8 targetIndex = TOP_N;
        for (uint8 i = 0; i < TOP_N; i++) {
            if (userDeposit > deposits[tempTopThree[i]]) {
                targetIndex = i;
                break;
            }
        }

        // 3. 根据 targetIndex 和 existingIndex 更新内存数组
        if (targetIndex < TOP_N) {
            if (existingIndex != -1) {
                uint8 newIndex = targetIndex;
                uint8 oldIndex = uint8(existingIndex);
                if (newIndex < oldIndex) {
                    for (uint256 j = oldIndex; j > newIndex; j--) {
                        tempTopThree[j] = tempTopThree[j - 1];
                    }
                    tempTopThree[newIndex] = user;
                    isUpdated = true;
                }
            } else {
                for (uint256 j = TOP_N - 1; j > targetIndex; j--) {
                    tempTopThree[j] = tempTopThree[j - 1];
                }
                tempTopThree[targetIndex] = user;
                isUpdated = true;
            }
        }

        // 优化：只有在排名真正发生改变时，才写回 Storage 并释放事件
        if (isUpdated) {
            topThreeAddress = tempTopThree;
            emit TopThreeUpdated(tempTopThree);
        }
    }

    function withdraw() external {
        // 权限校验
        if (admin != msg.sender) revert NotAdmin();

        uint256 balance = address(this).balance;
        if (balance == 0) revert NoBalanceToWithdraw();

        // 释放提现日志
        emit AdminWithdrawn(admin, balance);

        // 发送转账
        (bool success, ) = admin.call{value: balance}("");
        if (!success) revert TransferFailed();
    }
}
