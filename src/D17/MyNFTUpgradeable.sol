// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title MyNFTUpgradeable
 * @dev Upgradeable ERC721 Token contract using UUPS Proxy pattern.
 */
contract MyNFTUpgradeable is Initializable, ERC721Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract setting the token name, symbol, and owner.
     * @param name Token collection name
     * @param symbol Token collection symbol
     * @param initialOwner Address of the contract owner
     */
    function initialize(string memory name, string memory symbol, address initialOwner) public initializer {
        __ERC721_init(name, symbol);
        __Ownable_init(initialOwner);
    }

    /**
     * @dev Mints a new NFT to the specified address.
     * @param to Recipient address
     * @param tokenId ID of the token to mint
     */
    function mint(address to, uint256 tokenId) public {
        _safeMint(to, tokenId);
    }

    /**
     * @dev Restricts contract upgrades to contract owner.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
