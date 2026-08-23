// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {NFTMarketV1} from "./NFTMarketV1.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title NFTMarketV2
 * @dev Upgradeable NFT Market Version 2 adding EIP-712 offline signature listing & purchasing.
 */
contract NFTMarketV2 is NFTMarketV1, EIP712Upgradeable {
    // 追加存储变量：记录各个卖家的 nonce，以防止签名重放
    mapping(address => uint256) public userNonces;

    bytes32 public constant LISTING_TYPEHASH = keccak256(
        "ListingOrder(address seller,address nftAddress,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"
    );

    event NFTSoldWithSignature(
        address indexed buyer,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 nonce
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializer for V2 to setup EIP712 domain.
     */
    function reinitializeV2() public reinitializer(2) {
        __EIP712_init("NFTMarket", "2");
    }

    /**
     * @dev Purchases an NFT listed via off-chain signature.
     * @param seller Address of the NFT owner who signed the listing
     * @param nftAddress NFT contract address
     * @param tokenId NFT token ID
     * @param price Price required in wei
     * @param deadline Expiration timestamp of the signature
     * @param signature Cryptographic signature by the seller
     */
    function buyWithSignature(
        address seller,
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes calldata signature
    ) public payable nonReentrant {
        require(block.timestamp <= deadline, "Signature expired");

        uint256 currentNonce = userNonces[seller];

        bytes32 structHash = keccak256(
            abi.encode(LISTING_TYPEHASH, seller, nftAddress, tokenId, price, currentNonce, deadline)
        );

        bytes32 digest = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(digest, signature);

        require(signer == seller && signer != address(0), "Invalid signature");

        // Increment nonce to prevent replay attacks
        userNonces[seller]++;

        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == seller, "Seller does not own token");
        require(
            nft.isApprovedForAll(seller, address(this)) || nft.getApproved(tokenId) == address(this),
            "Market not approved"
        );
        require(msg.value >= price, "Insufficient payment");

        // Transfer NFT to buyer
        nft.safeTransferFrom(seller, msg.sender, tokenId);

        // Transfer ETH to seller
        (bool success, ) = payable(seller).call{value: price}("");
        require(success, "ETH transfer failed");

        // Refund excess payment
        if (msg.value > price) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - price}("");
            require(refundSuccess, "Refund failed");
        }

        emit NFTSoldWithSignature(msg.sender, seller, nftAddress, tokenId, price, currentNonce);
    }

    /**
     * @dev Returns the EIP-712 hash for a listing order struct.
     */
    function getListingTypedDataHash(
        address seller,
        address nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 nonce,
        uint256 deadline
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(LISTING_TYPEHASH, seller, nftAddress, tokenId, price, nonce, deadline)
        );
        return _hashTypedDataV4(structHash);
    }

    /**
     * @dev Returns the EIP-712 domain separator.
     */
    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
