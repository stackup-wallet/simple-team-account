import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const provider = ethers.provider;
  const from = await provider.getSigner().getAddress();

  await hre.deployments.deploy("SimpleTeamAccountFactory", {
    from,
    args: [process.env.ENTRY_POINT_ADDRESS],
    gasLimit: 6e6,
    log: true,
    deterministicDeployment: true,
  });
};

export default func;
