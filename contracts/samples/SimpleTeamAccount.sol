// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable reason-string */

import "../core/BaseAccount.sol";
import "../core/Helpers.sol";
import "./callback/TokenCallbackHandler.sol";

import {Initializable} from "solady/src/utils/Initializable.sol";
import {ECDSA} from "solady/src/utils/ECDSA.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {WebAuthn} from "solady/src/utils/WebAuthn.sol";
import {Base64} from "solady/src/utils/Base64.sol";
import {EfficientHashLib} from "solady/src/utils/EfficientHashLib.sol";

struct Call {
    address target;
    uint256 value;
    bytes data;
}

enum Access {
    Outsider,
    Member,
    Owner
}

/**
 * Data structure for storing the public credentials for a signer.
 * If WebAuthn, pubKeySlt1 and pubKeySlt2 is the P256 x and y coordinates.
 * If ECDSA, pubKeySlt1 is the padded address and pubKeySlt2 is 0.
 */
struct Signer {
    bytes32 pubKeySlt1;
    bytes32 pubKeySlt2;
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
 * The execute and executeBatch functions are modified from Solady.
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

    modifier onlySelf() {
        _onlySelf();
        _;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    function getSigner(bytes32 signerId) public view returns (Signer memory) {
        return signers[signerId];
    }

    function getSignerId(bytes32 pubKeySlt1, bytes32 pubKeySlt2) public pure returns (bytes32) {
        return EfficientHashLib.hash(pubKeySlt1, pubKeySlt2);
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}

    constructor(IEntryPoint anEntryPoint) {
        _entryPoint = anEntryPoint;
        _disableInitializers();
    }

    function _onlySelf() internal view {
        // directly from the account itself (which gets redirected through execute())
        require(msg.sender == address(this), "only self");
    }

    /**
     * execute a transaction
     * @param target destination address to call
     * @param value the value to pass in this call
     * @param data the calldata to pass in this call
     */
    function execute(address target, uint256 value, bytes calldata data) external returns (bytes memory result) {
        _requireFromEntryPoint();
        assembly {
            result := mload(0x40)
            calldatacopy(result, data.offset, data.length)
            if iszero(call(gas(), target, value, result, data.length, codesize(), 0x00)) {
                // Bubble up the revert if the call reverts.
                returndatacopy(result, 0x00, returndatasize())
                revert(result, returndatasize())
            }
            mstore(result, returndatasize()) // Store the length.
            let o := add(result, 0x20)
            returndatacopy(o, 0x00, returndatasize()) // Copy the returndata.
            mstore(0x40, add(o, returndatasize())) // Allocate the memory.
        }
    }

    /**
     * execute a sequence of transactions
     * @param calls an array of calls to make from this account
     */
    function executeBatch(Call[] calldata calls) external returns (bytes[] memory results) {
        _requireFromEntryPoint();
        assembly {
            results := mload(0x40)
            mstore(results, calls.length)
            let r := add(0x20, results)
            let m := add(r, shl(5, calls.length))
            calldatacopy(r, calls.offset, shl(5, calls.length))
            for { let end := m } iszero(eq(r, end)) { r := add(r, 0x20) } {
                let e := add(calls.offset, mload(r))
                let o := add(e, calldataload(add(e, 0x40)))
                calldatacopy(m, add(o, 0x20), calldataload(o))
                // forgefmt: disable-next-item
                if iszero(call(gas(), calldataload(e), calldataload(add(e, 0x20)),
                    m, calldataload(o), codesize(), 0x00)) {
                    // Bubble up the revert if the call reverts.
                    returndatacopy(m, 0x00, returndatasize())
                    revert(m, returndatasize())
                }
                mstore(r, m) // Append `m` into `results`.
                mstore(m, returndatasize()) // Store the length,
                let p := add(m, 0x20)
                returndatacopy(p, 0x00, returndatasize()) // and copy the returndata.
                m := add(p, returndatasize()) // Advance `m`.
            }
            mstore(0x40, m) // Allocate the memory.
        }
    }

    /**
     * Sets a new WebAuthn signer or overrides an existing one on the account.
     * @param x The P256 x coordinate of the public key.
     * @param y The P256 y coordinate of the public key.
     * @param level The access level for the signer.
     */
    function setWebAuthnSigner(bytes32 x, bytes32 y, Access level) external onlySelf {
        Signer memory s = Signer(x, y, level);
        _setSigner(s);
    }

    /**
     * Sets a new ECDSA signer or overrides an existing one on the account.
     * @param ecdsa The signer address.
     * @param level The access level for the signer.
     */
    function setECDSASigner(address ecdsa, Access level) external onlySelf {
        Signer memory s = Signer(bytes32(uint256(uint160(ecdsa))), 0, level);
        _setSigner(s);
    }

    /**
     * Deletes a signer from the account.
     * @param signerId The id of the signer to remove.
     */
    function deleteSigner(bytes32 signerId) external onlySelf {
        delete signers[signerId];
        emit SimpleTeamAccountSignerDeleted(signerId);
    }

    /**
     * Sets a new verifier for approving member level transactions.
     * @param aVerifier The address for the new verifying entity.
     */
    function setVerifier(address aVerifier) external onlySelf {
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

    function _setSigner(Signer memory signer) internal {
        bytes32 id = EfficientHashLib.hash(signer.pubKeySlt1, signer.pubKeySlt2);
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
        if (signer.pubKeySlt2 != 0) {
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
        return WebAuthn.verify(challenge, true, auth, signer.pubKeySlt1, signer.pubKeySlt2)
            ? SIG_VALIDATION_SUCCESS
            : SIG_VALIDATION_FAILED;
    }

    function _validateECDSAOwner(Signer memory signer, bytes32 userOpHash, bytes calldata data)
        internal
        view
        returns (uint256 validationData)
    {
        return address(uint160(uint256(signer.pubKeySlt1)))
            == ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), data)
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

        bool verifierOk = verifier == ECDSA.recover(ECDSA.toEthSignedMessageHash(userOpHash), data[:65]);
        bool signerOk = WebAuthn.verify(challenge, true, auth, signer.pubKeySlt1, signer.pubKeySlt2);
        return verifierOk && signerOk ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
    }

    function _validateECDSAMember(Signer memory signer, bytes32 userOpHash, bytes calldata data)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 hash = ECDSA.toEthSignedMessageHash(userOpHash);
        bool verifierOk = verifier == ECDSA.recover(hash, data[:65]);
        bool signerOk = address(uint160(uint256(signer.pubKeySlt1))) == ECDSA.recover(hash, data[65:]);
        return verifierOk && signerOk ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
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
            bytes32 r,
            bytes32 s
        ) = abi.decode(data, (bytes, string, string, uint256, uint256, bytes32, bytes32));
        auth = WebAuthn.WebAuthnAuth({
            authenticatorData: authenticatorData,
            clientDataJSON: clientDataJSONPre.concat(Base64.encode(challenge, true, true)).concat(clientDataJSONPost),
            challengeIndex: challengeIndex,
            typeIndex: typeIndex,
            r: r,
            s: s
        });
    }
}
