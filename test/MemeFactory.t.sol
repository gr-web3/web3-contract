// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/D14/MemeFactory.sol";
import "../src/D14/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;

    address public creator = address(0x1111);
    address public user1 = address(0x2222);
    address public user2 = address(0x3333);

    event InscriptionDeployed(
        address indexed tokenAddr,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        address indexed creator
    );

    event InscriptionMinted(
        address indexed tokenAddr,
        address indexed minter,
        uint256 amount
    );

    function setUp() public {
        factory = new MemeFactory();
    }

    function test_DeployInscription_Success() public {
        vm.prank(creator);
        
        address tokenAddr = factory.deployInscription("PEPE", 10_000 * 1e18, 1_000 * 1e18);

        assertTrue(tokenAddr != address(0));
        assertTrue(factory.isInscription(tokenAddr));
        assertEq(factory.getInscriptionCount(), 1);
        assertEq(factory.getAllInscriptions()[0], tokenAddr);

        MemeToken token = MemeToken(tokenAddr);
        assertEq(token.symbol(), "PEPE");
        assertEq(token.name(), "Meme Inscription PEPE");
        assertEq(token.totalSupplyCap(), 10_000 * 1e18);
        assertEq(token.perMint(), 1_000 * 1e18);
        assertEq(token.factory(), address(factory));
        assertEq(token.currentMinted(), 0);
    }

    function test_MintInscription_Success() public {
        vm.prank(creator);
        address tokenAddr = factory.deployInscription("DOGE", 5_000 * 1e18, 1_000 * 1e18);
        MemeToken token = MemeToken(tokenAddr);

        // User1 铸造
        vm.prank(user1);
        factory.mintInscription(tokenAddr);

        assertEq(token.balanceOf(user1), 1_000 * 1e18);
        assertEq(token.currentMinted(), 1_000 * 1e18);

        // User2 铸造
        vm.prank(user2);
        factory.mintInscription(tokenAddr);

        assertEq(token.balanceOf(user2), 1_000 * 1e18);
        assertEq(token.currentMinted(), 2_000 * 1e18);
    }

    function test_MintInscription_RevertExceedsCap() public {
        // 总上限仅 2000，每次 1000
        vm.prank(creator);
        address tokenAddr = factory.deployInscription("SHIB", 2_000 * 1e18, 1_000 * 1e18);

        // 第一次铸造 (1000)
        vm.prank(user1);
        factory.mintInscription(tokenAddr);

        // 第二次铸造 (2000)
        vm.prank(user2);
        factory.mintInscription(tokenAddr);

        // 第三次铸造超出上限 2000 -> 失败抛出异常
        vm.prank(user1);
        vm.expectRevert("MemeToken: exceeds total supply cap");
        factory.mintInscription(tokenAddr);
    }

    function test_RevertReinitialize() public {
        vm.prank(creator);
        address tokenAddr = factory.deployInscription("FLOKI", 10_000 * 1e18, 1_000 * 1e18);
        MemeToken token = MemeToken(tokenAddr);

        // 尝试二次调用 initialize -> 必定触发 Initializable 的 InvalidInitialization 逻辑
        vm.expectRevert();
        token.initialize("HACK", 99_999 * 1e18, 99_999 * 1e18, address(0x9999));
    }

    function test_MintInscription_RevertInvalidTokenAddress() public {
        address fakeToken = address(0x9999);
        vm.prank(user1);
        vm.expectRevert("MemeFactory: invalid inscription token");
        factory.mintInscription(fakeToken);
    }
}
