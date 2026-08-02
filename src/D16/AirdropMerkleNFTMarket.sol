// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

/**
 * @title AirdropMerkleNFTMarket
 * @notice 结合 Multicall、Merkle 白名单树与 ERC20 Permit 的优惠价格 (100 Token) NFT 市场
 */
contract AirdropMerkleNFTMarket is Multicall {
    IERC20 public immutable token;
    IERC721 public immutable nft;
    bytes32 public immutable merkleRoot;

    // 优惠白名单价格：100 Token (假设 18 decimals)
    uint256 public constant DISCOUNT_PRICE = 100 * 10 ** 18;

    // 记录白名单地址是否已享受优惠领取过 NFT (防重领)
    mapping(address => bool) public hasClaimed;

    error AlreadyClaimed();
    error InvalidProof();
    error TransferFailed();
    error PriceZero();

    event NFTSold(uint256 indexed tokenId, address indexed buyer, uint256 price);

    constructor(address _token, address _nft, bytes32 _merkleRoot) {
        token = IERC20(_token);
        nft = IERC721(_nft);
        merkleRoot = _merkleRoot;
    }

    /**
     * @dev 1. 预支付授权方法 (调用 ERC20Permit 签名核销)
     */
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(token)).permit(owner, spender, value, deadline, v, r, s);
    }

    /**
     * @dev 2. 默克尔树白名单验证并使用优惠价购买 NFT
     * @param tokenId 欲购买的 NFT ID
     * @param proof 白名单 Merkle Proof 路径
     */
    function claimNFT(uint256 tokenId, bytes32[] calldata proof) external {
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();

        // 计算当前 msg.sender 的白名单叶子哈希节点 (二次哈希规避叶子节点重叠攻击)
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert InvalidProof();

        // 标记已领取，防止重复领取
        hasClaimed[msg.sender] = true;

        // 扣除 100 Token (依赖 permitPrePay 先行完成授权)
        bool success = token.transferFrom(msg.sender, address(this), DISCOUNT_PRICE);
        if (!success) revert TransferFailed();

        // 获取该 NFT 当前持有者，并转移给买家 (需确保持有者已授权本市场合约)
        address seller = nft.ownerOf(tokenId);
        nft.safeTransferFrom(seller, msg.sender, tokenId);

        emit NFTSold(tokenId, msg.sender, DISCOUNT_PRICE);
    }
}
