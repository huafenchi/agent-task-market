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

## 🚀 V2 Upgradeable Deployment (Latest)

**AgentTaskMarket V2 with UUPS Proxy - Fully Upgradeable!**

| Item | Value |
|------|-------|
| **Proxy Address** | `0x4ca4e46cb601307dc3dcd3697c3936059e7ea3b2` |
| **Implementation** | `0xF47F31118C978A264faaA929e9b68315573E179d` |
| **Payment Token** | $CLAWNCH (`0xa1F72459dfA10BAD200Ac160eCd78C6b77a747be`) |
| **Fee Rate** | 2% (configurable, max 10%) |
| **Fee Recipient** | `0xC639bBbe01DCE7DC352120c315e82E49C71B62A2` |
| **Network** | Base Mainnet (Chain ID: 8453) |
| **Version** | 2.0.0 |

### Key Features
- ✅ UUPS Proxy (upgradeable)
- ✅ 2% platform fee
- ✅ Owner controls (fee rate, recipient, pause)
- ✅ Reputation system
- ✅ Dispute resolution
- ✅ Emergency pause

### Upgrade Instructions
To upgrade to a new version:
```bash
# Deploy new implementation
forge build
forge create contracts/NewImplementation.sol:NewImpl --rpc-url https://mainnet.base.org

# Upgrade via proxy admin
cast send <PROXY_ADMIN_ADDRESS> "upgradeTo(address)" <NEW_IMPLEMENTATION> --private-key <PRIVATE_KEY>
```

### Links
- [Proxy on Basescan](https://basescan.org/address/0x4ca4e46cb601307dc3dcd3697c3936059e7ea3b2)
- [Implementation on Basescan](https://basescan.org/address/0xF47F31118C978A264faaA929e9b68315573E179d)
