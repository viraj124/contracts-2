# Welcome to RENFT - First NFT Renting dApp

To install the dependencies, run

```bash
yarn
```

To compile the contracts run

```bash
truffle compile
```

Contract abis can be found in the build directory now

## Development

To mint your own Kovan NFT.

Ensure you have all the env variables defined from truffle-config.js. These are: MNEMONIC, INFURA and ETHERSCAN api

Now run

```bash
truffle console --network kovan
```

```bash
migrate --reset
```

and you will have minted 5 NFTs, e.g. this is [me](https://kovan.etherscan.io/tx/0x332ed73158c8c55547a4a5285938be9e76061b62b7aee5a6ab82ae2b48a6f84f)
