// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 定义接收合约需要实现的回调接口
interface IERC20Receiver {
    function tokensReceived(
        address sender,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract ERC20WithCallback is ERC20 {
    
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    /**
     * @dev 方式一：显式回调转账（类似于 ERC-1363 风格的 transferAndCall）
     * 只有调用此函数时才会携带自定义的 `data` 并触发回调，更加安全和灵活。
     */
    function transferAndCall(
        address to,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        bool success = super.transfer(to, amount);
        require(success, "ERC20: transfer failed");

        if (to.code.length > 0) {
            try IERC20Receiver(to).tokensReceived(msg.sender, amount, data) returns (bool retval) {
                require(retval, "ERC20: receiver rejected tokens");
            } catch {
                revert("ERC20: receiver contract does not implement tokensReceived");
            }
        }
        return true;
    }

    /**
     * @dev 方式二：重写标准的 transfer 函数
     * 使得在进行常规的以太坊 `transfer` 转账给合约地址时，能自动触发回调。
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        bool success = super.transfer(to, amount);
        if (success && to.code.length > 0) {
            _executeCallback(msg.sender, to, amount, "");
        }
        return success;
    }

    /**
     * @dev 方式二：重写标准的 transferFrom 函数
     * 授权转账给合约地址时，自动触发回调。
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        bool success = super.transferFrom(from, to, amount);
        if (success && to.code.length > 0 && msg.sender != to) {
            _executeCallback(from, to, amount, "");
        }
        return success;
    }

    /**
     * @dev 内部辅助函数，安全触发目标合约的 tokensReceived 回调
     */
    function _executeCallback(
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) internal {
        try IERC20Receiver(to).tokensReceived(from, amount, data) returns (bool retval) {
            require(retval, "ERC20: receiver rejected tokens");
        } catch {
            revert("ERC20: receiver contract failed to handle tokensReceived");
        }
    }
}
