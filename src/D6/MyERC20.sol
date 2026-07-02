// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ERC20 接收者接口
interface IERC20Receiver {
    function tokensReceived(
        address sender,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract MyERC20 is ERC20 {
    constructor() ERC20("MyERC20", "ME20") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @dev 携带回调的转账，若接收方为合约，将触发其 tokensReceived 回调
     */
    function transferAndCall(
        address to,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        bool success = transfer(to, amount);
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
}
