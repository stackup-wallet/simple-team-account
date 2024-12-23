# Simple Team Account

This repository is a fork of [eth-infinitism/account-abstraction](https://github.com/eth-infinitism/account-abstraction) for implementing a `SimpleAccount` variant for the [Stackup platform](https://stackup.fi/).

| Contract                                                                           | Address                                      |
| ---------------------------------------------------------------------------------- | -------------------------------------------- |
| [`SimpleTeamAccount.sol`](./contracts/samples/SimpleTeamAccount.sol)               | `0x40DA7aECC1e711a2F683642878692AAEFDDA0E32` |
| [`SimpleTeamAccountFactory.sol`](./contracts/samples/SimpleTeamAccountFactory.sol) | `0xF3150664c2a505690bbaA23a5d9bF863eeFC485B` |

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
