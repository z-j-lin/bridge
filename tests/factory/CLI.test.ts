import { expect } from "chai";
import {
  deployFactory,
  getAccounts,
  MADNET_FACTORY,
  predictFactoryAddress,
} from "./Setup.test";
import { artifacts, ethers, run } from "hardhat";
import { getDefaultFactoryAddress } from "../../scripts/lib/factoryStateUtils";
import { MadnetFactory, Utils } from "../../typechain-types";
import { Args } from "../../scripts/lib/madnetFactoryTasks";

describe("Cli tasks", async () => {
  let utilsBase;
  let firstOwner: string;
  let firstDelegator: string;
  let accounts: Array<string> = [];
  let utilsContract: Utils;
  let factory: MadnetFactory;

  beforeEach(async () => {
    accounts = await getAccounts();
    //set owner and delegator
    firstOwner = accounts[0];
    firstDelegator = accounts[1];
    let utilsFactory = await ethers.getContractFactory("Utils")
    utilsContract = await utilsFactory.deploy();
    factory = await deployFactory(MADNET_FACTORY);
    let cSize = await utilsContract.getCodeSize(factory.address);
    expect(cSize.toNumber()).to.be.greaterThan(0);
  });

  it.only("deployFactory", async () => {
    let futureFactoryAddress = await predictFactoryAddress(firstOwner);
    let factoryAddress = await run("deployFactory", {dev: true});
    //check if the address is the predicted
    expect(factoryAddress).to.equal(futureFactoryAddress);
    let defaultFactoryAddress = await getDefaultFactoryAddress("dev");
    expect(defaultFactoryAddress).to.equal(factoryAddress);
  });
  
  it("deployMetamorphic", async () => {
    let futureFactoryAddress = await predictFactoryAddress(firstOwner);
    let factoryAddress = await run("deployFactory");
    let args:Args = {
      contractName: "Mock",
    }
    let metamorphicContractData = await run("deployMetamorphic")
  })
   

  it("deployCreate", async () => {
    let futureFactoryAddress = await predictFactoryAddress(firstOwner);
    let factoryAddress = await run("deployFactory");
    let contractData = await run("deployCreate", {
      contractName: "Mock",
      constructorArgs: ["2", "s"]
    });
    //check the deployed contract size 
  });

  it("deploy mock with deploystatic", async () => {
    await run("deployMetamorphic", {
      contractName: "EndPoint",
      constructorArgs: "0x92D3A65c5890a5623F3d73Bf3a30c973043eE90C",
    });
  });

});
