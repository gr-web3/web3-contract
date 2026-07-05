// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// 继承自 ERC721URIStorage
contract YPNFT is ERC721URIStorage {
    uint256 private _nextTokenId;

    constructor() ERC721("YPNFT", "YPNFT") {}

    /**
     * @dev 铸造 NFT 并绑定其元数据 JSON 链接
     * @param to 接收 NFT 的地址
     * @param tokenURI 刚才上传的 JSON 文件的 IPFS 地址 (例如 "ipfs://QmYyy...")
     */
    function mint(
        address to,
        string memory tokenURI
    ) external returns (uint256) {
        uint256 tokenId = _nextTokenId;
        _safeMint(to, tokenId);

        // 绑定该 tokenId 的元数据
        _setTokenURI(tokenId, tokenURI);

        _nextTokenId++;
        return tokenId;
    }
}
