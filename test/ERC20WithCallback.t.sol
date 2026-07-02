// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ERC20WithCallback, IERC20Receiver} from "../src/D5/ERC20WithCallback.sol";

// 模拟实现了 IERC20Receiver 的合约
contract MockTokenReceiver is IERC20Receiver {
    address public lastSender;
    uint256 public lastAmount;
    bytes public lastData;
    bool public shouldReject;

    function setShouldReject(bool _shouldReject) external {
        shouldReject = _shouldReject;
    }

    function tokensReceived(
        address sender,
        uint256 amount,
        bytes calldata data
    ) external override returns (bool) {
        if (shouldReject) {
            return false;
        }
        lastSender = sender;
        lastAmount = amount;
        lastData = data;
        return true;
    }
}

// 模拟没有实现 IERC20Receiver 的普通合约
contract NonReceiverContract {
    // 只是一个普通的合约，没有任何接收 token 的回调
    receive() external payable {}
}

contract ERC20WithCallbackTest is Test {
    ERC20WithCallback public token;
    MockTokenReceiver public receiver;
    NonReceiverContract public nonReceiver;

    address public owner = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        token = new ERC20WithCallback("CallbackToken", "CBT", 1_000_000);
        
        receiver = new MockTokenReceiver();
        nonReceiver = new NonReceiverContract();

        // 给用户分发点代币 (代币归测试合约所有，直接转账给用户)
        token.transfer(user, 1000 * 10 ** token.decimals());
    }

    function test_TransferToEOA_NoCallback() public {
        uint256 amount = 100 * 10 ** token.decimals();
        address eoa = address(0x3);

        vm.prank(user);
        bool success = token.transfer(eoa, amount);
        assertTrue(success);
        assertEq(token.balanceOf(eoa), amount);
    }

    function test_TransferToContract_AutoCallback() public {
        uint256 amount = 100 * 10 ** token.decimals();

        // 往 Mock 接收合约转账，应当自动触发回调并记录参数
        vm.prank(user);
        bool success = token.transfer(address(receiver), amount);
        assertTrue(success);

        assertEq(token.balanceOf(address(receiver)), amount);
        assertEq(receiver.lastSender(), user);
        assertEq(receiver.lastAmount(), amount);
    }

    function test_TransferAndCall() public {
        uint256 amount = 100 * 10 ** token.decimals();
        bytes memory customData = abi.encodePacked("Custom Action");

        // 测试 transferAndCall 显式传递参数
        vm.prank(user);
        bool success = token.transferAndCall(address(receiver), amount, customData);
        assertTrue(success);

        assertEq(receiver.lastSender(), user);
        assertEq(receiver.lastAmount(), amount);
        assertEq(receiver.lastData(), customData);
    }

    function test_TransferToContract_Reject_Reverts() public {
        uint256 amount = 100 * 10 ** token.decimals();
        receiver.setShouldReject(true);

        // 如果回调返回 false，转账应该被拒绝并 revert
        vm.prank(user);
        vm.expectRevert("ERC20: receiver rejected tokens");
        token.transfer(address(receiver), amount);
    }

    function test_TransferToNonReceiverContract_Reverts() public {
        uint256 amount = 100 * 10 ** token.decimals();

        // 如果合约没有实现回调接口，转账应该 revert
        vm.prank(user);
        vm.expectRevert("ERC20: receiver contract failed to handle tokensReceived");
        token.transfer(address(nonReceiver), amount);
    }
}
