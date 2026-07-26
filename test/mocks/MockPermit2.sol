// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../src/D12/IPermit2.sol";

/**
 * @title MockPermit2
 * @dev 本地 Foundry 测试用的 Permit2 模拟合约
 */
contract MockPermit2 is IPermit2 {
    mapping(address => mapping(uint256 => bool)) public nonceUsed;

    function permitTransferFrom(
        PermitTransferFrom calldata permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external override {
        require(block.timestamp <= permit.deadline, "Permit2: expired");
        require(!nonceUsed[owner][permit.nonce], "Permit2: nonce already used");
        require(signature.length > 0, "Permit2: invalid signature");

        nonceUsed[owner][permit.nonce] = true;

        bool success = IERC20(permit.permissions.token).transferFrom(
            owner,
            transferDetails.to,
            transferDetails.requestedAmount
        );
        require(success, "Permit2: transfer failed");
    }
}
