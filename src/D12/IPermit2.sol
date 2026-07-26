// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPermit2
 * @dev Uniswap Permit2 接口定义
 */
interface IPermit2 {
    /// @notice 权限转账的代币及数量结构体
    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    /// @notice 签名转账授权许可结构体
    struct PermitTransferFrom {
        TokenPermissions permissions;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice 转账接收方与实际转账金额结构体
    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    /**
     * @notice 通过 Permit2 签名授权将代币从 owner 转转移给接收方
     * @param permit 包含代币、授权数量、nonce、deadline 的授权结构体
     * @param transferDetails 包含接收方地址与请求转账金额
     * @param owner 代币拥有者（签名者地址）
     * @param signature 符合 EIP-712 规范的 Permit2 签名
     */
    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}
