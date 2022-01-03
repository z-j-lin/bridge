const {expect} = require("chai");
const { getCreate2Address } = require("ethers/lib/utils");
const { ethers } = require("hardhat");
var address;
describe("MadnetFactory", function () {
    it("should return 0", async function(){
        const MadnetFactory = await ethers.getContractFactory("MadnetFactory");
        const madnetFactory = await MadnetFactory.deploy();
        await madnetFactory.deployed();
        await madnetFactory.initialize();
        await madnetFactory.deploy('0x000000000000000000000000000000000000000000000000004d616442797465', initcode, "0xaaaa")
        address = madnetFactory.address;
    });
    it.only("should return address of contract", async function(){
        const MadnetFactory = await ethers.getContractFactory("MadnetFactory");
        //get the bytecode of the implementation contract
        const MadByte = await ethers.getContractFactory("MadByte");
        //connect to the deployed factory contract
        const madnetFactory = await MadnetFactory.attach("0x782A289aF1dF5Cdbc48fE8DbCa772E7d0F34e4B8");
        //run the deployfunction      
        await madnetFactory.deploy('0x000000000000000000000000000000000000000000000000004d616442797465', initcode, "0xaaaa")
    });
});