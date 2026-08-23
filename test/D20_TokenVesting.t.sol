// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TokenVesting} from "../src/D20/TokenVesting.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockVestingToken is ERC20 {
    constructor() ERC20("Vesting Test Token", "VTT") {
        _mint(msg.sender, 10_000_000 * 10 ** 18);
    }
}

contract D20_TokenVestingTest is Test {
    TokenVesting public vesting;
    MockVestingToken public token;

    address public owner = makeAddr("owner");
    address public beneficiary = makeAddr("beneficiary");

    uint256 public constant TOTAL_ALLOCATION = 1_000_000 * 10 ** 18; // 100 万代币
    uint256 public startTimestamp;

    function setUp() public {
        startTimestamp = 1_700_000_000; // 设置固定基准时间戳
        vm.warp(startTimestamp);

        vm.startPrank(owner);
        token = new MockVestingToken();

        // 部署 Vesting 合约
        vesting = new TokenVesting(address(token), beneficiary, startTimestamp);

        // 转入 100 万代币资产到 Vesting 合约中
        token.transfer(address(vesting), TOTAL_ALLOCATION);
        vm.stopPrank();
    }

    function test_InitialState() public view {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.beneficiary(), beneficiary);
        assertEq(vesting.startTimestamp(), startTimestamp);
        assertEq(token.balanceOf(address(vesting)), TOTAL_ALLOCATION);
        assertEq(vesting.released(), 0);
    }

    function test_CliffPeriod_6Months_ReturnsZero() public {
        // 模拟时间移至第 6 个月 (悬崖期内)
        vm.warp(startTimestamp + 180 days);

        assertEq(vesting.vestedAmount(block.timestamp), 0);
        assertEq(vesting.releasable(), 0);

        // 试图提取代币，预期回滚
        vm.expectRevert("TokenVesting: no tokens are due for release");
        vesting.release();
    }

    function test_CliffEnd_Month12_ReturnsZero() public {
        // 模拟时间恰好到达第 12 个月结束时刻 (360 天)
        vm.warp(startTimestamp + 360 days);

        assertEq(vesting.vestedAmount(block.timestamp), 0);
        assertEq(vesting.releasable(), 0);
    }

    function test_Month13_UnlocksOneTwentyFourth() public {
        // 模拟时间到达第 13 个月 (悬崖期 360 天 + 线性 30 天 = 390 天)
        vm.warp(startTimestamp + 390 days);

        uint256 expectedVested = (TOTAL_ALLOCATION * 1) / 24; // 1/24 解锁量
        assertEq(vesting.vestedAmount(block.timestamp), expectedVested);
        assertEq(vesting.releasable(), expectedVested);

        // 释放代币给受益人
        vesting.release();

        assertEq(token.balanceOf(beneficiary), expectedVested);
        assertEq(vesting.released(), expectedVested);
        assertEq(vesting.releasable(), 0);
    }

    function test_Month24_UnlocksFiftyPercent() public {
        // 模拟时间到达第 24 个月 (悬崖 12 个月 + 线性 12 个月 = 24 个月 = 720 天)
        vm.warp(startTimestamp + 720 days);

        uint256 expectedVested = TOTAL_ALLOCATION / 2; // 50% (50 万代币)
        assertEq(vesting.vestedAmount(block.timestamp), expectedVested);

        vesting.release();

        assertEq(token.balanceOf(beneficiary), expectedVested);
        assertEq(vesting.released(), expectedVested);
    }

    function test_Month36_UnlocksOneHundredPercent() public {
        // 模拟时间到达第 36 个月 (1080 天) 全额解锁
        vm.warp(startTimestamp + 1080 days);

        assertEq(vesting.vestedAmount(block.timestamp), TOTAL_ALLOCATION);
        assertEq(vesting.releasable(), TOTAL_ALLOCATION);

        vesting.release();

        assertEq(token.balanceOf(beneficiary), TOTAL_ALLOCATION);
        assertEq(token.balanceOf(address(vesting)), 0);
        assertEq(vesting.released(), TOTAL_ALLOCATION);
    }

    function test_MultiplePartialReleases() public {
        // 1. 第 13 个月提取 1/24
        vm.warp(startTimestamp + 390 days);
        vesting.release();
        uint256 release1 = token.balanceOf(beneficiary);
        assertEq(release1, (TOTAL_ALLOCATION * 1) / 24);

        // 2. 第 25 个月再提取
        vm.warp(startTimestamp + 750 days);
        vesting.release();
        uint256 release2 = token.balanceOf(beneficiary);
        assertEq(release2, (TOTAL_ALLOCATION * 13) / 24);

        // 3. 第 36 个月提取剩余全部
        vm.warp(startTimestamp + 1080 days);
        vesting.release();
        assertEq(token.balanceOf(beneficiary), TOTAL_ALLOCATION);
        assertEq(vesting.releasable(), 0);
    }
}
