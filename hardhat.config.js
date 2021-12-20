require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "ganache",
  networks: {
    ganache: {
      url: "HTTP://127.0.0.1:8545",
      accounts: ["9305771b3112a9a52cfcc4270bd0040ff5aefd2ae18cbbd972612bdb357a1074", "8441c5098bd9e6f06b5d2000176aec0d2332e6ac994a9c586aeb2dd8c4c20000"]
    }
  },
  solidity: "0.8.10",
  paths: {
    sources: "./src",
    tests: "./test",
    artifacts: "./artifacts"
  }
};
