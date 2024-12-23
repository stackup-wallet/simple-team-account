import { config as dotenvConfig } from "dotenv";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import { HardhatUserConfig, task } from "hardhat/config";
import type { NetworkUserConfig } from "hardhat/types";
import "hardhat-deploy";
import "@nomicfoundation/hardhat-verify";
import "solidity-coverage";
import { resolve } from "path";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

task("deploy", "Deploy contracts").addFlag(
  "simpleAccountFactory",
  "deploy sample factory (by default, enabled only on localhost)"
);

// Ensure that we have all the environment variables we need.
const ep: string | undefined = process.env.ENTRY_POINT_ADDRESS;
const mnemonic: string | undefined = process.env.MNEMONIC;
if (!ep || !mnemonic) {
  throw new Error("Please set your MNEMONIC in a .env file");
}

function getChainConfig(jsonRpcUrl?: string): NetworkUserConfig {
  if (!jsonRpcUrl) {
    throw new Error("Please set your RPC urls in a .env file");
  }

  if (process.env.DEPLOY_WITH_LOCAL_RPC != "") {
    return {
      accounts: "remote",
      url: process.env.DEPLOY_WITH_LOCAL_RPC,
    };
  }
  return {
    accounts: {
      mnemonic,
    },
    url: jsonRpcUrl,
  };
}

const optimizedCompilerSettings = {
  version: "0.8.23",
  settings: {
    optimizer: { enabled: true, runs: 1000000 },
    viaIR: true,
  },
};

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.23",
        settings: {
          optimizer: { enabled: true, runs: 1000000 },
        },
      },
    ],
    overrides: {
      "contracts/core/EntryPoint.sol": optimizedCompilerSettings,
      "contracts/samples/SimpleAccount.sol": optimizedCompilerSettings,
    },
  },
  networks: {
    dev: { url: "http://localhost:8545" },
    // github action starts localgeth service, for gas calculations
    localgeth: { url: "http://localgeth:8545" },

    mainnet: getChainConfig(process.env.ETHEREUM_RPC),
    sepolia: getChainConfig(process.env.SEPOLIA_RPC),
  },
  mocha: {
    timeout: 10000,
  },
  // @ts-ignore
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
    },
  },
  sourcify: {
    enabled: true,
  },
};

// coverage chokes on the "compilers" settings
if (process.env.COVERAGE != null) {
  // @ts-ignore
  config.solidity = config.solidity.compilers[0];
}

export default config;
