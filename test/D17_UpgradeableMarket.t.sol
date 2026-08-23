// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MyNFTUpgradeable} from "../src/D17/MyNFTUpgradeable.sol";
import {NFTMarketV1} from "../src/D17/NFTMarketV1.sol";
import {NFTMarketV2} from "../src/D17/NFTMarketV2.sol";

contract D17_UpgradeableMarketTest is Test {
    MyNFTUpgradeable public nftProxy;
    NFTMarketV1 public marketV1Proxy;
    NFTMarketV2 public marketV2Proxy;

    address public owner = address(this);
    uint256 public sellerPrivateKey = 0xA11CE;
    address public seller;
    address public buyer = address(0x2222);

    function setUp() public {
        seller = vm.addr(sellerPrivateKey);

        // 1. Deploy MyNFTUpgradeable Implementation and Proxy
        MyNFTUpgradeable nftImpl = new MyNFTUpgradeable();
        bytes memory nftInitData = abi.encodeWithSelector(MyNFTUpgradeable.initialize.selector, "Upchain NFT", "UNFT", owner);
        ERC1967Proxy nftProxyContract = new ERC1967Proxy(address(nftImpl), nftInitData);
        nftProxy = MyNFTUpgradeable(address(nftProxyContract));

        // 2. Deploy NFTMarketV1 Implementation and Proxy
        NFTMarketV1 marketV1Impl = new NFTMarketV1();
        bytes memory marketInitData = abi.encodeWithSelector(NFTMarketV1.initialize.selector, owner);
        ERC1967Proxy marketProxyContract = new ERC1967Proxy(address(marketV1Impl), marketInitData);
        marketV1Proxy = NFTMarketV1(address(marketProxyContract));

        // Fund accounts
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);
    }

    function test_V1_ListAndBuy() public {
        // Mint NFT to seller
        nftProxy.mint(seller, 1);

        vm.startPrank(seller);
        nftProxy.setApprovalForAll(address(marketV1Proxy), true);
        marketV1Proxy.list(address(nftProxy), 1, 1 ether);
        vm.stopPrank();

        (address listedSeller, uint256 price, bool active) = marketV1Proxy.listings(address(nftProxy), 1);
        assertEq(listedSeller, seller);
        assertEq(price, 1 ether);
        assertTrue(active);

        uint256 sellerBalBefore = seller.balance;

        vm.prank(buyer);
        marketV1Proxy.buyNFT{value: 1 ether}(address(nftProxy), 1);

        assertEq(nftProxy.ownerOf(1), buyer);
        assertEq(seller.balance, sellerBalBefore + 1 ether);

        (, , bool activeAfter) = marketV1Proxy.listings(address(nftProxy), 1);
        assertFalse(activeAfter);
    }

    function test_UpgradeToV2() public {
        // Deploy V2 Implementation
        NFTMarketV2 marketV2Impl = new NFTMarketV2();

        // Upgrade Proxy to V2 and reinitialize EIP712
        bytes memory upgradeData = abi.encodeWithSelector(NFTMarketV2.reinitializeV2.selector);
        marketV1Proxy.upgradeToAndCall(address(marketV2Impl), upgradeData);

        marketV2Proxy = NFTMarketV2(address(marketV1Proxy));

        // Verify V2 function works and nonces mapping is available
        assertEq(marketV2Proxy.userNonces(seller), 0);
        assertTrue(marketV2Proxy.LISTING_TYPEHASH() != bytes32(0));
    }

    function test_V2_BuyWithSignature() public {
        // First upgrade to V2
        test_UpgradeToV2();

        // Mint NFT #2 to seller
        nftProxy.mint(seller, 2);

        // Seller approves market once
        vm.prank(seller);
        nftProxy.setApprovalForAll(address(marketV2Proxy), true);

        uint256 price = 0.5 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = marketV2Proxy.userNonces(seller);

        // Seller signs listing order off-chain
        bytes32 digest = marketV2Proxy.getListingTypedDataHash(
            seller,
            address(nftProxy),
            2,
            price,
            nonce,
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        uint256 sellerBalBefore = seller.balance;

        // Buyer executes buyWithSignature
        vm.prank(buyer);
        marketV2Proxy.buyWithSignature{value: price}(
            seller,
            address(nftProxy),
            2,
            price,
            deadline,
            signature
        );

        // Assertions
        assertEq(nftProxy.ownerOf(2), buyer);
        assertEq(seller.balance, sellerBalBefore + price);
        assertEq(marketV2Proxy.userNonces(seller), 1);
    }

    function test_V2_ReplaySignatureFails() public {
        test_V2_BuyWithSignature();

        // Mint another NFT #3 to seller
        nftProxy.mint(seller, 3);

        uint256 price = 0.5 ether;
        uint256 deadline = block.timestamp + 1 hours;
        // Using old nonce 0 digest & signature
        bytes32 digest = marketV2Proxy.getListingTypedDataHash(
            seller,
            address(nftProxy),
            3,
            price,
            0, // stale nonce
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Expect revert due to invalid signature (signer recovery won't match seller with current nonce 1)
        vm.prank(buyer);
        vm.expectRevert("Invalid signature");
        marketV2Proxy.buyWithSignature{value: price}(
            seller,
            address(nftProxy),
            3,
            price,
            deadline,
            signature
        );
    }

    function test_V2_ExpiredSignatureFails() public {
        test_UpgradeToV2();
        nftProxy.mint(seller, 4);

        vm.prank(seller);
        nftProxy.setApprovalForAll(address(marketV2Proxy), true);

        uint256 price = 0.5 ether;
        uint256 deadline = block.timestamp - 1; // Expired
        uint256 nonce = marketV2Proxy.userNonces(seller);

        bytes32 digest = marketV2Proxy.getListingTypedDataHash(
            seller,
            address(nftProxy),
            4,
            price,
            nonce,
            deadline
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sellerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(buyer);
        vm.expectRevert("Signature expired");
        marketV2Proxy.buyWithSignature{value: price}(
            seller,
            address(nftProxy),
            4,
            price,
            deadline,
            signature
        );
    }

    function test_UnauthorizedUpgradeFails() public {
        NFTMarketV2 marketV2Impl = new NFTMarketV2();

        // Non-owner attempts upgrade
        vm.prank(buyer);
        vm.expectRevert();
        marketV1Proxy.upgradeToAndCall(address(marketV2Impl), "");
    }
}
