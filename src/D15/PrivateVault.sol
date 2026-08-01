// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title PrivateVault
 * @notice 包含多种常见 Solidity 存储布局类型私有变量的合约（用于 15.3 读取私有变量实验）
 */
contract PrivateVault {
    // ------------------------------------------------------------------------
    // 1. 标量私有变量 (Slot 0)
    // ------------------------------------------------------------------------
    uint256 private secretPassword;

    // ------------------------------------------------------------------------
    // 2. 紧凑打包的私有变量 (Slot 1)
    // address(20 bytes) + uint96(12 bytes) = 32 bytes 刚好填满 Slot 1
    // ------------------------------------------------------------------------
    address private admin;
    uint96 private vaultId;

    // ------------------------------------------------------------------------
    // 3. 私有映射 Mapping (Slot 2 占位)
    // ------------------------------------------------------------------------
    mapping(address => uint256) private userRewards;

    // ------------------------------------------------------------------------
    // 4. 私有动态数组 Array (Slot 3 存 length)
    // ------------------------------------------------------------------------
    uint256[] private secretCodes;

    constructor(uint256 _password, address _admin, uint96 _vaultId) {
        secretPassword = _password;
        admin = _admin;
        vaultId = _vaultId;
    }

    /**
     * @dev 初始化 Mapping 与 Array 模拟写入私有数据
     */
    function initializeData(address user, uint256 reward, uint256 code1, uint256 code2) external {
        require(msg.sender == admin, "Only admin");
        userRewards[user] = reward;
        secretCodes.push(code1);
        secretCodes.push(code2);
    }
}
