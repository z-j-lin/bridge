// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.15;

import "ds-test/test.sol";

import "./Constants.sol";
import "./ETHDKG.sol";
import "./ETHDKGCompletion.sol";
import "./ETHDKGGroupAccusation.sol";
import "./ETHDKGSubmitMPK.sol";
import "./Registry.sol";
import "./Validators.sol";
import "./ValidatorsSnapshot.sol";

contract ETHDKGTest is Constants, DSTest {

    ETHDKG private ethdkg;
    ETHDKGCompletion private ethdkgCompletion;
    ETHDKGGroupAccusation private ethdkgGroupAccusation;
    ETHDKGSubmitMPK private ethdkgSubmitMPK;
    Registry private registry;
    Validators private validators;
    ValidatorsSnapshot private validatorsSnapshot;

    function setUp() public {
        Registry reg = new Registry();
        validators = new Validators(10, reg);
        validatorsSnapshot = new ValidatorsSnapshot();
        ethdkg = new ETHDKG(reg);
        ethdkgCompletion = new ETHDKGCompletion();
        ethdkgGroupAccusation = new ETHDKGGroupAccusation();
        ethdkgSubmitMPK = new ETHDKGSubmitMPK();

        reg.register(CRYPTO_CONTRACT, address(new Crypto()));
        reg.register(ETHDKG_COMPLETION_CONTRACT, address(ethdkgCompletion));
        reg.register(ETHDKG_GROUPACCUSATION_CONTRACT, address(ethdkgGroupAccusation));
        reg.register(ETHDKG_SUBMITMPK_CONTRACT, address(ethdkgSubmitMPK));
        reg.register(VALIDATORS_CONTRACT, address(validators));
        reg.register(VALIDATORS_SNAPSHOT_CONTRACT, address(validatorsSnapshot));

        ethdkg.reloadRegistry();
    }

    function sliceUint(bytes memory bs, uint start) internal pure returns (uint256) {
        require(bs.length >= start + 32, "slicing out of range");
        uint256 x;
        assembly { // solium-disable-line
            x := mload(add(bs, add(0x20, start)))
        }
        return x;
    }

    // Group_Accusation_GPKj(uint256[] memory invArray, uint256[] memory honestIndices, uint256[] memory dishonestIndices) public view
    function wrappedGroup_Accusation(
        uint256[] memory invArray,
        uint256[] memory honestIndices,
        uint256[] memory dishonestIndices
    )
    internal returns (bool, bytes memory) {
        bool ok;
        bytes memory res;

        (ok, res) = address(ethdkg).call( // solium-disable-line
            abi.encodeWithSignature("Group_Accusation_GPKj(uint256[], uint256[], uint256[])", invArray, honestIndices, dishonestIndices));

        return (ok, res);
    }

    // submit_master_public_key(uint256[4] memory _master_public_key) public view
    function wrappedSubmitMPK(
        uint256[4] memory _master_public_key
    )
    internal returns (bool, bytes memory) {
        bool ok;
        bytes memory res;

        (ok, res) = address(ethdkg).call( // solium-disable-line
            abi.encodeWithSignature("submit_master_public_key(uint256[4])", _master_public_key));

        return (ok, res);
    }

    function getInverses(uint8 quantity) internal pure returns (uint256[] memory _inverses) {
        require(quantity <= 4, "Only have 4 inverses to select from.");
        uint256[4] memory inverses = [
            0x1,
            0x183227397098d014dc2822db40c0ac2e9419f4243cdcb848a1f0fac9f8000001,
            0x2042def740cbc01bd03583cf0100e59370229adafbd0f5b62d414e62a0000001,
            0x244b3ad628e5381f4a3c3448e1210245de26ee365b4b146cf2e9782ef4000001
        ];

        _inverses = new uint256[](quantity);
        for (uint8 idx; idx < quantity; idx++) {
            _inverses[idx] = inverses[idx];
        }
    }

    function testGroupAccusationGPKj() public {
        // Group_Accusation_GPKj(uint256[] memory invArray, uint256[] memory honestIndices, uint256[] memory dishonestIndices) public view
        uint256[] memory inverses = getInverses(3);
        uint256[] memory invalidHonestIndices = new uint256[](3);
        invalidHonestIndices[0] = 2;
        invalidHonestIndices[1] = 3;
        invalidHonestIndices[2] = 4;

        uint256[] memory dishonestIndices = new uint256[](1);
        dishonestIndices[0] = 1;

        bool ok;
        bytes memory results;
        (ok, results) = wrappedGroup_Accusation(inverses, invalidHonestIndices, dishonestIndices);

        assertTrue(!ok);
    }

    function testSubmitMPKNegative() public {
        uint256[4] memory mpk;

        bool ok;
        bytes memory results;
        
        (ok, results) = wrappedSubmitMPK(mpk);

        assertTrue(!ok);
    }

    function testSuccessful_Completion() public {
        // ethdkg.Successful_Completion();
    }

}