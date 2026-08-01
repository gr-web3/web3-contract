// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../D6/MyERC20.sol";

/**
 * @title NFTMarketOptimized
 * @notice 高度 Gas 优化的 NFT 市场合约
 */
contract NFTMarketOptimized is IERC20Receiver {
    IERC20 public immutable token;
    IERC721 public immutable nft;

    // 自定义异常（替代长字符串 require，减少 Deployment Code & Runtime Gas）
    error ZeroAddress();
    error NotNFTOwner();
    error PriceZero();
    error PriceTooHigh();
    error MarketNotApproved();
    error TokenNotListed();
    error InsufficientPayment();
    error TransferFailed();
    error OnlyTokenCallback();

    // 结构体紧凑打包：address(160bits) + uint96(96bits) = 256bits (恰好 1 个 Storage Slot)
    struct Listing {
        address seller;
        uint96 price;
    }

    // tokenId => Listing
    mapping(uint256 => Listing) public listings;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

    constructor(address _token, address _nft) {
        if (_token == address(0) || _nft == address(0)) revert ZeroAddress();
        token = IERC20(_token);
        nft = IERC721(_nft);
    }

    /**
     * @dev 上架 NFT
     */
    function list(uint256 tokenId, uint256 price) external {
        if (price == 0) revert PriceZero();
        if (price > type(uint96).max) revert PriceTooHigh();
        if (nft.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();

        if (nft.getApproved(tokenId) != address(this) && !nft.isApprovedForAll(msg.sender, address(this))) {
            revert MarketNotApproved();
        }

        // 打包写入，仅占用 1 个 SSTORE 槽位
        listings[tokenId] = Listing({
            seller: msg.sender,
            price: uint96(price)
        });

        emit NFTListed(tokenId, msg.sender, price);
    }

    /**
     * @dev 购买 NFT（传统 approve 方式）
     */
    function buyNFT(uint256 tokenId, uint256 amount) external {
        Listing memory listing = listings[tokenId];
        address seller = listing.seller;
        if (seller == address(0)) revert TokenNotListed();
        uint256 price = listing.price;
        if (amount < price) revert InsufficientPayment();

        // 清空 1 个槽位，释放 Storage 槽并获得 Gas Refund
        delete listings[tokenId];

        // 转账 ERC20 代币
        if (!token.transferFrom(msg.sender, seller, price)) revert TransferFailed();

        // 转移 NFT
        nft.safeTransferFrom(seller, msg.sender, tokenId);

        emit NFTSold(tokenId, msg.sender, seller, price);
    }

    /**
     * @dev 购买 NFT（transferAndCall 回调方式）
     */
    function tokensReceived(
        address sender,
        uint256 amount,
        bytes calldata data
    ) external override returns (bool) {
        if (msg.sender != address(token)) revert OnlyTokenCallback();

        // 汇编提取 calldata 中的 tokenId，避免 abi.decode 开销
        uint256 tokenId;
        assembly {
            tokenId := calldataload(data.offset)
        }

        Listing memory listing = listings[tokenId];
        address seller = listing.seller;
        if (seller == address(0)) revert TokenNotListed();
        uint256 price = listing.price;
        if (amount < price) revert InsufficientPayment();

        // 删除 listing 释放存储槽
        delete listings[tokenId];

        // 付款给 seller
        if (!token.transfer(seller, price)) revert TransferFailed();

        // 超额退款处理（使用 unchecked 避免已知无溢出的减法开销）
        if (amount > price) {
            unchecked {
                uint256 refund = amount - price;
                if (!token.transfer(sender, refund)) revert TransferFailed();
            }
        }

        // 转移 NFT 给 buyer
        nft.safeTransferFrom(seller, sender, tokenId);

        emit NFTSold(tokenId, sender, seller, price);

        return true;
    }
}
