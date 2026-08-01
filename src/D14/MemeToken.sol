// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title MemeToken
 * @dev Meme 铭文代币逻辑实现合约（最小代理模板）
 */
contract MemeToken is ERC20, Initializable {
    uint256 public totalSupplyCap; // 总发行上限
    uint256 public perMint;        // 单次铸造额度
    uint256 public currentMinted;  // 当前已铸造总量
    address public factory;        // 关联的铭文工厂合约地址

    string private customName;
    string private customSymbol;

    event Mint(address indexed minter, uint256 amount, uint256 totalMinted);

    constructor() ERC20("Meme Inscription Template", "MEME_TMPL") {
        // 部署模板合约本身时封锁初始化，防止模板被攻击篡改
        _disableInitializers();
    }

    /**
     * @dev 初始化克隆出来的 Minimal Proxy 代理合约参数
     * @param _symbol 代币符号 (如 "DOGE", "PEPE")
     * @param _totalSupplyCap 总发行上限
     * @param _perMint 单次铸造固定数量
     * @param _factory 工厂合约地址
     */
    function initialize(
        string memory _symbol,
        uint256 _totalSupplyCap,
        uint256 _perMint,
        address _factory
    ) external initializer {
        require(_totalSupplyCap > 0, "MemeToken: totalSupplyCap must be > 0");
        require(_perMint > 0 && _perMint <= _totalSupplyCap, "MemeToken: invalid perMint");
        require(_factory != address(0), "MemeToken: invalid factory address");

        customSymbol = _symbol;
        customName = string(abi.encodePacked("Meme Inscription ", _symbol));
        totalSupplyCap = _totalSupplyCap;
        perMint = _perMint;
        factory = _factory;
    }

    function name() public view override returns (string memory) {
        return customName;
    }

    function symbol() public view override returns (string memory) {
        return customSymbol;
    }

    /**
     * @dev 铸造铭文代币，允许工厂合约或持有人直接调用
     * @param to 接收代币的地址
     */
    function mint(address to) external returns (bool) {
        require(msg.sender == factory || msg.sender == to, "MemeToken: unauthorized minter");
        require(currentMinted + perMint <= totalSupplyCap, "MemeToken: exceeds total supply cap");

        currentMinted += perMint;
        _mint(to, perMint);

        emit Mint(to, perMint, currentMinted);
        return true;
    }
}
