// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MyERC20} from "../src/D6/MyERC20.sol";
import {TokenBank} from "../src/D5/TokenBank.sol";
import {YPNFT} from "../src/D6/YPNFT.sol";
import {NFTMarket} from "../src/D6/NFTMarket.sol";
import "forge-std/console.sol";

contract DeployAllScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 ERC20 代币合约
        MyERC20 token = new MyERC20();

        // 2. 部署 TokenBank 银行合约，关联代币
        TokenBank tokenBank = new TokenBank(address(token));

        // 3. 部署 YPNFT 代币合约
        YPNFT nft = new YPNFT();

        // 4. 部署 NFTMarket 市场合约，关联代币和 NFT
        NFTMarket market = new NFTMarket(address(token), address(nft));

        vm.stopBroadcast();

        // 打印部署地址，方便前端和后端配置使用
        console.log("=== Deploy Success ===");
        console.log("MyERC20 Token: ", address(token));
        console.log("TokenBank:     ", address(tokenBank));
        console.log("YPNFT:         ", address(nft));
        console.log("NFTMarket:     ", address(market));
        console.log("======================");
    }
}
