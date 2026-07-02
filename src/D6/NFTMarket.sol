// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./MyERC20.sol"; // 导入 IERC20Receiver 接口定义

contract NFTMarket is IERC20Receiver {
    IERC20 public immutable token;
    IERC721 public immutable nft;

    struct Listing {
        address seller;
        uint256 price;
    }

    // tokenId => Listing
    mapping(uint256 => Listing) public listings;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed buyer, address indexed seller, uint256 price);

    constructor(address _token, address _nft) {
        require(_token != address(0) && _nft != address(0), "NFTMarket: address cannot be zero");
        token = IERC20(_token);
        nft = IERC721(_nft);
    }

    /**
     * @dev 上架 NFT，设置价格（需要多少个 ERC20 代币）
     */
    function list(uint256 tokenId, uint256 price) external {
        require(nft.ownerOf(tokenId) == msg.sender, "NFTMarket: only owner can list");
        require(price > 0, "NFTMarket: price must be greater than zero");
        
        // 检查市场是否获得划转该 NFT 的授权
        require(
            nft.getApproved(tokenId) == address(this) || nft.isApprovedForAll(msg.sender, address(this)),
            "NFTMarket: market not approved for this NFT"
        );

        listings[tokenId] = Listing({
            seller: msg.sender,
            price: price
        });

        emit NFTListed(tokenId, msg.sender, price);
    }

    /**
     * @dev 购买 NFT（传统方式：通过 approve 授权划转代币）
     */
    function buyNFT(uint256 tokenId, uint256 amount) external {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "NFTMarket: token not listed");
        require(amount >= listing.price, "NFTMarket: price mismatch or insufficient payment");

        // 遵循 Checks-Effects-Interactions 模式，先修改状态，防止重入
        delete listings[tokenId];

        // 1. 划转 ERC20 代币给卖家
        bool success = token.transferFrom(msg.sender, listing.seller, listing.price);
        require(success, "NFTMarket: token transfer failed");

        // 2. 转移 NFT 给买家
        nft.safeTransferFrom(listing.seller, msg.sender, tokenId);

        emit NFTSold(tokenId, msg.sender, listing.seller, listing.price);
    }

    /**
     * @dev 购买 NFT（回调方式：在 ERC20 token 的 transferAndCall 回调中自动完成购买）
     * 额外数据参数 `data` 需传入编码后的 `tokenId`
     */
    function tokensReceived(
        address sender,
        uint256 amount,
        bytes calldata data
    ) external override returns (bool) {
        // 安全检查：只有关联的 Token 合约发起的调用才被接受
        require(msg.sender == address(token), "NFTMarket: only accept designated token callback");

        // 从 data 中解码得到要购买的 tokenId
        uint256 tokenId = abi.decode(data, (uint256));
        Listing memory listing = listings[tokenId];
        
        require(listing.seller != address(0), "NFTMarket: token not listed");
        require(amount >= listing.price, "NFTMarket: insufficient token amount sent");

        // 遵循 Checks-Effects-Interactions 模式，先修改状态，防止重入
        delete listings[tokenId];

        // 此时代币已在市场合约中，需将 listing.price 个代币付给卖家
        bool success = token.transfer(listing.seller, listing.price);
        require(success, "NFTMarket: payment to seller failed");

        // 如果用户多传了代币，退还溢出的代币给买家
        if (amount > listing.price) {
            bool refundSuccess = token.transfer(sender, amount - listing.price);
            require(refundSuccess, "NFTMarket: refund to buyer failed");
        }

        // 转移 NFT 给买家
        nft.safeTransferFrom(listing.seller, sender, tokenId);

        emit NFTSold(tokenId, sender, listing.seller, listing.price);

        return true;
    }
}
