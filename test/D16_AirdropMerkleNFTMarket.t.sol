// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {AirdropToken} from "../src/D16/AirdropToken.sol";
import {AirdropNFT} from "../src/D16/AirdropNFT.sol";
import {AirdropMerkleNFTMarket} from "../src/D16/AirdropMerkleNFTMarket.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract D16_AirdropMerkleNFTMarketTest is Test, IERC721Receiver {
    AirdropToken public token;
    AirdropNFT public nft;
    AirdropMerkleNFTMarket public market;

    // 私钥与测试账户设置
    uint256 public buyerPrivateKey = 0xA11CE;
    address public buyer;

    address public user2 = address(0x2222);
    address public nonWhitelistUser = address(0x9999);
    address public seller = address(0x7777);

    uint256 public tokenId;
    bytes32 public merkleRoot;
    bytes32[] public buyerProof;

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        buyer = vm.addr(buyerPrivateKey);

        token = new AirdropToken();
        nft = new AirdropNFT();

        // 1. 动态生成 2 个白名单节点的 Merkle Tree (包含 buyer 和 user2)
        bytes32 leaf0 = keccak256(bytes.concat(keccak256(abi.encode(buyer))));
        bytes32 leaf1 = keccak256(bytes.concat(keccak256(abi.encode(user2))));

        if (uint256(leaf0) < uint256(leaf1)) {
            merkleRoot = keccak256(abi.encodePacked(leaf0, leaf1));
        } else {
            merkleRoot = keccak256(abi.encodePacked(leaf1, leaf0));
        }

        // 构造 buyer 的 Proof (兄弟节点即为 leaf1)
        buyerProof.push(leaf1);

        // 2. 部署 AirdropMerkleNFTMarket
        market = new AirdropMerkleNFTMarket(address(token), address(nft), merkleRoot);

        // 3. 给 buyer 铸造 1000 Token
        token.mint(buyer, 1000 * 10 ** token.decimals());

        // 4. 给 seller 铸造 NFT，并授权给市场合约
        tokenId = nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(market), tokenId);
    }

    /**
     * @dev 核心测试：白名单买家通过 Multicall（单笔交易）实现 Permit 预授权 + 100 Token 优惠购买 NFT
     */
    function test_Multicall_PermitAndClaimNFT_Success() public {
        uint256 price = 100 * 10 ** token.decimals();
        uint256 deadline = block.timestamp + 1 hours;

        // 1. 链下构造 EIP-712 Permit 签名 (买家授权给市场合约 100 Token)
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                buyer,
                address(market),
                price,
                token.nonces(buyer),
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, digest);

        // 2. 打包 Multicall 的 2 个 Call 指令数据
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            buyer,
            address(market),
            price,
            deadline,
            v,
            r,
            s
        );
        data[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            tokenId,
            buyerProof
        );

        uint256 buyerTokenBefore = token.balanceOf(buyer);

        // 3. 买家发起单笔 Multicall 交易
        vm.prank(buyer);
        market.multicall(data);

        // 4. 验证资产与状态变动
        // - NFT 所有权已转移至买家
        assertEq(nft.ownerOf(tokenId), buyer);
        // - 100 Token 已划转至市场合约
        assertEq(token.balanceOf(address(market)), price);
        assertEq(buyerTokenBefore - token.balanceOf(buyer), price);
        // - 标记为已领取
        assertTrue(market.hasClaimed(buyer));
    }

    /**
     * @dev 测试防护：非白名单用户尝试提交 Multicall 购买应当 Revert (InvalidProof)
     */
    function test_RevertWhen_NonWhitelistUserTriesToClaim() public {
        uint256 price = 100 * 10 ** token.decimals();
        uint256 deadline = block.timestamp + 1 hours;

        // 给非白名单用户铸造 Token
        token.mint(nonWhitelistUser, 1000 * 10 ** token.decimals());

        // 为 nonWhitelistUser 生成通用私钥签名 (伪造签名)
        uint256 nonWhitelistKey = 0x9999;
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                nonWhitelistUser,
                address(market),
                price,
                token.nonces(nonWhitelistUser),
                deadline
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(nonWhitelistKey, digest);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            nonWhitelistUser,
            address(market),
            price,
            deadline,
            v,
            r,
            s
        );
        data[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            tokenId,
            buyerProof // 使用他人的证明
        );

        // 发起 Multicall 应当失败，抛出 InvalidProof
        vm.prank(nonWhitelistUser);
        vm.expectRevert();
        market.multicall(data);
    }

    /**
     * @dev 测试防护：白名单用户重复购买应当 Revert (AlreadyClaimed)
     */
    function test_RevertWhen_AlreadyClaimed() public {
        // 先成功完成第 1 次购买
        test_Multicall_PermitAndClaimNFT_Success();

        // 铸造新的 NFT
        uint256 nextTokenId = nft.mint(seller);
        vm.prank(seller);
        nft.approve(address(market), nextTokenId);

        // 再次尝试领取
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(
            market.claimNFT.selector,
            nextTokenId,
            buyerProof
        );

        vm.prank(buyer);
        vm.expectRevert();
        market.multicall(data);
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
