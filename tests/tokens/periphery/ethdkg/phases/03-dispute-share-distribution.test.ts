import { validators4 } from "../assets/4-validators-successful-case";
import { ethers } from "hardhat";
import {
  endCurrentPhase,
  endCurrentAccusationPhase,
  distributeValidatorsShares,
  startAtDistributeShares,
  expect,
  assertETHDKGPhase,
  Phase,
  PLACEHOLDER_ADDRESS,
  submitValidatorsKeyShares,
  submitMasterPublicKey,
  mineBlocks,
  submitValidatorsGPKJ,
  completeETHDKG,
} from "../setup";

describe("Distribute bad shares accusation", () => {

  it("should not allow accusations before time", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtDistributeShares(
      validators4
    );
    
    await assertETHDKGPhase(ethdkg, Phase.ShareDistribution);

    // try accusing bad shares
    await expect(ethdkg.accuseParticipantDistributedBadShares(PLACEHOLDER_ADDRESS, 0, 0, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Contract is not in dispute phase")
  });

  it("should not allow accusations unless in DisputeShareDistribution phase, or expired ShareDistribution phase", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtDistributeShares(
      validators4
    );

    // try accusing bad shares
    await expect(ethdkg.accuseParticipantDistributedBadShares(PLACEHOLDER_ADDRESS, 0, 0, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Contract is not in dispute phase")
    
    await assertETHDKGPhase(ethdkg, Phase.ShareDistribution);

    // try accusing bad shares
    await expect(ethdkg.accuseParticipantDistributedBadShares(PLACEHOLDER_ADDRESS, 0, 0, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Contract is not in dispute phase")

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
    await submitValidatorsKeyShares(ethdkg, validatorPool, validators4, expectedNonce)

    // try accusing bad shares
    await expect(ethdkg.accuseParticipantDistributedBadShares(PLACEHOLDER_ADDRESS, 0, 0, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Contract is not in dispute phase")

    //await endCurrentPhase(ethdkg)
    await assertETHDKGPhase(ethdkg, Phase.MPKSubmission);

    // try accusing bad shares
    await expect(ethdkg.accuseParticipantDistributedBadShares(PLACEHOLDER_ADDRESS, 0, 0, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Contract is not in dispute phase")

    // submit MPK
    await mineBlocks((await ethdkg.getConfirmationLength()).toNumber())
    await submitMasterPublicKey(ethdkg, validators4, expectedNonce)

    await assertETHDKGPhase(ethdkg, Phase.GPKJSubmission);

    // try accusing bad shares
    await expect(ethdkg.accuseParticipantDistributedBadShares(PLACEHOLDER_ADDRESS, 0, 0, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Contract is not in dispute phase")
    
    // submit GPKj
    await submitValidatorsGPKJ(ethdkg, validatorPool, validators4, expectedNonce, 1)

    await assertETHDKGPhase(ethdkg, Phase.DisputeGPKJSubmission)

    // try accusing bad shares
    await expect(ethdkg.accuseParticipantDistributedBadShares(PLACEHOLDER_ADDRESS, 0, 0, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Contract is not in dispute phase")

    await endCurrentPhase(ethdkg)

    // try accusing bad shares
    await expect(ethdkg.accuseParticipantDistributedBadShares(PLACEHOLDER_ADDRESS, 0, 0, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Contract is not in dispute phase")

    // complete ethdkg
    await completeETHDKG(ethdkg, validators4, expectedNonce, 1, 1)

    await assertETHDKGPhase(ethdkg, Phase.Completion)

    // try accusing bad shares
    await expect(ethdkg.accuseParticipantDistributedBadShares(PLACEHOLDER_ADDRESS, 0, 0, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Contract is not in dispute phase")
  });

  
  it("should not allow accusation of a non-participating validator", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtDistributeShares(
      validators4
    );
    
    await assertETHDKGPhase(ethdkg, Phase.ShareDistribution);

    // 3/4 validators will distribute shares, 4th validator will not
    await distributeValidatorsShares(
      ethdkg,
      validatorPool,
      validators4.slice(0, 3),
      expectedNonce
    );

    await endCurrentPhase(ethdkg)

    // try accusing the 4th validator of bad shares, when it did not even distribute them
    await expect(ethdkg.connect(await ethers.getSigner(validators4[0].address)).accuseParticipantDistributedBadShares(validators4[3].address, 4, 1, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Issuer did not distribute shares!")
  });

  it("should not allow accusation of a non-participating validator", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtDistributeShares(
      validators4
    );
    
    await assertETHDKGPhase(ethdkg, Phase.ShareDistribution);

    // 3/4 validators will distribute shares, 4th validator will not
    await distributeValidatorsShares(
      ethdkg,
      validatorPool,
      validators4.slice(0, 3),
      expectedNonce
    );

    await endCurrentPhase(ethdkg)

    // validator 4 will try accusing the 1st validator of bad shares, when it did not even distribute them itself
    await expect(ethdkg.connect(await ethers.getSigner(validators4[3].address)).accuseParticipantDistributedBadShares(validators4[0].address, 4, 1, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Disputer did not distribute shares!")
  });

  it("should not allow accusation with an incorrect index", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtDistributeShares(
      validators4
    );
    
    await assertETHDKGPhase(ethdkg, Phase.ShareDistribution);

    // 
    await distributeValidatorsShares(
      ethdkg,
      validatorPool,
      validators4,
      expectedNonce
    );

    await assertETHDKGPhase(ethdkg, Phase.DisputeShareDistribution)
    await mineBlocks((await ethdkg.getConfirmationLength()).toNumber())
    //await endCurrentPhase(ethdkg)

    // try accusing the 4th validator of bad shares using an incorrect index
    await expect(ethdkg.connect(await ethers.getSigner(validators4[3].address)).accuseParticipantDistributedBadShares(validators4[0].address, 10, 20, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("Dispute failed! Invalid list indices for the issuer or for the disputer!")
  });

  it("should not allow accusation with incorrect encrypted shares or commitments", async function () {
    let [ethdkg, validatorPool, expectedNonce] = await startAtDistributeShares(
      validators4
    );
    
    await assertETHDKGPhase(ethdkg, Phase.ShareDistribution);

    await distributeValidatorsShares(
      ethdkg,
      validatorPool,
      validators4,
      expectedNonce
    );

    await assertETHDKGPhase(ethdkg, Phase.DisputeShareDistribution)
    await mineBlocks((await ethdkg.getConfirmationLength()).toNumber())

    // try accusing the 1st validator of bad shares using incorrect encrypted shares and commitments
    await expect(ethdkg.connect(await ethers.getSigner(validators4[3].address)).accuseParticipantDistributedBadShares(validators4[0].address, 1, 4, [], [[0,0]], [0,0], [0,0]))
    .to.be.revertedWith("dispute failed, submitted commitments and encrypted shares don't match!")
  });
 

});
