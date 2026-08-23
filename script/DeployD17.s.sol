// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MyNFTUpgradeable} from "../src/D17/MyNFTUpgradeable.sol";
import {NFTMarketV1} from "../src/D17/NFTMarketV1.sol";
import {NFTMarketV2} from "../src/D17/NFTMarketV2.sol";

contract DeployD17Script is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy MyNFTUpgradeable Implementation and Proxy
        MyNFTUpgradeable nftImpl = new MyNFTUpgradeable();
        bytes memory nftInitData = abi.encodeWithSelector(
            MyNFTUpgradeable.initialize.selector,
            "Upchain NFT",
            "UNFT",
            deployer
        );
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftImpl), nftInitData);

        // 2. Deploy NFTMarketV1 Implementation and Proxy
        NFTMarketV1 marketV1Impl = new NFTMarketV1();
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketV1.initialize.selector,
            deployer
        );
        ERC1967Proxy marketProxy = new ERC1967Proxy(address(marketV1Impl), marketInitData);

        // 3. Deploy NFTMarketV2 Implementation
        NFTMarketV2 marketV2Impl = new NFTMarketV2();

        // 4. Upgrade NFTMarket Proxy from V1 to V2
        bytes memory upgradeData = abi.encodeWithSelector(NFTMarketV2.reinitializeV2.selector);
        NFTMarketV1(address(marketProxy)).upgradeToAndCall(address(marketV2Impl), upgradeData);

        vm.stopBroadcast();

        console.log("------------------- Deployment Log -------------------");
        console.log("MyNFT Proxy Address:                ", address(nftProxy));
        console.log("MyNFT Implementation Address:         ", address(nftImpl));
        console.log("NFTMarket Proxy Address:             ", address(marketProxy));
        console.log("NFTMarket V1 Implementation Address: ", address(marketV1Impl));
        console.log("NFTMarket V2 Implementation Address: ", address(marketV2Impl));
        console.log("------------------------------------------------------");
    }
}
