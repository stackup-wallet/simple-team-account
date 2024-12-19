// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./SimpleTeamAccount.sol";

/**
 * The factory contract for SimpleTeamAccount.
 *
 * SimpleTeamAccountFactory is originally forked from SimpleAccountFactory.
 */
contract SimpleTeamAccountFactory {
    SimpleTeamAccount public immutable accountImplementation;

    constructor(IEntryPoint _entryPoint) {
        accountImplementation = new SimpleTeamAccount(_entryPoint);
    }

    /**
     * create an account, and return its address.
     * returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation
     */
    function createAccount(Signer calldata signer, address verifier, uint256 salt)
        public
        returns (SimpleTeamAccount ret)
    {
        address addr = getAddress(signer, verifier, salt);
        uint256 codeSize = addr.code.length;
        if (codeSize > 0) {
            return SimpleTeamAccount(payable(addr));
        }
        ret = SimpleTeamAccount(
            payable(
                new ERC1967Proxy{salt: bytes32(salt)}(
                    address(accountImplementation), abi.encodeCall(SimpleTeamAccount.initialize, (signer, verifier))
                )
            )
        );
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(Signer calldata signer, address verifier, uint256 salt) public view returns (address) {
        return Create2.computeAddress(
            bytes32(salt),
            keccak256(
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(
                        address(accountImplementation), abi.encodeCall(SimpleTeamAccount.initialize, (signer, verifier))
                    )
                )
            )
        );
    }
}
