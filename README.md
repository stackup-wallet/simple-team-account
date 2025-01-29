# Simple Team Account

This repository is a fork of [eth-infinitism/account-abstraction](https://github.com/eth-infinitism/account-abstraction) for implementing a `SimpleAccount` variant for the [Stackup platform](https://stackup.fi/).

| Contract                                                                           | Address                                      |
| ---------------------------------------------------------------------------------- | -------------------------------------------- |
| [`SimpleTeamAccount.sol`](./contracts/samples/SimpleTeamAccount.sol)               | `0x83e759DF2550d0cB1714F095D208aD7225FDa56a` |
| [`SimpleTeamAccountFactory.sol`](./contracts/samples/SimpleTeamAccountFactory.sol) | `0x080ACC9E07deb1E9Ef351281a01079b0f717BCBF` |

## Usage

Before being able to run any command, you need to create a `.env` file and set your environment variables. You can
follow the example in `.env.example`.

Install dependencies:

```shell
yarn install
```

Compile contracts:

```shell
yarn compile
```

Deploy `SimpleTeamAccountFactory`:

```shell
yarn run deploy
```

Deploy `P256 verifier` (if not yet deployed):

```shell
yarn hardhat deploy_p256_verifier
```
