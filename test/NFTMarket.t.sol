// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MyERC20} from "../src/D6/MyERC20.sol";
import {MyNFT} from "../src/D6/MyNFT.sol";
import {NFTMarket} from "../src/D6/NFTMarket.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTMarketTest is Test, IERC721Receiver {
    MyERC20 public token;
    MyNFT public nft;
    NFTMarket public market;

    address public seller = address(0x10);
    address public buyer = address(0x20);
    uint256 public tokenId;

    function setUp() public {
        token = new MyERC20();
        nft = new MyNFT();
        market = new NFTMarket(address(token), address(nft));

        // 1. 给 buyer 铸造一些代币
        token.mint(buyer, 1000 * 10 ** token.decimals());

        // 2. 给 seller 铸造一个 NFT
        vm.prank(seller);
        tokenId = nft.mint(seller);
    }

    function test_ListNFT() public {
        uint256 price = 100 * 10 ** token.decimals();

        // 没授权上架应当失败
        vm.startPrank(seller);
        vm.expectRevert("NFTMarket: market not approved for this NFT");
        market.list(tokenId, price);

        // 授权给市场
        nft.approve(address(market), tokenId);

        // 再次上架应当成功
        market.list(tokenId, price);
        vm.stopPrank();

        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, seller);
        assertEq(listedPrice, price);
    }

    function test_BuyNFT_Traditional() public {
        uint256 price = 100 * 10 ** token.decimals();

        // 1. Seller 授权并上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        // 2. Buyer 授权代币给市场
        vm.startPrank(buyer);
        token.approve(address(market), price);

        // 3. Buyer 购买 NFT
        market.buyNFT(tokenId, price);
        vm.stopPrank();

        // 4. 验证资产转移
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);

        // 验证上架信息已被清除
        (address listedSeller, uint256 listedPrice) = market.listings(tokenId);
        assertEq(listedSeller, address(0));
        assertEq(listedPrice, 0);
    }

    function test_BuyNFT_Callback() public {
        uint256 price = 100 * 10 ** token.decimals();

        // 1. Seller 授权并上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        // 2. Buyer 调用 transferAndCall 直接买，省去单独 approve 步骤
        vm.prank(buyer);
        token.transferAndCall(address(market), price, abi.encode(tokenId));

        // 3. 验证资产转移
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
    }

    function test_BuyNFT_Callback_WithRefund() public {
        uint256 price = 100 * 10 ** token.decimals();
        uint256 payAmount = 150 * 10 ** token.decimals(); // 溢出支付

        // 1. Seller 授权并上架 NFT
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        market.list(tokenId, price);
        vm.stopPrank();

        uint256 buyerBalanceBefore = token.balanceOf(buyer);

        // 2. Buyer 调用 transferAndCall 超额支付
        vm.prank(buyer);
        token.transferAndCall(address(market), payAmount, abi.encode(tokenId));

        // 3. 验证资产转移和退款
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(token.balanceOf(seller), price);
        // 应该退回 50 代币给 buyer，即 buyer 实际只花去了 100 代币
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
