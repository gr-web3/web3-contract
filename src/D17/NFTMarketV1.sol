// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NFTMarketV1
 * @dev Upgradeable NFT Market Version 1 with basic listing and purchase functionality.
 */
contract NFTMarketV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard {
    struct Listing {
        address seller;
        uint256 price;
        bool active;
    }

    // Mapping: nftAddress => tokenId => Listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    event Listed(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price);
    event ListingCancelled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract.
     * @param initialOwner Owner address who can authorize upgrades
     */
    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
    }

    /**
     * @dev Lists an NFT on the marketplace.
     * @param nftAddress Contract address of the NFT
     * @param tokenId ID of the token to list
     * @param price Listing price in wei
     */
    function list(address nftAddress, uint256 tokenId, uint256 price) public {
        require(price > 0, "Price must be greater than zero");
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not token owner");
        require(
            nft.isApprovedForAll(msg.sender, address(this)) || nft.getApproved(tokenId) == address(this),
            "Market not approved"
        );

        listings[nftAddress][tokenId] = Listing({
            seller: msg.sender,
            price: price,
            active: true
        });

        emit Listed(msg.sender, nftAddress, tokenId, price);
    }

    /**
     * @dev Purchases a listed NFT.
     * @param nftAddress Contract address of the NFT
     * @param tokenId ID of the token to buy
     */
    function buyNFT(address nftAddress, uint256 tokenId) public payable nonReentrant {
        Listing memory listing = listings[nftAddress][tokenId];
        require(listing.active, "Listing not active");
        require(msg.value >= listing.price, "Insufficient payment");

        listings[nftAddress][tokenId].active = false;

        IERC721(nftAddress).safeTransferFrom(listing.seller, msg.sender, tokenId);

        (bool success, ) = payable(listing.seller).call{value: listing.price}("");
        require(success, "ETH transfer failed");

        if (msg.value > listing.price) {
            (bool refundSuccess, ) = payable(msg.sender).call{value: msg.value - listing.price}("");
            require(refundSuccess, "Refund failed");
        }

        emit NFTSold(msg.sender, listing.seller, nftAddress, tokenId, listing.price);
    }

    /**
     * @dev Authorizes contract upgrades.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Storage gap to reserve space for future state variables.
     */
    uint256[49] private __gap;
}
