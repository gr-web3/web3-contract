# web3-contract
web3 合约代码

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

---

## 第十七课 可升级合约部署地址 (Ethereum Sepolia 测试网)

| 合约类型 | 合约名称 / 描述 | 链上地址 | 区块链浏览器链接 |
| :--- | :--- | :--- | :--- |
| **NFT Proxy** | `MyNFTUpgradeable` 代理合约 | `0x5D9D99f78f171CD6FCbfA299027922694495F4c1` | [Etherscan 链接](https://sepolia.etherscan.io/address/0x5D9D99f78f171CD6FCbfA299027922694495F4c1) |
| **NFT Impl** | `MyNFTUpgradeable` 逻辑实现合约 | `0xC2d19cE6914E0486852488FF519c3689Edb52614` | [Etherscan 链接](https://sepolia.etherscan.io/address/0xC2d19cE6914E0486852488FF519c3689Edb52614) |
| **Market Proxy** | `NFTMarket` UUPS 代理合约 | `0xD41a8283a9cB44e68772a0AcC4a911689cAba020` | [Etherscan 链接](https://sepolia.etherscan.io/address/0xD41a8283a9cB44e68772a0AcC4a911689cAba020) |
| **Market V1 Impl** | `NFTMarketV1` 第一版逻辑合约 | `0xfbDBeF4f3B132A74Ba0C28a0d27F3660ece4711f` | [Etherscan 链接](https://sepolia.etherscan.io/address/0xfbDBeF4f3B132A74Ba0C28a0d27F3660ece4711f) |
| **Market V2 Impl** | `NFTMarketV2` 第二版逻辑合约（EIP-712签名上架） | `0xaF6E3e6eE766620b16338122db9Bd89007a4C894` | [Etherscan 链接](https://sepolia.etherscan.io/address/0xaF6E3e6eE766620b16338122db9Bd89007a4C894) |
