import { validators4 } from "../assets/4-validators-successful-case";
import { ethers } from "hardhat";
import {
  endCurrentPhase,
  distributeValidatorsShares,
  startAtDistributeShares,
  expect,
  startAtGPKJ,
  assertETHDKGPhase,
  completeETHDKG,
  Phase,
  PLACEHOLDER_ADDRESS,
  submitMasterPublicKey,
  submitValidatorsGPKJ,
  submitValidatorsKeyShares,
  waitNextPhaseStartDelay,
} from "../setup";
import { BigNumberish } from "ethers";
import { validators4BadGPKJSubmission } from "../assets/4-validators-1-bad-gpkj-submission";
import { validators10BadGPKJSubmission } from "../assets/10-validators-1-bad-gpkj-submission";
import { validators10_2BadGPKJSubmission } from "../assets/10-validators-2-bad-gpkj-submission";
import { getValidatorEthAccount, mineBlocks } from "../../setup";

describe("ETHDKG: Dispute GPKj", () => {
  it("accuse good and bad participants of sending bad gpkj shares with 4 validators", async function () {
    // last validator is the bad one
    let validators = validators4BadGPKJSubmission;
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // all validators will send their gpkj. Validator 4 will send bad data
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators,
      expectedNonce,
      0
    );

    await waitNextPhaseStartDelay(ethdkg);

    await assertETHDKGPhase(ethdkg, Phase.DisputeGPKJSubmission);
    expect(await ethdkg.getBadParticipants()).to.equal(0);
    // Accuse the 4th validator of bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[0]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[3].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(1);
    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      true
    );
    expect(await validatorPool.isValidator(validators[3].address)).to.equal(
      false
    );

    // Accuse the a valid validator of bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[0]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[2].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(2);
    // validator 0 ( the disputer) should be the one evicted!
    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      false
    );
    expect(await validatorPool.isValidator(validators[2].address)).to.equal(
      true
    );
  });

  it("accuse multiple bad participants of sending bad gpkj shares with 10 validators", async function () {
    // last 2 validators are the bad ones
    let validators = validators10_2BadGPKJSubmission;
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // all validators will send their gpkj.
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators,
      expectedNonce,
      0
    );

    await waitNextPhaseStartDelay(ethdkg);

    await assertETHDKGPhase(ethdkg, Phase.DisputeGPKJSubmission);
    expect(await ethdkg.getBadParticipants()).to.equal(0);
    // Accuse the 10th validator of bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[0]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[validators.length - 1].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(1);
    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      true
    );
    expect(
      await validatorPool.isValidator(validators[validators.length - 1].address)
    ).to.equal(false);

    // Accuse the second validator that sent bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[0]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[validators.length - 2].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(2);

    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      true
    );
    expect(
      await validatorPool.isValidator(validators[validators.length - 2].address)
    ).to.equal(false);

    // Accuse the a valid validator of bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[0]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[2].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(3);
    // validator 0 ( the disputer) should be the one evicted!
    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      false
    );
    expect(await validatorPool.isValidator(validators[2].address)).to.equal(
      true
    );

  });

  it("accuse good and bad participants of sending bad gpkj shares with 10 validators", async function () {
    // last validator is the bad one
    let validators = validators10BadGPKJSubmission;
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // all validators will send their gpkj. Validator 4 will send bad data
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators,
      expectedNonce,
      0
    );

    await waitNextPhaseStartDelay(ethdkg);

    await assertETHDKGPhase(ethdkg, Phase.DisputeGPKJSubmission);
    expect(await ethdkg.getBadParticipants()).to.equal(0);

    // Accuse the 10th validator of bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[0]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[validators.length - 1].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(1);
    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      true
    );
    expect(
      await validatorPool.isValidator(validators[validators.length - 1].address)
    ).to.equal(false);

    // Accuse the a valid validator of bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[0]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[2].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(2);
    // validator 0 ( the disputer) should be the one evicted!
    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      false
    );
    expect(await validatorPool.isValidator(validators[2].address)).to.equal(
      true
    );
  });

  it("accuse a missing participant and bad participant at the same time ", async function () {
    // last validator is the bad one
    let validators = validators10BadGPKJSubmission;
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // all validators except validator 8 will send their gpkj. Validator 9 will send bad data
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators.slice(1, 10),
      expectedNonce,
      0
    );

    await endCurrentPhase(ethdkg);
    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);
    expect(await ethdkg.getBadParticipants()).to.equal(0);
    // Accuse the last validator of bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[1]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[1].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[1].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[validators.length - 1].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(1);
    expect(await validatorPool.isValidator(validators[1].address)).to.equal(
      true
    );
    expect(
      await validatorPool.isValidator(validators[validators.length - 1].address)
    ).to.equal(false);

    await ethdkg
      .connect(await getValidatorEthAccount(validators[1]))
      .accuseParticipantDidNotSubmitGPKJ([validators[0].address]);

    expect(await ethdkg.getBadParticipants()).to.equal(2);

    expect(await validatorPool.isValidator(validators[1].address)).to.equal(
      true
    );
    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      false
    );

    await endCurrentPhase(ethdkg);

    await expect(
      ethdkg.connect(await getValidatorEthAccount(validators[1])).complete()
    ).to.be.rejectedWith("ETHDKG: should be in post-GPKJDispute phase!");
  });

  it("should not allow accusations before time", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators4);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // try accusing bad GPKj
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[0].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          PLACEHOLDER_ADDRESS
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Should be in post-GPKJSubmission phase!");
  });

  it("should not allow accusations unless in DisputeGPKJSubmission phase, or expired GPKJSubmission phase", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtDistributeShares(
      validators4
    );

    await assertETHDKGPhase(ethdkg, Phase.ShareDistribution);

    // try accusing bad GPKj
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[0].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          PLACEHOLDER_ADDRESS
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Should be in post-GPKJSubmission phase!");

    // distribute shares
    await distributeValidatorsShares(
      ethdkg,
      validatorPool,
      validators4,
      expectedNonce
    );
    await assertETHDKGPhase(ethdkg, Phase.DisputeShareDistribution);

    // skipping the distribute shares accusation phase
    await endCurrentPhase(ethdkg);
    await assertETHDKGPhase(ethdkg, Phase.DisputeShareDistribution);

    // submit key shares phase
    await submitValidatorsKeyShares(
      ethdkg,
      validatorPool,
      validators4,
      expectedNonce
    );

    // try accusing bad GPKj
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[0].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          PLACEHOLDER_ADDRESS
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Should be in post-GPKJSubmission phase!");

    //await endCurrentPhase(ethdkg)
    await assertETHDKGPhase(ethdkg, Phase.MPKSubmission);

    // try accusing bad GPKj
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[0].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          PLACEHOLDER_ADDRESS
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Should be in post-GPKJSubmission phase!");

    // submit MPK
    await mineBlocks((await ethdkg.getConfirmationLength()).toNumber());
    await submitMasterPublicKey(ethdkg, validators4, expectedNonce);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // try accusing bad GPKj
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[0].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          PLACEHOLDER_ADDRESS
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Should be in post-GPKJSubmission phase!");

    // submit GPKj
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators4,
      expectedNonce,
      0
    );

    await assertETHDKGPhase(ethdkg, Phase.DisputeGPKJSubmission);

    // try accusing bad GPKj
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[0].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          PLACEHOLDER_ADDRESS
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Should be in post-GPKJSubmission phase!");

    await endCurrentPhase(ethdkg);

    // try accusing bad GPKj
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[0].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          PLACEHOLDER_ADDRESS
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Should be in post-GPKJSubmission phase!");

    // complete ethdkg
    await completeETHDKG(ethdkg, validators4, expectedNonce, 0, 0);

    await assertETHDKGPhase(ethdkg, Phase.Completion);

    // try accusing bad GPKj
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[0].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          PLACEHOLDER_ADDRESS
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Should be in post-GPKJSubmission phase!");
  });

  it("should not allow accusation of a non-participating validator", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators4);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // 3/4 validators will submit GPKj, 4th validator will not
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators4.slice(0, 3),
      expectedNonce,
      0
    );

    await endCurrentPhase(ethdkg);

    // try accusing the 4th validator of bad GPKj, when it did not even submit it
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[0].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          validators4[3].address
        )
    ).to.be.revertedWith(
      "ETHDKG: Dispute Failed! Dishonest participant didn't submit his GPKJ for this round!"
    );
  });

  it("should not allow accusation from a non-participating validator", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators4);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // 3/4 validators will submit GPKj, 4th validator will not
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators4.slice(0, 3),
      expectedNonce,
      0
    );

    await endCurrentPhase(ethdkg);

    // validator 4 will try accusing the 1st validator of bad GPKj, when it did not even submit it itself
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[3].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          validators4[0].address
        )
    ).to.be.revertedWith(
      "ETHDKG: Dispute Failed! Disputer didn't submit his GPKJ for this round!"
    );
  });

  it("should not allow accusation with incorrect data length, or all zeros", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators4);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // all validators will submit GPKj
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators4,
      expectedNonce,
      0
    );

    //await endCurrentPhase(ethdkg)
    await assertETHDKGPhase(ethdkg, Phase.DisputeGPKJSubmission);
    await mineBlocks((await ethdkg.getConfirmationLength()).toNumber());

    // length based tests

    // accuse a validator using incorrect validators length
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[3].address))
        .accuseParticipantSubmittedBadGPKJ(
          [],
          [],
          [[[0, 0]]],
          validators4[0].address
        )
    ).to.be.revertedWith(
      "ETHDKG: Dispute Failed! Invalid submission of arguments!"
    );

    // accuse a validator using incorrect encryptedSharesHash length
    const placeholderBytes32 =
      "0x0000000000000000000000000000000000000000000000000000000000000000";
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[3].address))
        .accuseParticipantSubmittedBadGPKJ(
          [
            PLACEHOLDER_ADDRESS,
            PLACEHOLDER_ADDRESS,
            PLACEHOLDER_ADDRESS,
            PLACEHOLDER_ADDRESS,
          ],
          [
            placeholderBytes32,
            placeholderBytes32,
            placeholderBytes32,
            placeholderBytes32,
          ],
          [[[0, 0]]],
          validators4[0].address
        )
    ).to.be.revertedWith(
      "ETHDKG: Dispute Failed! Invalid submission of arguments!"
    );

    // accuse a validator using incorrect commitments length
    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[3].address))
        .accuseParticipantSubmittedBadGPKJ(
          [
            PLACEHOLDER_ADDRESS,
            PLACEHOLDER_ADDRESS,
            PLACEHOLDER_ADDRESS,
            PLACEHOLDER_ADDRESS,
          ],
          [
            placeholderBytes32,
            placeholderBytes32,
            placeholderBytes32,
            placeholderBytes32,
          ],
          [[[0, 0]], [[0, 0]], [[0, 0]], [[0, 0]]],
          validators4[0].address
        )
    ).to.be.revertedWith(
      "ETHDKG: Dispute Failed! Invalid number of commitments provided!"
    );

    // duplicated validator in `validators` input
    // also create a encryptedSharesHash like keccak256(abi.encodePacked(encryptedShares))
    const encryptedSharesHash = ethers.utils.solidityKeccak256(
      ["uint256[]"],
      [validators4[0].encryptedShares]
    );

    await expect(
      ethdkg
        .connect(await ethers.getSigner(validators4[3].address))
        .accuseParticipantSubmittedBadGPKJ(
          [
            validators4[0].address,
            validators4[0].address,
            validators4[1].address,
            validators4[2].address,
          ],
          [
            encryptedSharesHash,
            placeholderBytes32,
            placeholderBytes32,
            placeholderBytes32,
          ],
          [
            validators4[0].commitments,
            [
              [0, 0],
              [0, 0],
              [0, 0],
            ],
            [
              [0, 0],
              [0, 0],
              [0, 0],
            ],
            [
              [0, 0],
              [0, 0],
              [0, 0],
            ],
          ],
          validators4[0].address
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Invalid or duplicated participant address!");
  });

  it("should not allow accusation with repeated addresses", async function () {
    let validators = validators4BadGPKJSubmission;
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // all validators will submit GPKj
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators,
      expectedNonce,
      0
    );

    await assertETHDKGPhase(ethdkg, Phase.DisputeGPKJSubmission);
    await waitNextPhaseStartDelay(ethdkg);

    await expect(
      ethdkg
        .connect(await getValidatorEthAccount(validators[0]))
        .accuseParticipantSubmittedBadGPKJ(
          [
            validators[0].address,
            validators[0].address,
            validators[1].address,
            validators[2].address,
          ],
          (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
            x.toString()
          ),
          validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
          validators[validators.length - 1].address
        )
    ).to.be.revertedWith("ETHDKG: Dispute Failed! Invalid or duplicated participant address!");
  });

  it("do not allow validators to proceed to the next phase if a validator was valid accused", async function () {
    // last validator is the bad one
    let validators = validators4BadGPKJSubmission;
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // all validators will send their gpkj. Validator 4 will send bad data
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators,
      expectedNonce,
      0
    );

    await waitNextPhaseStartDelay(ethdkg);

    await assertETHDKGPhase(ethdkg, Phase.DisputeGPKJSubmission);
    expect(await ethdkg.getBadParticipants()).to.equal(0);
    // Accuse the 4th validator of bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[0]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[3].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(1);
    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      true
    );
    expect(await validatorPool.isValidator(validators[3].address)).to.equal(
      false
    );

    await endCurrentPhase(ethdkg);

    await expect(
      ethdkg.connect(await getValidatorEthAccount(validators[0])).complete()
    ).to.be.rejectedWith(
      "ETHDKG: Not all requisites to complete this ETHDKG round were completed!"
    );
  });

  it("do not allow a bad validator being accused more than once", async function () {
    // last validator is the bad one
    let validators = validators4BadGPKJSubmission;
    let [ethdkg, validatorPool, expectedNonce] = await startAtGPKJ(validators);

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // all validators will send their gpkj. Validator 4 will send bad data
    await submitValidatorsGPKJ(
      ethdkg,
      validatorPool,
      validators,
      expectedNonce,
      0
    );

    await waitNextPhaseStartDelay(ethdkg);

    await assertETHDKGPhase(ethdkg, Phase.DisputeGPKJSubmission);
    expect(await ethdkg.getBadParticipants()).to.equal(0);
    // Accuse the 4th validator of bad GPKj
    await ethdkg
      .connect(await getValidatorEthAccount(validators[0]))
      .accuseParticipantSubmittedBadGPKJ(
        validators.map((x) => x.address),
        (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
          x.toString()
        ),
        validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
        validators[3].address
      );
    expect(await ethdkg.getBadParticipants()).to.equal(1);
    expect(await validatorPool.isValidator(validators[0].address)).to.equal(
      true
    );
    expect(await validatorPool.isValidator(validators[3].address)).to.equal(
      false
    );

    await expect(
      ethdkg
        .connect(await getValidatorEthAccount(validators[0]))
        .accuseParticipantSubmittedBadGPKJ(
          validators.map((x) => x.address),
          (validators[0].encryptedSharesHash as BigNumberish[]).map((x) =>
            x.toString()
          ),
          validators[0].groupCommitments as [BigNumberish, BigNumberish][][],
          validators[3].address
        )
    ).to.be.rejectedWith("ETHDKG: Dispute Failed! Dishonest Address is not a validator at the moment!");
  });
});
