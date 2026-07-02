// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/D5/ERC20WithCallback.sol";

contract DeployERC20WithCallback is Script {
    function run() external {
        // 读取环境变量中的私钥，如果不存在则使用 Anvil 的本地默认第一个私钥
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        );
        vm.startBroadcast(deployerPrivateKey);
        // 部署代币合约，初始发行 100万 枚
        ERC20WithCallback token = new ERC20WithCallback("MyCallbackToken", "YPB", 1000000);
        vm.stopBroadcast();
    }
}