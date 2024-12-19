// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../core/BaseAccount.sol";
import "../core/Helpers.sol";
import "./callback/TokenCallbackHandler.sol";

import {LibString} from "solady/utils/LibString.sol";
import {WebAuthn} from "webauthn-sol/WebAuthn.sol";
import {Base64} from "openzeppelin-contracts/contracts/utils/Base64.sol";

enum Access {
    Outsider,
    Member,
    Owner
}

struct Signer {
    uint256 p256x;
    uint256 p256y;
    address ecdsa;
    Access level;
}

/**
 * Minimal team account.
 *  This is a simple account for teams that require a shared treasury.
 *  It is lightweight by design and does not support modules or onchain permissions.
 *  Any access control logic should be computed and signed offchain.
 *
 *  This implementation supports 4 signature types:
 *      1. Owner with WebAuthn
 *      2. Member with WebAuthn and verified with ECDSA
 *      3. Owner with ECDSA
 *      4. Member with ECDSA and verified with ECDSA
 *
 * SimpleTeamAccount is originally forked from SimpleAccount.
 */
contract SimpleTeamAccount is BaseAccount, TokenCallbackHandler, Initializable {
    using LibString for string;

    address public verifier;
    mapping(bytes32 id => Signer s) internal signers;

    IEntryPoint private immutable _entryPoint;

    event SimpleTeamAccountInitialized(IEntryPoint indexed entryPoint);
    event SimpleTeamAccountSignerSet(bytes32 signerId);
    event SimpleTeamAccountSignerDeleted(bytes32 signerId);
    event SimpleTeamAccountVerifierSet(address verifier);

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function getSigner(bytes32 signerId) public view returns (Signer memory) {
        return signers[signerId];
    }

    function getSignerId(Signer calldata signer) public pure returns (bytes32) {
        return keccak256(abi.encode(signer.p256x, signer.p256y, signer.ecdsa));
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
        _disableInitializers();
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     * @param dest destination address to call
     * @param value the value to pass in this call
     * @param func the calldata to pass in this call
     */
    function execute(address dest, uint256 value, bytes calldata func) external {
        _requireFromEntryPoint();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     * @param dest an array of destination addresses
     * @param value an array of values to pass to each call. can be zero-length for no-value calls
     * @param func an array of calldata to pass to each call
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) external {
        _requireFromEntryPoint();
        require(dest.length == func.length && (value.length == 0 || value.length == func.length), "wrong array lengths");
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    /**
     * Sets a new signer or overrides an existing one on the account.
     * @param signer The Signer tuple to save.
     */
    function setSigner(Signer calldata signer) external {
        _requireFromEntryPoint();
        _setSigner(signer);
    }

    /**
     * Deletes a signer from the account.
     * @param signerId The id of the signer to remove.
     */
    function deleteSigner(bytes32 signerId) external {
        _requireFromEntryPoint();
        delete signers[signerId];
        emit SimpleTeamAccountSignerDeleted(signerId);
    }

    /**
     * Sets a new verifier for approving member level transactions.
     * @param aVerifier The address for the new verifying entity.
     */
    function setVerifier(address aVerifier) external {
        _requireFromEntryPoint();
        _setVerifier(aVerifier);
    }

    /**
     * @dev The _entryPoint member is immutable, to reduce gas consumption.
     * @param initSigner the owner (signer) of this account
     * @param initVerifier An authorized entity for approving member level transactions.
     */
    function initialize(Signer calldata initSigner, address initVerifier) public virtual initializer {
        _initialize(initSigner, initVerifier);
    }

    function _initialize(Signer calldata initSigner, address initVerifier) internal virtual {
        _setSigner(initSigner);
        _setVerifier(initVerifier);
        emit SimpleTeamAccountInitialized(_entryPoint);
    }

    function _setSigner(Signer calldata signer) internal {
        require(
            (signer.p256x != 0 && signer.p256y != 0 && signer.ecdsa == address(0))
                || (signer.p256x == 0 && signer.p256y == 0 && signer.ecdsa != address(0)),
            "account: must be one of p256 or ecdsa"
        );

        bytes32 id = getSignerId(signer);
        signers[id] = signer;
        emit SimpleTeamAccountSignerSet(id);
    }

    function _setVerifier(address aVerifier) internal {
        verifier = aVerifier;
        emit SimpleTeamAccountVerifierSet(aVerifier);
    }

    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        Signer memory signer = signers[bytes32(userOp.signature[:32])];
        require(signer.level != Access.Outsider, "account: unauthorized");

        // Assuming WebAuthn signature.
        bytes calldata data = userOp.signature[32:];
        if (signer.ecdsa == address(0)) {
            if (signer.level == Access.Owner) {
                return _validateWebAuthnOwner(signer, userOpHash, data);
            }
            return _validateWebAuthnMember(signer, userOpHash, data);
        }

        // Assuming ECDSA signature.
        if (signer.level == Access.Owner) {
            return _validateECDSAOwner(signer, userOpHash, data);
        }
        return _validateECDSAMember(signer, userOpHash, data);
    }

    function _validateWebAuthnOwner(Signer memory signer, bytes32 userOpHash, bytes calldata data)
        internal
        view
        returns (uint256 validationData)
    {
        bytes memory challenge = abi.encode(userOpHash);
        WebAuthn.WebAuthnAuth memory auth = _webAuthn(challenge, data);
        return WebAuthn.verify(challenge, true, auth, signer.p256x, signer.p256y)
            ? SIG_VALIDATION_SUCCESS
            : SIG_VALIDATION_FAILED;
    }

    function _validateECDSAOwner(Signer memory signer, bytes32 userOpHash, bytes calldata data)
        internal
        pure
        returns (uint256 validationData)
    {
        return signer.ecdsa == ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(userOpHash), data)
            ? SIG_VALIDATION_SUCCESS
            : SIG_VALIDATION_FAILED;
    }

    function _validateWebAuthnMember(Signer memory signer, bytes32 userOpHash, bytes calldata data)
        internal
        view
        returns (uint256 validationData)
    {
        bytes memory challenge = abi.encode(userOpHash);
        WebAuthn.WebAuthnAuth memory auth = _webAuthn(challenge, data[65:]);

        return verifier == ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(userOpHash), data[:65])
            && WebAuthn.verify(challenge, true, auth, signer.p256x, signer.p256y)
            ? SIG_VALIDATION_SUCCESS
            : SIG_VALIDATION_FAILED;
    }

    function _validateECDSAMember(Signer memory signer, bytes32 userOpHash, bytes calldata data)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 hash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        return verifier == ECDSA.recover(hash, data[:65]) && signer.ecdsa == ECDSA.recover(hash, data[65:])
            ? SIG_VALIDATION_SUCCESS
            : SIG_VALIDATION_FAILED;
    }

    function _webAuthn(bytes memory challenge, bytes memory data)
        internal
        pure
        returns (WebAuthn.WebAuthnAuth memory auth)
    {
        (
            bytes memory authenticatorData,
            string memory clientDataJSONPre,
            string memory clientDataJSONPost,
            uint256 challengeIndex,
            uint256 typeIndex,
            uint256 r,
            uint256 s
        ) = abi.decode(data, (bytes, string, string, uint256, uint256, uint256, uint256));
        auth = WebAuthn.WebAuthnAuth({
            authenticatorData: authenticatorData,
            clientDataJSON: clientDataJSONPre.concat(Base64.encodeURL(challenge)).concat(clientDataJSONPost),
            challengeIndex: challengeIndex,
            typeIndex: typeIndex,
            r: r,
            s: s
        });
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}
