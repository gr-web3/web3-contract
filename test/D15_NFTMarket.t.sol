// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MyERC20} from "../src/D6/MyERC20.sol";
import {MyNFT} from "../src/D6/MyNFT.sol";
import {NFTMarketOriginal} from "../src/D15/NFTMarketOriginal.sol";
import {NFTMarketOptimized} from "../src/D15/NFTMarketOptimized.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// ----------------------------------------------------------------------------
// 1. 测试未优化的原始合约 (Original)
// ----------------------------------------------------------------------------
contract D15_NFTMarketOriginalTest is Test, IERC721Receiver {
    MyERC20 public token;
    MyNFT public nft;
    NFTMarketOriginal public market;

    address public seller = address(0x10);
    address public buyer = address(0x20);
    uint256 public tokenId;

    function setUp() public {
        token = new MyERC20();
        nft = new MyNFT();
        market = new NFTMarketOriginal(address(token), address(nft));

        token.mint(buyer, 1000 * 10 ** token.decimals());

        vm.prank(seller);
        tokenId = nft.mint(seller);
    }

    function test_ListNFT() public {
        uint256 price = 100 * 10 ** token.decimals();

        vm.startPrank(seller);
        vm.expectRevert("NFTMarket: market not approved for this NFT");
        market.list(tokenId, price);

        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
    }

    function test_BuyNFT_Traditional() public {
        uint256 price = 100 * 10 ** token.decimals();

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.startPrank(buyer);
        token.approve(address(market), price);
        market.buyNFT(tokenId, price);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);

        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function test_BuyNFT_Callback() public {
        uint256 price = 100 * 10 ** token.decimals();

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.prank(buyer);
        token.transferAndCall(address(market), price, abi.encode(tokenId));

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
    }

    function test_BuyNFT_Callback_WithRefund() public {
        uint256 price = 100 * 10 ** token.decimals();
        uint256 payAmount = 150 * 10 ** token.decimals();

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        vm.prank(buyer);
        token.transferAndCall(address(market), payAmount, abi.encode(tokenId));

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
        assertEq(buyerBalanceBefore - token.balanceOf(buyer), price);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// ----------------------------------------------------------------------------
// 2. 测试优化后的合约 (Optimized)
// ----------------------------------------------------------------------------
contract D15_NFTMarketOptimizedTest is Test, IERC721Receiver {
    MyERC20 public token;
    MyNFT public nft;
    NFTMarketOptimized public market;

    address public seller = address(0x10);
    address public buyer = address(0x20);
    uint256 public tokenId;

    function setUp() public {
        token = new MyERC20();
        nft = new MyNFT();
        market = new NFTMarketOptimized(address(token), address(nft));

        token.mint(buyer, 1000 * 10 ** token.decimals());

        vm.prank(seller);
        tokenId = nft.mint(seller);
    }

    function test_ListNFT() public {
        uint256 price = 100 * 10 ** token.decimals();

        vm.startPrank(seller);
        vm.expectRevert(NFTMarketOptimized.MarketNotApproved.selector);
        market.list(tokenId, price);

        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        (address listedSeller, uint96 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
    }

    function test_BuyNFT_Traditional() public {
        uint256 price = 100 * 10 ** token.decimals();

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.startPrank(buyer);
        token.approve(address(market), price);
        market.buyNFT(tokenId, price);
        vm.stopPrank();

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);

        (address listedSeller, uint96 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function test_BuyNFT_Callback() public {
        uint256 price = 100 * 10 ** token.decimals();

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        vm.prank(buyer);
        token.transferAndCall(address(market), price, abi.encode(tokenId));

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
    }

    function test_BuyNFT_Callback_WithRefund() public {
        uint256 price = 100 * 10 ** token.decimals();
        uint256 payAmount = 150 * 10 ** token.decimals();

        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        vm.prank(buyer);
        token.transferAndCall(address(market), payAmount, abi.encode(tokenId));

        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
        assertEq(buyerBalanceBefore - token.balanceOf(buyer), price);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
