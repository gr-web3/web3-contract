// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TokenVesting
 * @notice 支持 12 个月 Cliff (悬崖期) 及接下来 24 个月线性解锁的 ERC20 代币 Vesting 合约
 */
contract TokenVesting is ReentrancyGuard {
    event TokensReleased(address indexed beneficiary, uint256 amount);

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable startTimestamp;

    // 时间常量定义 (以 1 个月 = 30 天计算)
    uint256 public constant MONTH = 30 days;
    uint256 public constant CLIFF_DURATION = 12 * MONTH;       // 12 个月悬崖期 (360 天)
    uint256 public constant VESTING_DURATION = 24 * MONTH;     // 24 个月线性解锁期 (720 天)
    uint256 public constant TOTAL_DURATION = CLIFF_DURATION + VESTING_DURATION; // 36 个月总时长 (1080 天)

    // 已释放给受益人的代币总额
    uint256 public released;

    /**
     * @param _token 锁定的 ERC20 代币地址
     * @param _beneficiary 代币受益人地址
     * @param _startTimestamp 起始计算时间戳 (通常为部署时刻 block.timestamp)
     */
    constructor(address _token, address _beneficiary, uint256 _startTimestamp) {
        require(_token != address(0), "TokenVesting: token is zero address");
        require(_beneficiary != address(0), "TokenVesting: beneficiary is zero address");
        require(_startTimestamp > 0, "TokenVesting: startTimestamp must be > 0");

        token = IERC20(_token);
        beneficiary = _beneficiary;
        startTimestamp = _startTimestamp;
    }

    /**
     * @notice 计算截至指定时间戳已被解禁/解冻的累计代币总额
     * @param timestamp 目标时间戳
     */
    function vestedAmount(uint256 timestamp) public view returns (uint256) {
        // 总资产归集 = 合约当前代币余额 + 已释放代币总额
        uint256 totalAllocation = token.balanceOf(address(this)) + released;

        // 1. 悬崖期内 (前 12 个月)：解锁量为 0
        if (timestamp < startTimestamp + CLIFF_DURATION) {
            return 0;
        }
        // 2. 释放期满后 (36 个月后)：100% 规则完全解锁
        else if (timestamp >= startTimestamp + TOTAL_DURATION) {
            return totalAllocation;
        }
        // 3. 悬崖期后 (第 13 个月至第 36 个月)：在 24 个月时间内线性均匀解锁
        else {
            uint256 timePastCliff = timestamp - (startTimestamp + CLIFF_DURATION);
            return (totalAllocation * timePastCliff) / VESTING_DURATION;
        }
    }

    /**
     * @notice 查询当前时刻可以被释放提取的代币数量
     */
    function releasable() public view returns (uint256) {
        return vestedAmount(block.timestamp) - released;
    }

    /**
     * @notice 释放当前已解锁但尚未提取的代币给受益人
     */
    function release() external nonReentrant {
        uint256 unreleased = releasable();
        require(unreleased > 0, "TokenVesting: no tokens are due for release");

        // 遵循 CEI 范式，先更新累积已释放状态
        released += unreleased;

        // 划转代币给受益人
        bool success = token.transfer(beneficiary, unreleased);
        require(success, "TokenVesting: token transfer failed");

        emit TokensReleased(beneficiary, unreleased);
    }
}
