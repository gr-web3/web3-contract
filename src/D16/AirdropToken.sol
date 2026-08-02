// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title AirdropToken
 * @notice 支持 ERC20Permit (EIP-2612 签名授权) 的测试代币
 */
contract AirdropToken is ERC20, ERC20Permit {
    constructor() ERC20("AirdropToken", "ADT") ERC20Permit("AirdropToken") {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
