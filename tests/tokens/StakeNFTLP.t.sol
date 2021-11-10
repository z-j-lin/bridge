// SPDX-License-Identifier: MIT-open-group
pragma solidity ^0.8.0;

import "lib/ds-test/test.sol";

import "src/tokens/StakeNFTLP.sol";
import "lib/openzeppelin/token/ERC20/ERC20.sol";
import "lib/openzeppelin/token/ERC721/IERC721Receiver.sol";

uint256 constant ONE_MADTOKEN = 10**18;

contract MadTokenMock is ERC20 {
    constructor(address to_) ERC20("MadToken", "MAD") {
        _mint(to_, 220000000 * ONE_MADTOKEN);
    }
}

abstract contract BaseMock {
    StakeNFTLP public _StakeNFTLP;
    MadTokenMock public madToken;

    function setTokens(MadTokenMock madToken_, StakeNFTLP StakeNFTLP_) public {
        _StakeNFTLP = StakeNFTLP_;
        madToken = madToken_;
    }

    receive() external payable virtual {}

    function mint(uint256 amount_) public returns (uint256) {
        return _StakeNFTLP.mint(amount_);
    }

    function mintTo(
        address to_,
        uint256 amount_
    ) public returns (uint256) {
        return _StakeNFTLP.mintTo(to_, amount_);
    }

    function burn(uint256 tokenID) public returns (uint256, uint256) {
        return _StakeNFTLP.burn(tokenID);
    }

    function burnTo(address to_, uint256 tokenID)
        public
        returns (uint256, uint256)
    {
        return _StakeNFTLP.burnTo(to_, tokenID);
    }

    function approve(address who, uint256 amount_) public returns (bool) {
        return madToken.approve(who, amount_);
    }

    function depositEth(uint256 amount_) public {
        _StakeNFTLP.depositEth{value: amount_}(42);
    }

    function collectEth(uint256 tokenID_) public returns (uint256 payout) {
        return _StakeNFTLP.collectEth(tokenID_);
    }

    function approveNFT(address to, uint256 tokenID_) public {
        return _StakeNFTLP.approve(to, tokenID_);
    }

    function setApprovalForAll(address to, bool approve_) public {
        return _StakeNFTLP.setApprovalForAll(to, approve_);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenID_
    ) public {
        return _StakeNFTLP.transferFrom(from, to, tokenID_);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenID_,
        bytes calldata data
    ) public {
        return _StakeNFTLP.safeTransferFrom(from, to, tokenID_, data);
    }
}

contract AdminAccount is BaseMock {
    constructor() {}

    function tripCB() public {
        _StakeNFTLP.tripCB();
    }

    function skimExcessEth(address to_) public returns (uint256 excess) {
        return _StakeNFTLP.skimExcessEth(to_);
    }

    function skimExcessToken(address to_) public returns (uint256 excess) {
        return _StakeNFTLP.skimExcessToken(to_);
    }

}

contract UserAccount is BaseMock {
    constructor() {}
}

contract ReentrantLoopEthCollectorAccount is BaseMock {
    uint256 tokenID;

    constructor() {}

    receive() external payable virtual override {
        collectEth(tokenID);
    }

    function setTokenID(uint256 tokenID_) public {
        tokenID = tokenID_;
    }
}

contract ReentrantFiniteEthCollectorAccount is BaseMock {
    uint256 tokenID;
    uint256 public _count = 0;

    constructor() {}

    receive() external payable virtual override {
        if (_count < 2) {
            _count++;
            collectEth(1);
        } else {
            return;
        }
    }

    function setTokenID(uint256 tokenID_) public {
        tokenID = tokenID_;
    }
}

contract ReentrantLoopBurnAccount is BaseMock {
    uint256 tokenID;

    constructor() {}

    receive() external payable virtual override {
        burn(tokenID);
    }

    function setTokenID(uint256 tokenID_) public {
        tokenID = tokenID_;
    }
}

contract ReentrantFiniteBurnAccount is BaseMock {
    uint256 tokenID;
    uint256 public _count = 0;

    constructor() {}

    receive() external payable virtual override {
        if (_count < 2) {
            _count++;
            burn(tokenID);
        } else {
            return;
        }
    }

    function setTokenID(uint256 tokenID_) public {
        tokenID = tokenID_;
    }
}

