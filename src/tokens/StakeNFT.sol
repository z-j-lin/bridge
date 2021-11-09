// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.6;

import "../../lib/openzeppelin/token/ERC721/ERC721.sol";
import "../../lib/openzeppelin/token/ERC721/IERC721.sol";
import "../governance/Governance.sol";
import "../governance/GovernanceMaxLock.sol";
import "./utils/Admin.sol";
import "./utils/EthSafeTransfer.sol";
import "./utils/ERC20SafeTransfer.sol";
import "./utils/CircuitBreaker.sol";
import "./utils/MagicValue.sol";
import "./utils/AtomicCounter.sol";
import "./interfaces/ICBOpener.sol";
import "./interfaces/IERC721TransferMinimal.sol";
import "./interfaces/INFTStake.sol";

contract StakeNFT is
    ERC721,
    MagicValue,
    Admin,
    Governance,
    CircuitBreaker,
    AtomicCounter,
    EthSafeTransfer,
    ERC20SafeTransfer,
    GovernanceMaxLock,
    ICBOpener,
    INFTStake
{
    // _maxMintLock describes the maximum interval a Position may be locked
    // during a call to mintTo
    uint256 constant _maxMintLock = 1051200;
    // 10**18
    uint256 constant _accumulatorScaleFactor = 1000000000000000000;

    uint8 constant _enumEthState = 0;
    uint8 constant _enumTokenState = 1;
    uint8 constant _enumWithdrawLock = 2;
    uint8 constant _enumGovLock = 3;
    uint8 constant _enumMintLock = 4;

    // Position describes a staked position
    struct Position {
        // number of madToken
        uint224 shares;
        // block number after which the position may be burned.
        // prevents double spend of voting weight
        uint32 freeAfter;
        // block number after which the position may be collected or burned.
        uint32 withdrawFreeAfter;
        // the last value of the ethState accumulator this account performed a
        // withdraw at
        uint256 accumulatorEth;
        // the last value of the tokenState accumulator this account performed a
        // withdraw at
        uint256 accumulatorToken;
    }

    // Accumulator is a struct that allows values to be collected such that the
    // remainders of floor division may be cleaned up
    struct Accumulator {
        // accumulator is a sum of all changes always increasing
        uint256 accumulator;
        // slush stores division remainders until they may be distributed evenly
        uint256 slush;
    }

    // _shares stores total amount of MadToken staked in contract
    uint256 _shares;

    // _tokenState tracks distribution of MadToken that originate from slashing
    // events
    Accumulator _tokenState;

    // _ethState tracks the distribution of Eth that originate from the sale of
    // MadBytes
    Accumulator _ethState;

    // simple wrapper around MadToken ERC20 contract
    IERC20TransferMinimal _MadToken;

    // _positions tracks all staked positions based on tokenID
    mapping(uint256 => Position) _positions;

    // state to keep track of the amount of Eth deposited and collected from the
    // contract
    uint256 _reserveEth;

    // state to keep track of the amount of MadTokens deposited and collected
    // from the contract
    uint256 _reserveToken;

    constructor(
        IERC20TransferMinimal MadToken_,
        address admin_,
        address governance_
    ) ERC721("MNStake", "MNS") Governance(governance_) Admin(admin_) {
        _MadToken = MadToken_;
    }

    /// @dev tripCB opens the circuit breaker may only be called by _admin
    function tripCB() public override onlyAdmin {
        _tripCB();
    }

    /// @dev sets the governance contract, must only be called by _admin
    function setGovernance(address governance_) public override onlyAdmin {
        _setGovernance(governance_);
    }

    /// DO NOT CALL THIS METHOD UNLESS YOU ARE MAKING A DISTRIBUTION AS ALL VALUE
    /// WILL BE DISTRIBUTED TO STAKERS EVENLY. depositToken distributes MadToken
    /// to all stakers evenly should only be called during a slashing event. Any
    /// MadToken sent to this method in error will be lost. This function will
    /// fail if the circuit breaker is tripped. The magic_ parameter is intended
    /// to stop some one from successfully interacting with this method without
    /// first reading the source code and hopefully this comment
    function depositToken(uint8 magic_, uint256 amount_)
        public
        withCB
        checkMagic(magic_)
    {
        // collect tokens
        _safeTransferFromERC20(_MadToken, msg.sender, amount_);
        // update state
        Accumulator memory state = _loadAccumulator(_enumTokenState);
        _deposit(_shares, amount_, state);
        _storeAccumulator(_enumTokenState, state);
        _reserveToken += amount_;
    }

    /// DO NOT CALL THIS METHOD UNLESS YOU ARE MAKING A DISTRIBUTION ALL VALUE
    /// WILL BE DISTRIBUTED TO STAKERS EVENLY depositEth distributes Eth to all
    /// stakers evenly should only be called by MadBytes contract any Eth sent to
    /// this method in error will be lost this function will fail if the circuit
    /// breaker is tripped the magic_ parameter is intended to stop some one from
    /// successfully interacting with this method without first reading the
    /// source code and hopefully this comment
    function depositEth(uint8 magic_) public payable withCB checkMagic(magic_) {
        Accumulator memory state = _loadAccumulator(_enumEthState);
        _deposit(_shares, msg.value, state);
        _storeAccumulator(_enumEthState, state);
        _reserveEth += msg.value;
    }

    /// lockPosition is called by governance system when a governance
    /// vote is cast. This function will lock the specified Position for up to
    /// _maxGovernanceLock. This method may only be called by the governance
    /// contract. This function will fail if the circuit breaker is tripped
    function lockPosition(
        address caller_,
        uint256 tokenID_,
        uint256 lockDuration_
    ) public override withCB onlyGovernance returns (uint256 numberShares) {
        require(caller_ == ownerOf(tokenID_), "DNE");
                require(
            lockDuration_ <= _maxGovernanceLock,
            "LockDur>ALLOWED"
        );
        numberShares = _lockPosition(tokenID_, lockDuration_, _enumGovLock);
    }

    /// estimateExcessToken returns the amount of MadToken that is held in the
    /// name of this contract. The value returned is the value that would be
    /// returned by a call to skimExcessToken.
    function estimateExcessToken() public view returns (uint256 excess) {
        (, excess) = _estimateExcessToken();
        return excess;
    }

    /// estimateExcessEth returns the amount of Eth that is held in the name of
    /// this contract. The value returned is the value that would be returned by
    /// a call to skimExcessEth.
    function estimateExcessEth() public view returns (uint256 excess) {
        excess = _estimateExcessEth();
    }

    /// skimExcessEth will send to the address passed as to_ any amount of Eth
    /// held by this contract that is not tracked by the Accumulator system. This
    /// function allows the Admin role to refund any Eth sent to this contract in
    /// error by a user. This method can not return any funds sent to the contract
    /// via the depositEth method. This function should only be necessary if a
    /// user somehow manages to accidentally selfDestruct a contract with this
    /// contract as the recipient.
    function skimExcessEth(address to_)
        public
        onlyAdmin
        returns (uint256 excess)
    {
        excess = _estimateExcessEth();
        _safeTransferEth(to_, excess);
        return excess;
    }

    /// skimExcessToken will send to the address passed as to_ any amount of
    /// MadToken held by this contract that is not tracked by the Accumulator
    /// system. This function allows the Admin role to refund any MadToken sent to
    /// this contract in error by a user. This method can not return any funds
    /// sent to the contract via the depositToken method.
    function skimExcessToken(address to_)
        public
        onlyAdmin
        returns (uint256 excess)
    {
        IERC20TransferMinimal MadToken;
        (MadToken, excess) = _estimateExcessToken();
        _safeTransferERC20(MadToken, to_, excess);
        return excess;
    }

    /// gets the _accumulatorScaleFactor used to scale the ether and tokens
    /// deposited on this contract to reduce the integer division errors.
    function accumulatorScaleFactor() external pure returns (uint256) {
        return _accumulatorScaleFactor;
    }

    /// gets the total amount of MadToken staked in contract
    function getTotalShares() external view returns (uint256) {
        return _shares;
    }

    /// gets the total amount of Ether staked in contract
    function getTotalReserveEth() external view returns (uint256) {
        return _reserveEth;
    }

    /// gets the total amount of MadToken staked in contract
    function getTotalReserveMadToken() external view returns (uint256) {
        return _reserveToken;
    }

    /// gets the current value for the Eth accumulator
    function getEthAccumulator()
        external
        view
        returns (uint256 accumulator, uint256 slush)
    {
        Accumulator memory s = _loadAccumulator(_enumEthState);
        accumulator = s.accumulator;
        slush = s.slush;
    }

    /// gets the current value for the Token accumulator
    function getTokenAccumulator()
        external
        view
        returns (uint256 accumulator, uint256 slush)
    {   
        Accumulator memory s = _loadAccumulator(_enumTokenState);
        accumulator = s.accumulator;
        slush = s.slush;
    }

    /// gets the position struct given a tokenID. The tokenId must
    /// exist.
    function getPosition(uint256 tokenID_)
        external
        view
        returns (
            uint256 shares,
            uint256 freeAfter,
            uint256 withdrawFreeAfter,
            uint256 accumulatorEth,
            uint256 accumulatorToken
        )
    {
        require(_exists(tokenID_), "DNE");
        Position memory p = _loadPosition(tokenID_);
        shares = uint256(p.shares);
        freeAfter = uint256(p.freeAfter);
        withdrawFreeAfter = uint256(p.withdrawFreeAfter);
        accumulatorEth = p.accumulatorEth;
        accumulatorToken = p.accumulatorToken;
    }

     /// estimateEthCollection returns the amount of eth a tokenID may withdraw
    function estimateEthCollection(uint256 tokenID_)
        external
        view
        returns (uint256 payout)
    {
        require(_exists(tokenID_), "DNE");
        Position memory p = _loadPosition(tokenID_);
        Accumulator memory ethState = _loadAccumulator(_enumEthState);
        (, payout) = _collect(_shares, ethState, p, p.accumulatorEth);
        return payout;
    }

    /// estimateTokenCollection returns the amount of MadToken a tokenID may withdraw
    function estimateTokenCollection(uint256 tokenID_)
        external
        view
        returns (uint256 payout)
    {
        require(_exists(tokenID_), "DNE");
        Position memory p = _loadPosition(tokenID_);
        Accumulator memory tokenState = _loadAccumulator(_enumTokenState);
        (, payout) = _collect(_shares, tokenState, p, p.accumulatorToken);
        return payout;
    }

    /// mint allows a staking position to be opened. This function
    /// requires the caller to have performed an approve invocation against
    /// MadToken into this contract. This function will fail if the circuit
    /// breaker is tripped.
    function mint(uint256 amount_) public withCB returns (uint256 tokenID) {
        tokenID = _mintNFT(msg.sender, amount_);
    }

    /// mintTo allows a staking position to be opened in the name of an
    /// account other than the caller. This method also allows a lock to be
    /// placed on the position up to _maxMintLock . This function requires the
    /// caller to have performed an approve invocation against MadToken into
    /// this contract. This function will fail if the circuit breaker is
    /// tripped.
    function mintTo(address to_, uint256 amount_, uint256 lockDuration_) public withCB returns (uint256 tokenID) {
        require(lockDuration_ <= _maxMintLock, "LockDur>ALLOWED");
        tokenID = _mintNFT(to_, amount_);
        if (lockDuration_ > 0) {
            _lockPosition(tokenID, lockDuration_, _enumMintLock);
        }
        return tokenID;
    }

    /// burn exits a staking position such that all accumulated value is
    /// transferred to the owner on burn.
    function burn(uint256 tokenID_)
        public
        returns (uint256 payoutEth, uint256 payoutMadToken)
    {
        (payoutEth, payoutMadToken) = _burnNFT(msg.sender, msg.sender, tokenID_);
    }

    /// burnTo exits a staking position such that all accumulated value
    /// is transferred to a specified account on burn
    function burnTo(address to_, uint256 tokenID_)
        public
        returns (uint256 payoutEth, uint256 payoutMadToken)
    {
        (payoutEth, payoutMadToken) = _burnNFT(msg.sender, to_, tokenID_);
    }

    /// This function will lock withdraws on the specified Position for up to
    /// _maxGovernanceLock. This function will fail if the circuit breaker is tripped
    function lockWithdraw(uint256 tokenID_, uint256 lockDuration_)
        public
        withCB
        returns (uint256 numberShares)
    {
        require(msg.sender == ownerOf(tokenID_), "DNE");
        require(
            lockDuration_ <= _maxGovernanceLock,
            "LockDur>ALLOWED"
        );
        numberShares = _lockPosition(tokenID_, lockDuration_, _enumWithdrawLock);
    }

    /// collectEth returns all due Eth allocations to caller. The caller
    /// of this function must be the owner of the tokenID
    function collectEth(uint256 tokenID_) public returns (uint256 payout) {
        require(msg.sender == ownerOf(tokenID_), "!OWNER");
        Position memory p = _loadPosition(tokenID_);
        require(
            p.withdrawFreeAfter < block.number,
            "LOCKED"
        );

        // get values and update state
        payout = _collectEth(_shares, p);
        _reserveEth -= payout;
        _storePosition(tokenID_, p);
        
        // perform transfer and return amount paid out
        _safeTransferEth(msg.sender, payout);
        return payout;
    }

    /// collectToken returns all due MadToken allocations to caller. The
    /// caller of this function must be the owner of the tokenID
    function collectToken(uint256 tokenID_) public returns (uint256 payout) {
        require(msg.sender == ownerOf(tokenID_), "!OWNER");
        Position memory p = _loadPosition(tokenID_);
        require(p.withdrawFreeAfter < block.number, "LOCKED");

        // get values and update state
        payout = _collectToken(_shares, p);
        _reserveToken -= payout;
        _storePosition(tokenID_, p);

        // perform transfer and return amount paid out
        _safeTransferERC20(_MadToken, msg.sender, payout);
        return payout;
    }

    // _lockPosition prevents a position from being burned for duration_ number
    // of blocks by setting the freeAfter field on the Position struct returns
    // the number of shares in the locked Position so that governance vote
    // counting may be performed when setting a lock
    function _lockPosition(uint256 tokenID_, uint256 duration_, uint8 lockType_)
        internal
        returns (uint256 shares)
    {
        Position memory p = _loadPosition(tokenID_);
        uint256 freeDur = block.number + duration_;
        if (lockType_ == _enumWithdrawLock) {
            uint256 withdrawFreeAfter = freeDur > p.withdrawFreeAfter
            ? freeDur
            : p.withdrawFreeAfter;
            unchecked {
                p.withdrawFreeAfter = uint32(withdrawFreeAfter);
            }
        } else if (lockType_ == _enumGovLock || lockType_ == _enumMintLock ) {
            uint256 freeAfter = freeDur > p.freeAfter ? freeDur : p.freeAfter;
            unchecked {
                p.freeAfter = uint32(freeAfter);
            }
        } else {
            assert(false);
        }
        _storePosition(tokenID_, p);
        shares = p.shares;
    }

    // _mintNFT performs the mint operation and invokes the inherited _mint method
    function _mintNFT(address to_, uint256 amount_)
        internal
        returns (uint256 tokenID)
    {
        // this is to allow struct packing and is safe due to MadToken having a
        // total distribution of 220M
        require(amount_ <= type(uint224).max, "OVERFLOW AMOUNT");
        // transfer the number of tokens specified by amount_ into contract
        // from the callers account
        _safeTransferFromERC20(_MadToken, msg.sender, amount_);

        // get local copy of storage vars to save gas
        uint256 shares = _shares;
        Accumulator memory ethState = _loadAccumulator(_enumEthState);
        Accumulator memory tokenState = _loadAccumulator(_enumTokenState);

        // get new tokenID from counter
        tokenID = _increment();

        // update storage
        shares += amount_;
        _shares = shares;
        _storePosition(tokenID, Position(
            uint224(amount_),
            1,
            1,
            ethState.accumulator,
            tokenState.accumulator
        ));
        _reserveToken += amount_;
        // invoke inherited method and return
        _mint(to_, tokenID);
        return tokenID;
    }

    // _burn performs the burn operation and invokes the inherited _burn method
    function _burnNFT(
        address from_,
        address to_,
        uint256 tokenID_
    ) internal returns (uint256 payoutEth, uint256 payoutToken) {
        require(from_ == ownerOf(tokenID_), " not owner");

        // collect state
        Position memory p = _loadPosition(tokenID_);
        // enforce freeAfter to prevent burn during lock
        require(
            p.freeAfter < block.number && p.withdrawFreeAfter < block.number,
            "locked"
        );

        // get copy of storage to save gas
        uint256 shares = _shares;
        
        // calc Eth amounts due
        payoutEth = _collectEth(shares, p);

        // calc token amounts due
         payoutToken = _collectToken(shares, p);

        // add back to token payout the original stake position
        payoutToken += p.shares;

        // debit global shares counter and delete from mapping
        _shares -= p.shares;
        _reserveToken -= payoutToken;
        _reserveEth -= payoutEth;
        delete _positions[tokenID_];

        // invoke inherited burn method
        _burn(tokenID_);

        // transfer out all eth and tokens owed
        _safeTransferERC20(_MadToken, to_, payoutToken);
        _safeTransferEth(to_, payoutEth);
        return (payoutEth, payoutToken);
    }

    // _estimateExcessEth returns the amount of Eth that is held in the name of
    // this contract
    function _estimateExcessEth() internal view returns (uint256 excess) {
        uint256 reserve = _reserveEth;
        uint256 balance = address(this).balance;
        require(balance >= reserve, "balance>reserve");
        excess = balance - reserve;
    }

    // _estimateExcessToken returns the amount of MadToken that is held in the
    // name of this contract
    function _estimateExcessToken()
        internal
        view
        returns (IERC20TransferMinimal MadToken, uint256 excess)
    {
        uint256 reserve = _reserveToken;
        MadToken = _MadToken;
        uint256 balance = MadToken.balanceOf(address(this));
        require(balance >= reserve, "balance>reserve");
        excess = balance - reserve;
        return (MadToken, excess);
    }

    function _collectToken(uint256 shares_, Position memory p_)
        internal
        returns (uint256 payout)
    {
        uint256 acc;
        Accumulator memory state = _loadAccumulator(_enumTokenState);
        (acc, payout) = _collect(
            shares_,
            state,
            p_,
            p_.accumulatorToken
        );
        p_.accumulatorToken = acc;
        _storeAccumulator(_enumTokenState, state);
        return payout;
    }

    // _collectEth performs call to _collect and updates state during a request
    // for an eth distribution
    function _collectEth(uint256 shares_, Position memory p_)
        internal
        returns (uint256 payout)
    {
        uint256 acc;
        Accumulator memory state = _loadAccumulator(_enumEthState);
        (acc, payout) = _collect(
            shares_,
            state,
            p_,
            p_.accumulatorEth
        );
        p_.accumulatorEth = acc;
        _storeAccumulator(_enumEthState, state);
        return payout;
    }

    // _collect performs calculations necessary to determine any distributions
    // due to an account such that it may be used for both token and eth
    // distributions this prevents the need to keep redundant logic
    function _collect(uint256 shares_, Accumulator memory state_, Position memory p_, uint256 positionAccumulatorValue_)
        internal pure
        returns (
            uint256, uint256
        )
    {
        // determine number of accumulator steps this Position needs distributions from
        uint256 accumulatorDelta = 0;
        if (positionAccumulatorValue_ > state_.accumulator) {
            accumulatorDelta = type(uint168).max - positionAccumulatorValue_;
            accumulatorDelta += state_.accumulator;
            positionAccumulatorValue_ = accumulatorDelta;
        } else {
            accumulatorDelta = state_.accumulator - positionAccumulatorValue_;
            // update accumulator value for calling method
            positionAccumulatorValue_ += accumulatorDelta;
        }
        // calculate payout based on shares held in position
        uint256 payout = accumulatorDelta * p_.shares;
        // if there are no shares other than this position, flush the slush fund
        // into the payout and update the in memory state object
        if (shares_ == p_.shares) {
            payout += state_.slush;
            state_.slush = 0;
        }

        uint256 payoutReminder = payout;
        // reduce payout by scale factor
        payout /= _accumulatorScaleFactor;
        // Computing and saving the numeric error from the floor division in the
        // slush.
        payoutReminder -= payout * _accumulatorScaleFactor;
        state_.slush += payoutReminder;

        return (positionAccumulatorValue_, payout);
    }

    // _deposit allows an Accumulator to be updated with new value if there are
    // no currently staked positions, all value is stored in the slush
    function _deposit(uint256 shares_, uint256 delta_, Accumulator memory state_) internal pure {
        
        state_.slush += (delta_ * _accumulatorScaleFactor);
        if (shares_ > 0) {
            uint256 deltaAccumulator = state_.slush / shares_;
            state_.slush -= deltaAccumulator * shares_;
            state_.accumulator += deltaAccumulator;
            // avoiding accumulator_ overflow.
            if (state_.accumulator > type(uint168).max) {
                // The maximum allowed value for the accumulator is 2**168-1.
                // This hard limit was set to not overflow the operation
                // `accumulator * shares` that happens later in the code.
                state_.accumulator = state_.accumulator % type(uint168).max;
            }
        }
        // Slush should be never be above 2**167 to protect against overflow in
        // the later code.
        require(state_.slush < 2**167, "slushOVERFLOW");
    }
    
    function _loadPosition(uint256 tokenID_)internal view returns(Position memory) {
            return _positions[tokenID_];
    }

    function _storePosition(uint256 tokenID_, Position memory p_) internal {
            _positions[tokenID_] = p_;
    }

    function _loadAccumulator(uint8 ethA) internal view returns(Accumulator memory a) {
        if (ethA == _enumEthState) {
            return _ethState;
        }
        if (ethA == _enumTokenState) {
            return _tokenState;
        }
        assert(false);
    }

    function _storeAccumulator(uint8 ethA, Accumulator memory a_) internal {
        if (ethA == _enumEthState) {
            _ethState = a_;
            return;
        } 
        if (ethA == _enumTokenState) {
            _tokenState = a_;
            return;
        }
        assert(false);
    }
}