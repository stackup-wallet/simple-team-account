# Simple Team Account

This repository is a fork of [eth-infinitism/account-abstraction](https://github.com/eth-infinitism/account-abstraction) for implementing a `SimpleAccount` variant for the [Stackup platform](https://stackup.fi/).

| Contract                                                                           | Address                                      |
| ---------------------------------------------------------------------------------- | -------------------------------------------- |
| [`SimpleTeamAccount.sol`](./contracts/samples/SimpleTeamAccount.sol)               | `0xd496F5C1be29b31D6748507E5E428e38f0F71798` |
| [`SimpleTeamAccountFactory.sol`](./contracts/samples/SimpleTeamAccountFactory.sol) | `0xa9F58948f7ce0f603091537e1f484825f97321b5` |

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
