# Simple Team Account

This repository is a fork of [eth-infinitism/account-abstraction](https://github.com/eth-infinitism/account-abstraction) for implementing a `SimpleAccount` variant for the [Stackup platform](https://stackup.fi/).

| Contract                                                                           | Address                                      |
| ---------------------------------------------------------------------------------- | -------------------------------------------- |
| [`SimpleTeamAccount.sol`](./contracts/samples/SimpleTeamAccount.sol)               | `0x9F19C6a27CEA6b40C031954A01A710714fD750Bc` |
| [`SimpleTeamAccountFactory.sol`](./contracts/samples/SimpleTeamAccountFactory.sol) | `0xC04aB952581658671D1f6f1Daa8738a0725F0425` |

## Usage

Before being able to run any command, you need to create a `.env` file and set your environment variables. You can
follow the example in `.env.example`.

Install dependencies:

```shell
yarn install
forge install
```

Compile contracts:

```shell
yarn compile
```

Deploy `SimpleTeamAccountFactory`:

```shell
yarn run deploy
```
