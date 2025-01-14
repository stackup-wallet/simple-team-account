# Simple Team Account

This repository is a fork of [eth-infinitism/account-abstraction](https://github.com/eth-infinitism/account-abstraction) for implementing a `SimpleAccount` variant for the [Stackup platform](https://stackup.fi/).

| Contract                                                                           | Address                                      |
| ---------------------------------------------------------------------------------- | -------------------------------------------- |
| [`SimpleTeamAccount.sol`](./contracts/samples/SimpleTeamAccount.sol)               | `0x5eC82BC221333Eb3e21BE9F52dCb61Fb524AF0A4` |
| [`SimpleTeamAccountFactory.sol`](./contracts/samples/SimpleTeamAccountFactory.sol) | `0x6D0A9F4A178c7Bbe4A14892A4Ec572da61c66A50` |

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
