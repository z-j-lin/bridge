// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/INFTStake.sol";
import "../interfaces/IERC20Transferable.sol";
import "../interfaces/IERC721Transferable.sol";
import "../utils/EthSafeTransfer.sol";
import "../utils/ERC20SafeTransfer.sol";

contract ValidatorPool is Initializable, UUPSUpgradeable, EthSafeTransfer, ERC20SafeTransfer {
    // _maxMintLock describes the maximum interval a Position may be locked
    // during a call to mintTo
    uint256 constant _maxMintLock = 1051200;

    // Minimum amount to stake
    uint256 internal _minimumStake;


    INFTStake internal _stakeNFT;
    INFTStake internal _validatorsNFT;
    IERC20Transferable internal _madToken;

    enum State {
        Pending,
        Active
    }
    struct ValidatorData {
        uint128 index;
        uint128 tokenID;
        State state;
    }

    // todo: lock writes to this variable once an ETHDKG has started
    address[] internal _validators;
    mapping(address=>ValidatorData) internal _validatorsData;

    function initialize(
        INFTStake stakeNFT_,
        INFTStake validatorNFT_,
        IERC20Transferable madToken_
    ) public initializer {
        //20000*10**18 MadWei = 20k MadTokens
        _minimumStake = 200000*1000000000000000000;
        _stakeNFT = stakeNFT_;
        _madToken = madToken_;
        _validatorsNFT = validatorNFT_;
        __UUPSUpgradeable_init();
    }

    // todo: onlyAdmin or onlyGovernance?
    function _authorizeUpgrade(address newImplementation) internal onlyAdmin override {

    }

    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), "Validators: requires admin privileges");
        _;
    }

    /// @dev tripCB opens the circuit breaker may only be called by _admin
    function setMinimumStake(uint256 minimumStake_) public onlyAdmin {
        _minimumStake = minimumStake_;
    }

    function getValidatorsCount() public view returns(uint256) {
        return _validators.length;
    }

    function isValidator(address participant) public view returns(bool) {
        return _validators[_validatorsData[participant].index] == participant;
    }

    function _swapStakeNFTForValidatorNFT(address to_, uint256 stakerTokenID_)
        internal
        returns (
            uint256 validatorTokenID,
            uint256 payoutEth,
            uint256 payoutToken
        )
    {
        require(_validatorsData[msg.sender].tokenID == 0, "The user already have a ValidatorNFT Position!");
        (uint256 stakeShares,,,,) = _stakeNFT.getPosition(stakerTokenID_);
        require(
            stakeShares >= _minimumStake,
            "ValidatorStakeNFT: Error, the Stake position doesn't have enough founds!"
        );
        IERC721Transferable(address(_stakeNFT)).safeTransferFrom(msg.sender, address(this), stakerTokenID_);
    }

    // function finishSwap() public {
    //     (payoutEth, payoutToken) = _stakeNFT.burn(stakerTokenID_);

    //     //Subtracting the shares from StakeNFT profit. The shares will be used to mint the new ValidatorPosition
    //     payoutToken -= stakeShares;

    //     // We should approve the StakeNFT to transferFrom the tokens of this contract
    //     _madToken.approve(address(_validatorsNFT), stakeShares);
    //     validatorTokenID = _validatorsNFT.mint(stakeShares);

    //     _validators.push(to_);
    //     _validatorsData[msg.sender] = ValidatorData(uint128(_validators.length-1), uint128(validatorTokenID));

    //     // transfer back any profit that was available for the stakeNFT position by the
    //     // time that we burned it
    //     _safeTransferERC20(_madToken, to_, payoutToken);
    //     _safeTransferEth(to_, payoutEth);
    //     return (validatorTokenID, payoutEth, payoutToken);
    //     //todo:emit an event when someone becomes a validator
    // }

    function collectProfits() external returns (uint256 payoutEth, uint256 payoutToken)
    {
        uint256 validatorTokenID = _validatorsData[msg.sender].tokenID;
        require(validatorTokenID > 0, "Error, no position was found for address!");
        payoutEth = _validatorsNFT.collectEthTo(msg.sender, validatorTokenID);
        payoutToken = _validatorsNFT.collectTokenTo(msg.sender, validatorTokenID);
    }

    // _burn performs the burn operation and invokes the inherited _burn method
    function _swapValidatorNFTForStakeNFT(
        address to_,
        uint256 validatorTokenID_
    )
        internal
        returns (
            uint256 stakeTokenID,
            uint256 payoutEth,
            uint256 payoutToken
        )
    {
        (uint256 minerShares,,,,) = _validatorsNFT.getPosition(validatorTokenID_);

        //IERC721Transferable(address(_validatorsNFT)).safeTransferFrom(msg.sender, address(this), validatorTokenID_);
        (payoutEth, payoutToken) = _validatorsNFT.burn(validatorTokenID_);
        payoutToken -= minerShares;

        // We should approve the StakeNFT to transferFrom the tokens of this contract
        _madToken.approve(address(_stakeNFT), minerShares);
        // Notice that we are not summing the shared to the payoutToken because
        // we will use this amount to mint a new NFT in the StakeNFt contract.
        stakeTokenID = _stakeNFT.mint(minerShares);

        // Move last address in 'validators' to the spot this validator is relinquishing
        uint256 lastIndex = _validators.length - 1;
        address lastAddress = _validators[lastIndex];

        // ps.validatorIndex[lastAddress] = index;
        // ps.validators[index] = ps.validators[lastIndex];
        // ps.validators.pop();

        _safeTransferERC20(_madToken, to_, payoutToken);
        _safeTransferEth(to_, payoutEth);
        return (stakeTokenID, payoutEth, payoutToken);
    }

    function claimStakeNFTPosition() public returns(uint256 stakeTokenID) {
        //require(time has passed)
        //get stakeNFT in this contract using msg.sender
    }

    // todo: replace modifier
    function majorSlash(address participant) public onlyAdmin {

    }

    // todo: replace modifier
    function minorSlash(address participant) public onlyAdmin {

    }

}