contract ERC721ReceiverAccount is BaseMock, IERC721Receiver {
    constructor() {}

    // receive() external payable virtual override {

    // }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}

contract ReentrantLoopBurnERC721ReceiverAccount is BaseMock, IERC721Receiver {
    uint256 _tokenId;

    constructor() {}

    receive() external payable virtual override {
        _StakeNFTLP.burn(_tokenId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        _tokenId = tokenId;
        _StakeNFTLP.burn(tokenId);
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}

contract ReentrantFiniteBurnERC721ReceiverAccount is BaseMock, IERC721Receiver {
    uint256 _tokenId;
    uint256 _count = 0;

    constructor() {}

    receive() external payable virtual override {
        _StakeNFTLP.burn(_tokenId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        if (_count < 2) {
            _count++;
            _tokenId = tokenId;
            _StakeNFTLP.burn(tokenId);
        }

        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}

contract ReentrantLoopCollectEthERC721ReceiverAccount is
    BaseMock,
    IERC721Receiver
{
    uint256 _tokenId;

    constructor() {}

    receive() external payable virtual override {
        _StakeNFTLP.collectEth(_tokenId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        _tokenId = tokenId;
        _StakeNFTLP.collectEth(tokenId);
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }
}

contract AdminAccountReEntrant is BaseMock {
    uint256 public _count = 0;

    constructor() {}

    function skimExcessEth(address to_) public returns (uint256 excess) {
        return _StakeNFTLP.skimExcessEth(to_);
    }

    receive() external payable virtual override {
        if (_count < 2) {
            _count++;
            _StakeNFTLP.skimExcessEth(address(this));
        } else {
            return;
        }
    }
}

contract StakeNFTLPHugeAccumulator is StakeNFTLP {
    uint256 public constant offsetToOverflow = 1_000000000000000000;

    constructor(
        IERC20TransferMinimal MadToken_,
        address admin_
    ) StakeNFTLP(MadToken_, admin_) {
        _ethState.accumulator = uint256(type(uint168).max - offsetToOverflow);
    }

    function getOffsetToOverflow() public pure returns (uint256) {
        return offsetToOverflow;
    }
}

contract StakeNFTLPTest is DSTest {
    function getFixtureData()
        internal
        returns (
            StakeNFTLP StakeNFTLP_,
            MadTokenMock madToken,
            AdminAccount admin
        )
    {
        admin = new AdminAccount();
        madToken = new MadTokenMock(address(this));
        StakeNFTLP_ = new StakeNFTLP(
            IERC20TransferMinimal(address(madToken)),
            address(admin)
        );

        admin.setTokens(madToken, StakeNFTLP_);
    }

    function getFixtureDataWithHugeAccumulator()
        internal
        returns (
            StakeNFTLPHugeAccumulator StakeNFTLP_,
            MadTokenMock madToken,
            AdminAccount admin
        )
    {
        admin = new AdminAccount();
        madToken = new MadTokenMock(address(this));
        StakeNFTLP_ = new StakeNFTLPHugeAccumulator(
            IERC20TransferMinimal(address(madToken)),
            address(admin)
        );

        admin.setTokens(madToken, StakeNFTLP_);
    }

    function getFixtureDataAdminReEntrant()
        internal
        returns (
            StakeNFTLP StakeNFTLP_,
            MadTokenMock madToken,
            AdminAccountReEntrant admin
        )
    {
        admin = new AdminAccountReEntrant();
        madToken = new MadTokenMock(address(this));
        StakeNFTLP_ = new StakeNFTLP(
            IERC20TransferMinimal(address(madToken)),
            address(admin)
        );

        admin.setTokens(madToken, StakeNFTLP_);
    }

    function newUserAccount(MadTokenMock madToken, StakeNFTLP StakeNFTLP_)
        private
        returns (UserAccount acct)
    {
        acct = new UserAccount();
        acct.setTokens(madToken, StakeNFTLP_);
    }

    function setBlockNumber(uint256 bn) internal returns (bool) {
        // https://github.com/dapphub/dapptools/tree/master/src/hevm#cheat-codes
        address externalContract = address(
            0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
        );
        (
            bool success, /*bytes memory returnedData*/

        ) = externalContract.call(abi.encodeWithSignature("roll(uint256)", bn));

        return success;
    }

    function getCurrentPosition(StakeNFTLP StakeNFTLP_, uint256 tokenID)
        internal
        view
        returns (StakeNFTLP.Position memory actual)
    {
        (uint256 shares, uint256 accumulatorEth) = StakeNFTLP_.getPosition(tokenID);
        actual =  StakeNFTLP.Position(uint224(shares),accumulatorEth);
    }

    function assertPosition(
        StakeNFTLP.Position memory p,
        StakeNFTLP.Position memory expected
    ) internal {
        assertEq(p.shares, expected.shares);
        assertEq(p.accumulatorEth, expected.accumulatorEth);
    }

    function assertEthAccumulator(
        StakeNFTLP StakeNFTLP_,
        uint256 expectedAccumulator,
        uint256 expectedSlush
    ) internal {
        (uint256 acc, uint256 slush) = StakeNFTLP_.getEthAccumulator();
        assertEq(acc, expectedAccumulator);
        assertEq(slush, expectedSlush);
    }

    function assertReserveAndExcessZero(
        StakeNFTLP StakeNFTLP_,
        uint256 reserveAmountEth
    ) internal {
        assertEq(StakeNFTLP_.getTotalReserveEth(), reserveAmountEth);
        assertEq(StakeNFTLP_.estimateExcessEth(), 0);
    }

    function assertReserveAndExcess(
        StakeNFTLP StakeNFTLP_,
        uint256 reserveAmountEth,
        uint256 excessEth
    ) internal {
        assertEq(StakeNFTLP_.getTotalReserveEth(), reserveAmountEth);
        assertEq(StakeNFTLP_.estimateExcessEth(), excessEth);
    }

    function testFail_noAdminTripCB() public {
        (StakeNFTLP StakeNFTLP_, , ) = getFixtureData();
        StakeNFTLP_.tripCB();
    }

    function testFail_noAdminSkimExcessEth() public {
        (StakeNFTLP StakeNFTLP_, , ) = getFixtureData();
        StakeNFTLP_.skimExcessEth(address(0));
    }

    function testFail_tripCBDepositEth() public {
        (StakeNFTLP StakeNFTLP_, , AdminAccount admin) = getFixtureData();
        admin.tripCB(); // open CB
        StakeNFTLP_.depositEth(42);
    }

    function testFail_tripCBMint() public {
        (StakeNFTLP StakeNFTLP_, , AdminAccount admin) = getFixtureData();
        admin.tripCB(); // open CB
        StakeNFTLP_.mint(100);
    }

    function testFail_tripCBMintTo() public {
        (StakeNFTLP StakeNFTLP_, , AdminAccount admin) = getFixtureData();
        admin.tripCB(); // open CB
        StakeNFTLP_.mintTo(address(0x0), 100);
    }

    function testFail_getPositionThatDoesNotExist() public {
        (StakeNFTLP StakeNFTLP_, , ) = getFixtureData();
        getCurrentPosition(StakeNFTLP_,  4);
    }

    function testBasicERC721() public {
        (StakeNFTLP StakeNFTLP_, , ) = getFixtureData();
        assertEq(StakeNFTLP_.name(), "MNStake");
        assertEq(StakeNFTLP_.symbol(), "MNS");
    }

    function testDeposit() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        StakeNFTLP_.depositEth{value: 10 ether}(42);
        assertEq(address(StakeNFTLP_).balance, 10 ether);
        assertReserveAndExcessZero(StakeNFTLP_, 10 ether);
    }

    function testFail_DepositEthWithWrongMagicNumber() public {
        (StakeNFTLP StakeNFTLP_, , ) = getFixtureData();
        StakeNFTLP_.depositEth{value: 10 ether}(41);
    }

    function testMint() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();

        madToken.approve(address(StakeNFTLP_), 1000);
        uint256 tokenID = StakeNFTLP_.mint(1000);
        assertPosition(
            getCurrentPosition(StakeNFTLP_, tokenID),
            StakeNFTLP.Position(1000, 0)
            );
        assertEq(StakeNFTLP_.balanceOf(address(this)), 1);
        assertEq(StakeNFTLP_.ownerOf(tokenID), address(this));
        assertReserveAndExcessZero(StakeNFTLP_, 0 ether);
    }

    function testFail_MintWithoutApproval() public {
        (StakeNFTLP StakeNFTLP_, , ) = getFixtureData();
        StakeNFTLP_.mint(1000);
    }

    function testFail_MintMoreMadTokensThanPossible() public {
        (StakeNFTLP StakeNFTLP_, , ) = getFixtureData();
        StakeNFTLP_.mint(2**32);
    }

    function testFail_MintToMoreMadTokensThanPossible() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user = newUserAccount(madToken, StakeNFTLP_);
        StakeNFTLP_.mintTo(address(user), 2**32);
    }

    function testFail_MintToWithoutApproval() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user = newUserAccount(madToken, StakeNFTLP_);
        StakeNFTLP_.mintTo(address(user), 100);
    }
    // mint+burn
    function test_BurningRightAfterMinting() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 1000);
        user.approve(address(StakeNFTLP_), 1000);

        uint256 tokenID = user.mint(1000);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID),
            StakeNFTLP.Position(1000, 0)
        );

        assertEq(madToken.balanceOf(address(user)), 0);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 1000);

        (uint256 ethPayout, uint256 tokenPayout) = user.burn(tokenID);
        assertEq(ethPayout, 0);
        assertEq(tokenPayout, 1000);
    }

    function testMintAndBurn() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 1000);
        user.approve(address(StakeNFTLP_), 1000);

        uint256 tokenID = user.mint(1000);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID),
            StakeNFTLP.Position(1000, 0)
        );
        assertEq(StakeNFTLP_.balanceOf(address(user)), 1);
        assertEq(StakeNFTLP_.ownerOf(tokenID), address(user));
        assertEq(madToken.balanceOf(address(user)), 0);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 1000);
        assertReserveAndExcessZero(StakeNFTLP_, 0);

        setBlockNumber(block.number + 2);

        (uint256 payoutEth, uint256 payoutToken) = user.burn(tokenID);
        assertEq(payoutEth, 0);
        assertEq(payoutToken, 1000);
        assertReserveAndExcessZero(StakeNFTLP_, 0 ether);
        assertEq(madToken.balanceOf(address(user)), 1000);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 0);
    }

    // mint+burnTo
    function testMintAndBurnTo() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 1000);
        user.approve(address(StakeNFTLP_), 1000);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 0);

        uint256 tokenID = user.mint(1000);
        StakeNFTLP.Position memory p = getCurrentPosition(StakeNFTLP_,  tokenID);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID),
            StakeNFTLP.Position(1000, 0)
        );
        assertEq(StakeNFTLP_.balanceOf(address(user)), 1);
        assertEq(madToken.balanceOf(address(user)), 0);
        assertEq(madToken.balanceOf(address(user2)), 0);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 1000);
        assertReserveAndExcessZero(StakeNFTLP_, 0 ether);

        setBlockNumber(block.number + 2);

        (uint256 payoutEth, uint256 payoutToken) = user.burnTo(address(user2),tokenID);
        assertEq(payoutEth, 0);
        assertEq(payoutToken, 1000);
        assertEq(madToken.balanceOf(address(user)), 0);
        assertEq(madToken.balanceOf(address(user2)), 1000);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 0);
        assertReserveAndExcessZero(StakeNFTLP_, 0 ether);
    }

    // mintTo + burn
    function testMintToAndBurn() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 1000);
        user.approve(address(StakeNFTLP_), 1000);

        uint256 tokenID = user.mintTo(address(user2), 1000);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID),
            StakeNFTLP.Position(1000, 0)
        );

        assertEq(madToken.balanceOf(address(user)), 0);
        assertEq(madToken.balanceOf(address(user2)), 0);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 1000);
        assertReserveAndExcessZero(StakeNFTLP_, 0 ether);

        setBlockNumber(block.number + 2);

        (uint256 payoutEth, uint256 payoutToken) = user2.burn(tokenID);
        assertEq(payoutEth, 0);
        assertEq(payoutToken, 1000);

        assertEq(madToken.balanceOf(address(user)), 0);
        assertEq(madToken.balanceOf(address(user2)), 1000);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 0);
        assertReserveAndExcessZero(StakeNFTLP_, 0 ether);
    }

    // mintTo + burnTo
    function testMintToAndBurnTo() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user3 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 1000);
        user.approve(address(StakeNFTLP_), 1000);

        uint256 tokenID = user.mintTo(address(user2), 1000);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID),
            StakeNFTLP.Position(1000, 0)
        );

        assertEq(madToken.balanceOf(address(user)), 0);
        assertEq(madToken.balanceOf(address(user2)), 0);
        assertEq(madToken.balanceOf(address(user3)), 0);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 1000);
        assertReserveAndExcessZero(StakeNFTLP_, 0);

        setBlockNumber(block.number + 2);

        (uint256 payoutEth, uint256 payoutToken) = user2.burnTo(address(user3), tokenID);
        assertEq(payoutEth, 0);
        assertEq(payoutToken, 1000);
        assertEq(madToken.balanceOf(address(user)), 0);
        assertEq(madToken.balanceOf(address(user2)), 0);
        assertEq(madToken.balanceOf(address(user3)), 1000);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 0);
        assertReserveAndExcessZero(StakeNFTLP_, 0);
    }

    function test_SharesInvariance() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        madToken.transfer(address(donator), 10000000 * ONE_MADTOKEN);
        donator.approve(address(StakeNFTLP_), 10000000 * ONE_MADTOKEN);
        payable(address(donator)).transfer(100000 ether);

        UserAccount[50] memory users;
        uint256 shares = 0;
        // Minting a lot
        for (uint256 i = 0; i < 50; i++) {
            users[i] = newUserAccount(madToken, StakeNFTLP_);
            madToken.transfer(
                address(users[i]),
                (1_000_000 * ONE_MADTOKEN) + i
            );
            users[i].approve(address(StakeNFTLP_), (1_000_000 * ONE_MADTOKEN) + i);
            users[i].mint((1_000_000 * ONE_MADTOKEN) + i);
            shares += (1_000_000 * ONE_MADTOKEN) + i;
        }
        assertEq(shares, StakeNFTLP_.getTotalShares());
        assertReserveAndExcessZero(StakeNFTLP_, 0);
        setBlockNumber(block.number + 2);
        // burning some of the NFTs
        for (uint256 i = 0; i < 50; i++) {
            if (i % 3 == 0) {
                users[i].burn(i + 1);
                shares -= (1_000_000 * ONE_MADTOKEN) + i;
            }
        }
        assertReserveAndExcessZero(StakeNFTLP_, 0);
        assertEq(shares, StakeNFTLP_.getTotalShares());
    }

    function test_SlushFlushIntoAccumulator() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user3 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100);
        madToken.transfer(address(user2), 100);
        madToken.transfer(address(user3), 100);
        madToken.transfer(address(donator), 100000 * ONE_MADTOKEN);

        user1.approve(address(StakeNFTLP_), 100);
        user2.approve(address(StakeNFTLP_), 100);
        user3.approve(address(StakeNFTLP_), 100);
        donator.approve(address(StakeNFTLP_), 100000 * ONE_MADTOKEN);
        payable(address(donator)).transfer(1000 ether);

        uint256 sharesPerUser = 10;
        uint256 tokenID1 = user1.mint(sharesPerUser);
        uint256 tokenID2 = user2.mint(sharesPerUser);
        uint256 tokenID3 = user3.mint(sharesPerUser);
       assertReserveAndExcessZero(StakeNFTLP_, 0);

        setBlockNumber(block.number + 2);

        uint256 credits = 0;
        uint256 debits = 0;
        for (uint256 i = 0; i < 2; i++) {
            donator.depositEth(1000);
            credits += 1000;
            uint256 payout = user1.collectEth(tokenID1);
            assertEq(payout, 333);
            debits += payout;
            uint256 payout2 = user2.collectEth(tokenID2);
            assertEq(payout2, 333);
            debits += payout2;
            uint256 payout3 = user3.collectEth(tokenID3);
            assertEq(payout3, 333);
            debits += payout3;
        }
        {
            emit log_named_uint("Balance ETH: ", address(StakeNFTLP_).balance);
            (, uint256 slush) = StakeNFTLP_.getEthAccumulator();
            assertEq(slush, (credits - debits) * 10**18);
           assertReserveAndExcessZero(StakeNFTLP_, credits - debits);
        }
        {
            donator.depositEth(2000);
            credits += 2000;
           assertReserveAndExcessZero(StakeNFTLP_, credits-debits);
            uint256 payout = user1.collectEth(tokenID1);
            assertEq(payout, 667);
            debits += payout;
            uint256 payout2 = user2.collectEth(tokenID2);
            assertEq(payout2, 667);
            debits += payout2;
            uint256 payout3 = user3.collectEth(tokenID3);
            assertEq(payout3, 667);
            debits += payout3;
            emit log_named_uint(
                "Balance ETH After: ",
                address(StakeNFTLP_).balance
            );
            (, uint256 slush) = StakeNFTLP_.getEthAccumulator();
            assertEq(slush, (credits - debits) * 10**18);
            assertEq(slush, 1 ether);
        }
        {
           assertReserveAndExcessZero(StakeNFTLP_, credits - debits);
        }
    }

    function test_SlushInvariance() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken, ) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user3 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 3333);
        madToken.transfer(address(user2), 111);
        madToken.transfer(address(user3), 7);
        madToken.transfer(address(donator), 100000 * ONE_MADTOKEN);

        user1.approve(address(StakeNFTLP_), 3333);
        user2.approve(address(StakeNFTLP_), 111);
        user3.approve(address(StakeNFTLP_), 7);
        donator.approve(address(StakeNFTLP_), 100000 * ONE_MADTOKEN);
        payable(address(donator)).transfer(10000000000 ether);

        uint256 tokenID1 = user1.mint(3333);
        uint256 tokenID2 = user2.mint(111);
        uint256 tokenID3 = user3.mint(7);
        //assertReserveAndExcessZero(StakeNFTLP_, 3333 + 111 + 7, 0 ether);
        assertReserveAndExcessZero(StakeNFTLP_, 0 ether);
        setBlockNumber(block.number + 2);

        uint256 credits = 0;
        uint256 debits = 0;
        {
            for (uint256 i = 0; i < 37; i++) {
                donator.depositEth(7 ether);
                credits += 7 ether;
                uint256 payout = user1.collectEth(tokenID1);
                debits += payout;
                uint256 payout2 = user2.collectEth(tokenID2);
                debits += payout2;
                uint256 payout3 = user3.collectEth(tokenID3);
                debits += payout3;
            }
            {
                emit log_named_uint("Balance ETH: ", address(StakeNFTLP_).balance);
                (, uint256 slush) = StakeNFTLP_.getEthAccumulator();
                // As long as all the users have withdrawal their dividends this should hold true
                assertEq(slush, (credits - debits) * 10**18);
                // assertReserveAndExcessZero(StakeNFTLP_, 3333 + 111 + 7, (credits - debits));
                assertReserveAndExcessZero(StakeNFTLP_, (credits - debits));
            }
            {
                donator.depositEth(credits);
                credits += credits;
                uint256 payout = user1.collectEth(tokenID1);
                debits += payout;
                uint256 payout2 = user2.collectEth(tokenID2);
                debits += payout2;
                uint256 payout3 = user3.collectEth(tokenID3);
                debits += payout3;
                (, uint256 slush) = StakeNFTLP_.getEthAccumulator();
                assertEq(slush, (credits - debits) * 10**18);
                // assertReserveAndExcessZero(StakeNFTLP_, 3333 + 111 + 7, (credits - debits));
                assertReserveAndExcessZero(StakeNFTLP_, (credits - debits));
            }
        }
        {
            donator.depositEth(13457811);
            credits += 13457811;
            uint256 payout = user1.collectEth(tokenID1);
            debits += payout;
            uint256 payout2 = user2.collectEth(tokenID2);
            debits += payout2;
            uint256 payout3 = user3.collectEth(tokenID3);
            debits += payout3;
            (, uint256 slush) = StakeNFTLP_.getEthAccumulator();
            assertEq(slush, (credits - debits) * 10**18);
            // assertReserveAndExcessZero(StakeNFTLP_, 3333 + 111 + 7, (credits - debits));
            assertReserveAndExcessZero(StakeNFTLP_, (credits - debits));
        }
        {
            donator.depositEth(1381_209873167895423687);
            credits += 1381_209873167895423687;
            uint256 payout = user1.collectEth(tokenID1);
            debits += payout;
            uint256 payout2 = user2.collectEth(tokenID2);
            debits += payout2;
            uint256 payout3 = user3.collectEth(tokenID3);
            debits += payout3;
            (, uint256 slush) = StakeNFTLP_.getEthAccumulator();
            // As long as all the users have withdrawal their dividends this should hold true
            assertEq(slush, (credits - debits) * 10**18);
            // assertReserveAndExcessZero(StakeNFTLP_, 3333 + 111 + 7, (credits - debits));
            assertReserveAndExcessZero(StakeNFTLP_, (credits - debits));
        }
        {
            donator.depositEth(1111_209873167895423687);
            credits += 1111_209873167895423687;
            uint256 payout = user1.collectEth(tokenID1);
            debits += payout;
            uint256 payout2 = user2.collectEth(tokenID2);
            debits += payout2;
            donator.depositEth(11_209873167895423687);
            credits += 11_209873167895423687;
            payout = user1.collectEth(tokenID1);
            debits += payout;
            donator.depositEth(156_209873167895423687);
            credits += 156_209873167895423687;
            payout = user1.collectEth(tokenID1);
            debits += payout;
            payout2 = user2.collectEth(tokenID2);
            debits += payout2;
            uint256 payout3 = user3.collectEth(tokenID3);
            debits += payout3;
            (, uint256 slush) = StakeNFTLP_.getEthAccumulator();
            // As long as all the users have withdrawal their dividends this should hold true
            assertEq(slush, (credits - debits) * 10**18);
            assertReserveAndExcessZero(StakeNFTLP_, (credits - debits));
            // assertReserveAndExcessZero(StakeNFTLP_, 3333 + 111 + 7, (credits - debits));
        }
    }

    function testBurnWithTripCB() public {
        (
            StakeNFTLP StakeNFTLP_,
            MadTokenMock madToken,
            AdminAccount admin

        ) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 1000 * ONE_MADTOKEN);
        madToken.transfer(address(user2), 1000 * ONE_MADTOKEN);
        madToken.transfer(address(donator), 1_000_000 * ONE_MADTOKEN);
        user1.approve(address(StakeNFTLP_), 1000 * ONE_MADTOKEN);
        user2.approve(address(StakeNFTLP_), 1000 * ONE_MADTOKEN);
        donator.approve(address(StakeNFTLP_), 20000 * ONE_MADTOKEN);
        payable(address(donator)).transfer(2000 ether);

        // minting
        uint256 tokenID1 = user1.mint(1000 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID1),
            StakeNFTLP.Position(uint224(1000 * ONE_MADTOKEN), 0)
        );
       assertReserveAndExcessZero(StakeNFTLP_,  0);
        uint256 tokenID2 = user2.mint(800 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID2),
            StakeNFTLP.Position(uint224(800 * ONE_MADTOKEN), 0)
        );
       assertReserveAndExcessZero(StakeNFTLP_,  0);

        // depositing to move the accumulators
        donator.depositEth(1800 ether);
       assertReserveAndExcessZero(StakeNFTLP_,  1800 ether);

        setBlockNumber(block.number + 2);
        // minting one more position to user 2
        uint256 tokenID3 = user2.mint(200 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID3),
            StakeNFTLP.Position(uint224(200 * ONE_MADTOKEN), 10**18)
        );
       assertReserveAndExcessZero(StakeNFTLP_, 1800 ether);
        donator.depositEth(200 ether);
       assertReserveAndExcessZero(StakeNFTLP_, 2000 ether);
        assertEq(madToken.balanceOf(address(user1)), 0);
        assertEq(madToken.balanceOf(address(user2)), 0);
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 1);
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 2);
        assertEq(address(user1).balance, 0 ether);
        assertEq(address(user2).balance, 0 ether);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 2000 * ONE_MADTOKEN);
        assertEq(address(StakeNFTLP_).balance, 2000 ether);

        setBlockNumber(block.number + 2);

        //e.g bug was found so we needed to trip the Circuit breaker
        admin.tripCB();
        {
        // Only burn (which uses both collect) should work now
        (uint256 payoutEth, uint256 payoutToken) = user1.burn(tokenID1);
        assertEq(payoutToken, 1000 * ONE_MADTOKEN);
        assertEq(payoutEth, 1100 ether);
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 0);
        assertEq(address(user1).balance, 1100 ether);
        assertEq(madToken.balanceOf(address(user1)), 1000 * ONE_MADTOKEN);
       assertReserveAndExcessZero(StakeNFTLP_, 900 ether);
        }
        {
        (uint256 payoutEth, uint256 payoutToken) = user2.burn(tokenID2);
        assertEq(payoutToken, 800 * ONE_MADTOKEN);
        assertEq(payoutEth, 880 ether);
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 1);
        assertEq(address(user2).balance, 880 ether);
        assertEq(madToken.balanceOf(address(user2)), 800 * ONE_MADTOKEN);
       assertReserveAndExcessZero(StakeNFTLP_, 20 ether);
        }
        {
        (uint256 payoutEth, uint256 payoutToken) = user2.burn(tokenID3);
        assertEq(payoutToken, 200 * ONE_MADTOKEN);
        assertEq(payoutEth, 20 ether);
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 0);
        assertEq(address(user2).balance, 900 ether);
        assertEq(madToken.balanceOf(address(user2)), 1000 * ONE_MADTOKEN);

        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 0);
       assertReserveAndExcessZero(StakeNFTLP_, 0 ether);
        }
    }

    function test_MintCollectBurnALot() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        madToken.transfer(address(donator), 10000000 * ONE_MADTOKEN);
        donator.approve(address(StakeNFTLP_), 10000000 * ONE_MADTOKEN);
        payable(address(donator)).transfer(100000 ether);

        UserAccount[50] memory users;
        uint256[100] memory tokenIDs;
        uint256 j = 0;
        uint256 iterations = 21;
        uint256 reserveEth = 0;
        // Minting a lot
        for (uint256 i = 0; i < iterations; i++) {
            users[i] = newUserAccount(madToken, StakeNFTLP_);
            madToken.transfer(
                address(users[i]),
                (1_000_000 * ONE_MADTOKEN) + i
            );
            users[i].approve(address(StakeNFTLP_), (1_000_000 * ONE_MADTOKEN) + i);
            tokenIDs[j] = users[i].mint((500_000 * ONE_MADTOKEN) - i);
            tokenIDs[j + 1] = users[i].mint((500_000 * ONE_MADTOKEN) + i);
            j += 2;
        }
       assertReserveAndExcessZero(StakeNFTLP_, reserveEth);
        setBlockNumber(block.number + 2);
        j = 0;
        // depositing and collecting some
        for (uint256 i = 0; i < iterations; i++) {
            if (i % 3 == 0) {
                donator.depositEth(i * 1 ether);
                reserveEth += i * 1 ether;
                reserveEth -= users[i].collectEth(tokenIDs[j]);
                reserveEth -= users[i].collectEth(tokenIDs[j + 1]);
            }
            j += 2;
        }
       assertReserveAndExcessZero(StakeNFTLP_, reserveEth);
        setBlockNumber(block.number + 2);
        j = 0;
        // burning some amount of Positions
        for (uint256 i = 0; i < iterations; i++) {
            if (i % 7 == 0) {
                        (uint256 payoutEth, ) = users[i].burn(
                    tokenIDs[j]
                );
                reserveEth -= payoutEth;
                (payoutEth, ) = users[i].burn(tokenIDs[j + 1]);
                reserveEth -= payoutEth;
            }
            j += 2;
        }
       assertReserveAndExcessZero(StakeNFTLP_, reserveEth);
        setBlockNumber(block.number + 2);
        j = 0;
        //mint more tokens again
        for (uint256 i = 0; i < iterations; i++) {
            if (i % 7 == 0) {
                users[i] = newUserAccount(madToken, StakeNFTLP_);
                madToken.transfer(
                    address(users[i]),
                    (1_000_000 * ONE_MADTOKEN) + i
                );
                users[i].approve(
                    address(StakeNFTLP_),
                    (1_000_000 * ONE_MADTOKEN) + i
                );
                tokenIDs[j] = users[i].mint((500_000 * ONE_MADTOKEN) - i);
                tokenIDs[j + 1] = users[i].mint((500_000 * ONE_MADTOKEN) + i);
                donator.depositEth(i * 1 ether);
                reserveEth += i * 1 ether;
            }
            j += 2;
        }
       assertReserveAndExcessZero(StakeNFTLP_, reserveEth);
        setBlockNumber(block.number + 2);
        j = 0;
        // collecting all the existing tokens
        for (uint256 i = 0; i < iterations; i++) {
            reserveEth -= users[i].collectEth(tokenIDs[j]);
            reserveEth -= users[i].collectEth(tokenIDs[j + 1]);
            j += 2;
        }
       assertReserveAndExcessZero(StakeNFTLP_, reserveEth);
        j = 0;
        // burning all token expect 1
        for (uint256 i = 0; i < iterations - 1; i++) {
            (uint256 payoutEth, ) = users[i].burn(
                tokenIDs[j]
            );
            reserveEth -= payoutEth;
           assertReserveAndExcessZero(StakeNFTLP_, reserveEth);
            (payoutEth, ) = users[i].burn(tokenIDs[j + 1]);
            reserveEth -= payoutEth;
           assertReserveAndExcessZero(StakeNFTLP_, reserveEth);
            j += 2;
        }
       assertReserveAndExcessZero(StakeNFTLP_, reserveEth);
        users[iterations - 1].burn(tokenIDs[(iterations - 1) * 2]);
        users[iterations - 1].burn(tokenIDs[(iterations - 1) * 2 + 1]);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 0);
        assertEq(address(StakeNFTLP_).balance, 0);
        assertEq(StakeNFTLP_.getTotalShares(), 0);
       assertReserveAndExcessZero(StakeNFTLP_, 0);
    }

    function testFail_CollectNonOwnedEth() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 1000 * ONE_MADTOKEN);
        user1.approve(address(StakeNFTLP_), 1000 * ONE_MADTOKEN);

        // minting
        uint256 tokenID1 = user1.mint(1000 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID1),
            StakeNFTLP.Position(uint224(1000 * ONE_MADTOKEN), 0)
        );

        user2.collectEth(tokenID1);
    }

    function testFail_BurnNonOwnedPosition() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 1000 * ONE_MADTOKEN);
        user1.approve(address(StakeNFTLP_), 1000 * ONE_MADTOKEN);

        // minting
        uint256 tokenID1 = user1.mint(1000 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  tokenID1),
            StakeNFTLP.Position(uint224(1000 * ONE_MADTOKEN), 0)
        );

        user2.burn(tokenID1);
    }

    function testFail_estimateEthCollectionNonExistentToken() public {
        (StakeNFTLP StakeNFTLP_, , ) = getFixtureData();
        StakeNFTLP_.estimateEthCollection(100);
    }

    function testCollectEtherWithOverflowOnTheAccumulator() public {
        (
            StakeNFTLPHugeAccumulator StakeNFTLPHugeAcc,
            MadTokenMock madToken,

        ) = getFixtureDataWithHugeAccumulator();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLPHugeAcc);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLPHugeAcc);
        UserAccount donator = newUserAccount(madToken, StakeNFTLPHugeAcc);

        madToken.transfer(address(user1), 100);
        madToken.transfer(address(user2), 100);

        user1.approve(address(StakeNFTLPHugeAcc), 100);
        user2.approve(address(StakeNFTLPHugeAcc), 100);
        payable(address(donator)).transfer(1000);

        uint256 expectedAccumulatorETH = type(uint168).max -
            StakeNFTLPHugeAcc.getOffsetToOverflow();
        uint224 user1Shares = 50;
        uint256 tokenID1 = user1.mint(user1Shares);
        assertPosition(        
            getCurrentPosition(StakeNFTLPHugeAcc, tokenID1),
            StakeNFTLP.Position(user1Shares, expectedAccumulatorETH)
        );
        assertReserveAndExcessZero(StakeNFTLPHugeAcc, 0);
        (uint256 acc, uint256 slush) = StakeNFTLPHugeAcc.getEthAccumulator();
        assertEq(acc, expectedAccumulatorETH);
        assertEq(slush, 0);

        //moving the accumulator closer to the overflow
        uint256 deposit1 = 25; //wei
        donator.depositEth(deposit1);
        expectedAccumulatorETH +=
            (deposit1 * StakeNFTLPHugeAcc.accumulatorScaleFactor()) /
            user1Shares;
        assertReserveAndExcessZero(StakeNFTLPHugeAcc, deposit1);

        uint224 user2Shares = 50;
        uint256 tokenID2 = user2.mint(user2Shares);
        assertPosition(
            getCurrentPosition(StakeNFTLPHugeAcc, tokenID2),
            StakeNFTLP.Position(user2Shares, expectedAccumulatorETH)
            );
        {
            (uint256 acc_, uint256 slush_) = StakeNFTLPHugeAcc
                .getEthAccumulator();
            assertEq(acc_, expectedAccumulatorETH);
            assertEq(slush_, 0);
        }
        assertReserveAndExcessZero(
            StakeNFTLPHugeAcc,
            deposit1
        );
        // the overflow should happen here as we are incrementing the accumulator by 150 * 10**16
        uint256 deposit2 = 150; //wei
        donator.depositEth(deposit2);
        expectedAccumulatorETH +=
            (deposit2 * StakeNFTLPHugeAcc.accumulatorScaleFactor()) /
            (user1Shares + user2Shares);
        expectedAccumulatorETH -= type(uint168).max;
        (acc, slush) = StakeNFTLPHugeAcc.getEthAccumulator();
        assertEq(acc, expectedAccumulatorETH);
        assertEq(acc, 1000000000000000000);
        assertEq(slush, 0);
        assertReserveAndExcessZero(
            StakeNFTLPHugeAcc,
            deposit1 + deposit2
        );

        setBlockNumber(block.number + 2);

        // Testing collecting the dividends after the accumulator overflow
        assertEq(StakeNFTLPHugeAcc.estimateEthCollection(tokenID1), 100);
        assertEq(user1.collectEth(tokenID1), 100);
        assertReserveAndExcessZero(StakeNFTLPHugeAcc, 75);
        assertEq(StakeNFTLPHugeAcc.estimateEthCollection(tokenID2), 75);
        assertEq(user2.collectEth(tokenID2), 75);
        assertReserveAndExcessZero(StakeNFTLPHugeAcc, 0);
    }

    function testBurnEtherWithOverflowOnTheAccumulator() public {
        (
            StakeNFTLPHugeAccumulator StakeNFTLPHugeAcc,
            MadTokenMock madToken,

        ) = getFixtureDataWithHugeAccumulator();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLPHugeAcc);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLPHugeAcc);
        UserAccount donator = newUserAccount(madToken, StakeNFTLPHugeAcc);

        madToken.transfer(address(user1), 100);
        madToken.transfer(address(user2), 100);

        user1.approve(address(StakeNFTLPHugeAcc), 100);
        user2.approve(address(StakeNFTLPHugeAcc), 100);
        payable(address(donator)).transfer(1000);

        uint256 expectedAccumulatorETH = type(uint168).max -
            StakeNFTLPHugeAcc.getOffsetToOverflow();
        uint224 user1Shares = 50;
        uint256 tokenID1 = user1.mint(user1Shares);
        assertPosition(
            getCurrentPosition(StakeNFTLPHugeAcc, tokenID1), 
            StakeNFTLP.Position(user1Shares, expectedAccumulatorETH)
        );
        assertReserveAndExcessZero(StakeNFTLPHugeAcc, 0);
        (uint256 acc, uint256 slush) = StakeNFTLPHugeAcc.getEthAccumulator();
        assertEq(acc, expectedAccumulatorETH);
        assertEq(slush, 0);

        //moving the accumulator closer to the overflow
        uint256 deposit1 = 25; //wei
        donator.depositEth(deposit1);
        expectedAccumulatorETH +=
            (deposit1 * StakeNFTLPHugeAcc.accumulatorScaleFactor()) /
            user1Shares;
        assertReserveAndExcessZero(StakeNFTLPHugeAcc, deposit1);
        uint224 user2Shares = 50;
        uint256 tokenID2 = user2.mint(user2Shares);
        assertPosition(
            getCurrentPosition(StakeNFTLPHugeAcc, tokenID2), 
            StakeNFTLP.Position(user2Shares, expectedAccumulatorETH)
        );
        {
            (uint256 acc_, uint256 slush_) = StakeNFTLPHugeAcc
                .getEthAccumulator();
            assertEq(acc_, expectedAccumulatorETH);
            assertEq(slush_, 0);
        }
        assertReserveAndExcessZero(
            StakeNFTLPHugeAcc,
            deposit1
        );

        // the overflow should happen here. As we are incrementing the accumulator by 150 * 10**16
        uint256 deposit2 = 150; //wei
        donator.depositEth(deposit2);
        expectedAccumulatorETH +=
            (deposit2 * StakeNFTLPHugeAcc.accumulatorScaleFactor()) /
            (user1Shares + user2Shares);
        expectedAccumulatorETH -= type(uint168).max;
        (acc, slush) = StakeNFTLPHugeAcc.getEthAccumulator();
        assertEq(acc, expectedAccumulatorETH);
        assertEq(acc, 1000000000000000000);
        assertEq(slush, 0);
        assertReserveAndExcessZero(
            StakeNFTLPHugeAcc,
            deposit1 + deposit2
        );

        //setBlockNumber(block.number+2);

        // Testing collecting the dividends after the accumulator overflow Each
        // user has to call collect twice to get the right amount of funds
        // (before and after the overflow)
        assertEq(StakeNFTLPHugeAcc.estimateEthCollection(tokenID1), 100);
        assertEq(StakeNFTLPHugeAcc.estimateEthCollection(tokenID2), 75);
        // advance block number
        require(setBlockNumber(block.number + 2));
        {
            (uint256 payoutEth1, ) = user1.burn(tokenID1);
            assertEq(payoutEth1, 100);
        }
        assertReserveAndExcessZero(StakeNFTLPHugeAcc, 75);
        {
            (uint256 payoutEth2, ) = user2.burn(tokenID2);
            assertEq(payoutEth2, 75);
        }
        assertReserveAndExcessZero(StakeNFTLPHugeAcc, 0);
    }

    function testFail_ReentrantLoopCollectEth() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        ReentrantLoopEthCollectorAccount user = new ReentrantLoopEthCollectorAccount();
        user.setTokens(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 100);
        //madToken.transfer(address(donator), 210_000_000 * ONE_MADTOKEN );

        user.approve(address(StakeNFTLP_), 100);
        //donator.approve(address(StakeNFTLP_), 210_000_000 * ONE_MADTOKEN);

        //payable(address(user)).transfer(2000 ether);
        payable(address(donator)).transfer(2000 ether);

        uint256 tokenID = user.mint(100);
        setBlockNumber(block.number + 2);
        donator.depositEth(1000 ether);

        user.collectEth(tokenID);

        // it should not get here
    }

    function test_ReentrantFiniteCollectEth() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        UserAccount honestUser = newUserAccount(madToken, StakeNFTLP_);
        ReentrantFiniteEthCollectorAccount user = new ReentrantFiniteEthCollectorAccount();
        user.setTokens(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 100);
        madToken.transfer(address(honestUser), 100);

        user.approve(address(StakeNFTLP_), 100);
        honestUser.approve(address(StakeNFTLP_), 100);

        payable(address(donator)).transfer(2000 ether);

        uint256 tokenID = user.mint(100);
        uint256 honestTokenID = honestUser.mint(100);
        setBlockNumber(block.number + 2);
        donator.depositEth(1000 ether);
        // the result with re-entrance should be the same as calling collectEth only once
        uint256 payout = user.collectEth(tokenID);
        assertEq(payout, 500 ether);
        assertEq(address(user).balance, 500 ether);
        payout = honestUser.collectEth(honestTokenID);
        assertEq(payout, 500 ether);
        assertEq(address(honestUser).balance, 500 ether);
    }

    function testFail_ReentrantLoopBurn() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        ReentrantLoopBurnAccount user = new ReentrantLoopBurnAccount();
        user.setTokens(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 100);
        //madToken.transfer(address(donator), 210_000_000 * ONE_MADTOKEN );

        user.approve(address(StakeNFTLP_), 100);
        //donator.approve(address(StakeNFTLP_), 210_000_000 * ONE_MADTOKEN);

        //payable(address(user)).transfer(2000 ether);
        payable(address(donator)).transfer(2000 ether);

        uint256 tokenID = user.mint(100);
        setBlockNumber(block.number + 2);
        donator.depositEth(1000 ether);

        user.burn(tokenID);

        // it should not get here
    }

    function testFail_ReentrantFiniteBurn() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        ReentrantFiniteBurnAccount user = new ReentrantFiniteBurnAccount();
        user.setTokens(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 100);
        //madToken.transfer(address(donator), 210_000_000 * ONE_MADTOKEN );

        user.approve(address(StakeNFTLP_), 100);
        //donator.approve(address(StakeNFTLP_), 210_000_000 * ONE_MADTOKEN);

        //payable(address(user)).transfer(2000 ether);
        payable(address(donator)).transfer(2000 ether);

        uint256 tokenID = user.mint(100);

        donator.depositEth(1000 ether);
        setBlockNumber(block.number + 2);
        user.burn(tokenID);

        // it should not get here

        //assertEq(payout, 1000 ether);

        //assertEq(address(user).balance, 1000 ether);
    }

    function testFail_SafeTransferPosition_WithoutApproval() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100);
        user1.approve(address(StakeNFTLP_), 100);
        uint256 tokenID = user1.mint(100);

        StakeNFTLP_.safeTransferFrom(address(user1), address(user2), tokenID);
    }

    function testFail_SafeTransferPosition_toNonERC721Receiver() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100);
        user1.approve(address(StakeNFTLP_), 100);
        uint256 tokenID = user1.mint(100);

        setBlockNumber(block.number + 2);

        user1.approveNFT(address(this), tokenID);

        StakeNFTLP_.safeTransferFrom(address(user1), address(user2), tokenID);
    }

    function testSafeTransferPosition_toERC721Receiver() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        ERC721ReceiverAccount user2 = new ERC721ReceiverAccount();
        user2.setTokens(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100);
        user1.approve(address(StakeNFTLP_), 100);
        uint256 tokenID = user1.mint(100);
       assertReserveAndExcessZero(StakeNFTLP_, 0);

        setBlockNumber(block.number + 2);

        user1.approveNFT(address(this), tokenID);

        StakeNFTLP_.safeTransferFrom(address(user1), address(user2), tokenID);

        assertEq(StakeNFTLP_.ownerOf(tokenID), address(user2));
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 0);
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 1);
        assertEq(StakeNFTLP_.balanceOf(address(StakeNFTLP_)), 0);
       assertReserveAndExcessZero(StakeNFTLP_, 0);     
        }

    function testFail_SafeTransferPosition_toReentrantLoopBurnERC721Receiver()
        public
    {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        ReentrantLoopBurnERC721ReceiverAccount user2 = new ReentrantLoopBurnERC721ReceiverAccount();
        user2.setTokens(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100);
        user1.approve(address(StakeNFTLP_), 100);
        uint256 tokenID = user1.mint(100);

        payable(donator).transfer(100 ether);
        donator.depositEth(100 ether);

        setBlockNumber(block.number + 2);

        user1.approveNFT(address(this), tokenID);
        StakeNFTLP_.safeTransferFrom(address(user1), address(user2), tokenID);
    }

    function testFail_SafeTransferPosition_toReentrantFiniteBurnERC721Receiver()
        public
    {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        ReentrantFiniteBurnERC721ReceiverAccount user2 = new ReentrantFiniteBurnERC721ReceiverAccount();
        user2.setTokens(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100);
        user1.approve(address(StakeNFTLP_), 100);
        uint256 tokenID = user1.mint(100);

        payable(donator).transfer(100 ether);
        donator.depositEth(100 ether);

        setBlockNumber(block.number + 2);

        user1.approveNFT(address(this), tokenID);
        StakeNFTLP_.safeTransferFrom(address(user1), address(user2), tokenID);
    }

    function testSafeTransferPosition_toReentrantLoopCollectEthERC721Receiver()
        public
    {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        ReentrantLoopCollectEthERC721ReceiverAccount user2 = new ReentrantLoopCollectEthERC721ReceiverAccount();
        user2.setTokens(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100);
        user1.approve(address(StakeNFTLP_), 100);
        uint256 tokenID = user1.mint(100);

        payable(donator).transfer(100 ether);
        donator.depositEth(100 ether);

        setBlockNumber(block.number + 2);

        user1.approveNFT(address(this), tokenID);
        StakeNFTLP_.safeTransferFrom(address(user1), address(user2), tokenID);

        assertEq(StakeNFTLP_.ownerOf(tokenID), address(user2));
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 0);
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 1);
        assertEq(StakeNFTLP_.balanceOf(address(StakeNFTLP_)), 0);

        assertEq(address(user2).balance, 100 ether);
        assertEq(address(user1).balance, 0);
        assertEq(address(donator).balance, 0);
        assertEq(address(StakeNFTLP_).balance, 0);
    }

    function testTransferPosition() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100 * ONE_MADTOKEN);
        madToken.transfer(address(user2), 100 * ONE_MADTOKEN);

        user1.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);
        user2.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);

        uint256 token1User1 = user1.mint(100 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  token1User1),
            StakeNFTLP.Position(uint224(100 * ONE_MADTOKEN), 0)
        );
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 1);
        assertEq(StakeNFTLP_.ownerOf(token1User1), address(user1));
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 0);
       assertReserveAndExcessZero(StakeNFTLP_,  0);

        user1.transferFrom(address(user1), address(user2), token1User1);

        assertEq(StakeNFTLP_.balanceOf(address(user1)), 0);
        assertEq(StakeNFTLP_.ownerOf(token1User1), address(user2));
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 1);
       assertReserveAndExcessZero(StakeNFTLP_,  0);
    }

    function testApproveTransferPosition() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100 * ONE_MADTOKEN);
        madToken.transfer(address(user2), 100 * ONE_MADTOKEN);

        user1.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);
        user2.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);

        uint256 token1User1 = user1.mint(100 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  token1User1),
            StakeNFTLP.Position(uint224(100 * ONE_MADTOKEN), 0)
        );
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 1);
        assertEq(StakeNFTLP_.ownerOf(token1User1), address(user1));
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 0);
       assertReserveAndExcessZero(StakeNFTLP_,  0);

        //approving user2 to transfer user1 token
        user1.approveNFT(address(user2), token1User1);
        user1.transferFrom(address(user1), address(user2), token1User1);

        assertEq(StakeNFTLP_.balanceOf(address(user1)), 0);
        assertEq(StakeNFTLP_.ownerOf(token1User1), address(user2));
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 1);
       assertReserveAndExcessZero(StakeNFTLP_,  0);
    }

    function testApproveAllTransferPosition() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken,) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100 * ONE_MADTOKEN);
        madToken.transfer(address(user2), 100 * ONE_MADTOKEN);

        user1.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);
        user2.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);

        uint256 token1User1 = user1.mint(50 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  token1User1),
            StakeNFTLP.Position(uint224(50 * ONE_MADTOKEN), 0)
        );
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 1);
        assertEq(StakeNFTLP_.ownerOf(token1User1), address(user1));
       assertReserveAndExcessZero(StakeNFTLP_,  0);

        uint256 token2User1 = user1.mint(50 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  token2User1),
            StakeNFTLP.Position(uint224(50 * ONE_MADTOKEN), 0)
        );
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 2);
        assertEq(StakeNFTLP_.ownerOf(token2User1), address(user1));
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 0);
       assertReserveAndExcessZero(StakeNFTLP_,  0);

        //approving the test contract to transfer all user1 token
        user1.setApprovalForAll(address(this), true);
        StakeNFTLP_.transferFrom(address(user1), address(user2), token1User1);
        StakeNFTLP_.transferFrom(address(user1), address(this), token2User1);

        assertEq(StakeNFTLP_.balanceOf(address(user1)), 0);
        assertEq(StakeNFTLP_.ownerOf(token1User1), address(user2));
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 1);
        assertEq(StakeNFTLP_.ownerOf(token2User1), address(this));
        assertEq(StakeNFTLP_.balanceOf(address(this)), 1);
       assertReserveAndExcessZero(StakeNFTLP_,  0);
    }

    function testFail_TransferNotOwnedPositionWithoutApproval() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken, ) = getFixtureData();
        UserAccount user1 =newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 =newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100 * ONE_MADTOKEN);
        madToken.transfer(address(user2), 100 * ONE_MADTOKEN);

        user1.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);
        user2.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);

        uint256 token1User1 = user1.mint(50 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_,  token1User1),
            StakeNFTLP.Position(uint224(50 * ONE_MADTOKEN), 0)
        );
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 1);
        assertEq(StakeNFTLP_.ownerOf(token1User1), address(user1));

        // test contract was not approved to run the transfer method
        StakeNFTLP_.transferFrom(address(user1), address(user2), token1User1);
    }

    function testFail_TransferNotOwnedPositionWithoutApproval2() public {
        (StakeNFTLP StakeNFTLP_, MadTokenMock madToken, ) = getFixtureData();
        UserAccount user1 = newUserAccount(madToken, StakeNFTLP_);
        UserAccount user2 = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(user1), 100 * ONE_MADTOKEN);
        madToken.transfer(address(user2), 100 * ONE_MADTOKEN);

        user1.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);
        user2.approve(address(StakeNFTLP_), 100 * ONE_MADTOKEN);

        uint256 token1User1 = user1.mint(50 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_, token1User1),
            StakeNFTLP.Position(uint224(50 * ONE_MADTOKEN), 0)
        );
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 1);
        assertEq(StakeNFTLP_.ownerOf(token1User1), address(user1));

        uint256 token2User1 = user1.mint(50 * ONE_MADTOKEN);
        assertPosition(
            getCurrentPosition(StakeNFTLP_, token2User1),
            StakeNFTLP.Position(uint224(50 * ONE_MADTOKEN), 0)
        );
        assertEq(StakeNFTLP_.balanceOf(address(user1)), 2);
        assertEq(StakeNFTLP_.ownerOf(token2User1), address(user1));
        assertEq(StakeNFTLP_.balanceOf(address(user2)), 0);

        user1.approveNFT(address(this), token1User1);
        // test contract was not approved to transfer token 2 only token1
        StakeNFTLP_.transferFrom(address(user1), address(user2), token2User1);
    }

    
    function testSkimExcessEth() public {
        // transferring money before the contract is created
        payable(address(0xEFc56627233b02eA95bAE7e19F648d7DcD5Bb132)).transfer(
            100 ether + 1
        );
        (
            StakeNFTLP StakeNFTLP_,
            MadTokenMock madToken,
            AdminAccount admin

        ) = getFixtureData();
        assertEq(address(StakeNFTLP_).balance, 100 ether + 1);
        assertReserveAndExcess(StakeNFTLP_, 0, 100 ether + 1);
        UserAccount user = newUserAccount(madToken, StakeNFTLP_);
        assertEq(address(user).balance, 0);
        admin.skimExcessEth(address(user));
        assertEq(address(user).balance, 100 ether + 1);
        assertEq(address(StakeNFTLP_).balance, 0);
    }

    function testSkimExcessToken() public {
        (
            StakeNFTLP StakeNFTLP_,
            MadTokenMock madToken,
            AdminAccount admin
        ) = getFixtureData();
        // transferring Token excess
        madToken.transfer(
            address(StakeNFTLP_),
            1000 * ONE_MADTOKEN + 1
        );
        assertEq(
            madToken.balanceOf(address(StakeNFTLP_)),
            1000 * ONE_MADTOKEN + 1
        );

        UserAccount user = newUserAccount(madToken, StakeNFTLP_);
        assertEq(madToken.balanceOf(address(user)), 0);
        admin.skimExcessToken(address(user));
        assertEq(madToken.balanceOf(address(user)), 1000 * ONE_MADTOKEN + 1);
        assertEq(madToken.balanceOf(address(StakeNFTLP_)), 0);
    }

    function testFail_ReentrantSkimExcessEth() public {
        // transferring money before the contract is created
        payable(address(0xEFc56627233b02eA95bAE7e19F648d7DcD5Bb132)).transfer(
            100 ether
        );
        (
            StakeNFTLP StakeNFTLP_,
            MadTokenMock madToken,
            AdminAccountReEntrant admin

        ) = getFixtureDataAdminReEntrant();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        UserAccount honestUser = newUserAccount(madToken, StakeNFTLP_);

        madToken.transfer(address(honestUser), 100);
        honestUser.approve(address(StakeNFTLP_), 100);
        payable(address(donator)).transfer(2000 ether);

        uint256 tokenID1 = honestUser.mint(50);
        uint256 TokenID2 = honestUser.mint(50);
        setBlockNumber(block.number + 2);
        donator.depositEth(1000 ether);

        // calling with reentrancy should yield the same result as calling it normally
        admin.skimExcessEth(address(admin));
        assertEq(address(admin).balance, 100 ether);

        uint256 payout = honestUser.collectEth(tokenID1);
        assertEq(payout, 500 ether);
        assertEq(address(honestUser).balance, 500 ether);
        payout = honestUser.collectEth(TokenID2);
        assertEq(payout, 500 ether);
        assertEq(address(honestUser).balance, 1000 ether);
    }

    function testFail_ReentrantNoAdmin() public {
        // transferring money before the contract is created
        payable(address(0xEFc56627233b02eA95bAE7e19F648d7DcD5Bb132)).transfer(
            100 ether
        );
        (
            StakeNFTLP StakeNFTLP_,
            MadTokenMock madToken,
            AdminAccount admin

        ) = getFixtureData();
        UserAccount donator = newUserAccount(madToken, StakeNFTLP_);
        UserAccount honestUser = newUserAccount(madToken, StakeNFTLP_);
        AdminAccountReEntrant user = new AdminAccountReEntrant();
        user.setTokens(madToken, StakeNFTLP_);

        madToken.transfer(address(user), 100);
        madToken.transfer(address(honestUser), 100);

        user.approve(address(StakeNFTLP_), 100);
        honestUser.approve(address(StakeNFTLP_), 100);

        payable(address(donator)).transfer(2000 ether);

        user.mint(100);
        uint256 honestTokenID = honestUser.mint(100);

        setBlockNumber(block.number + 2);
        donator.depositEth(1000 ether);
        admin.skimExcessEth(address(user));
    }
}