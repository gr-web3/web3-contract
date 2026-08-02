// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title AirdropNFT
 * @notice 测试用的 ERC721 NFT 合约
 */
contract AirdropNFT is ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("AirdropNFT", "ANFT") {}

    function mint(address to) external returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}
