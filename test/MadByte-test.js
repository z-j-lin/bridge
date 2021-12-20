const {expect} = require("chai");
const { getCreate2Address } = require("ethers/lib/utils");
const { ethers } = require("hardhat");
var address;
describe("MadnetFactory", function () {
    it("should return 0", async function(){
        const MadByte = await ethers.getContractFactory("MadByte");
        const madbyte = await MadByte.deploy();
        await madbyte.deployed();
    });
});