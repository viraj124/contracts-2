const fs = require("fs");
const chalk = require("chalk");

const GanFaceNft = artifacts.require("GanFaceNft");
const PaymentToken = artifacts.require("PaymentToken");
const Faucet = artifacts.require("Faucet");
const RentNft = artifacts.require("RentNft");
const Resolver = artifacts.require("Resolver");

const log = console.log;
const divider = "----------------------------------------";

// const PROVIDER = new HDWalletProvider(
//   "spoon mouse pupil sail verify message seat cross setup stumble park dentist",
//   "http://localhost:7545"
// );

global.web3 = web3;
global.artifacts = artifacts;

const ether = (n) => {
  return new web3.utils.BN(web3.utils.toWei(n.toString(), "ether"));
};

const init = async () => {
  const face = await GanFaceNft.deployed();
  const pmtToken = await PaymentToken.deployed();
  const faucet = await Faucet.deployed();
  const resolver = await Resolver.deployed();
  const rent = await RentNft.deployed();

  const accounts = await web3.eth.getAccounts();

  return {
    accounts,
    face,
    pmtToken,
    faucet,
    resolver,
    rent
  };
};

const mintFace = async ({face, accounts}) => {
  const receipt = await face.awardGanFace("", {from: accounts[0]});
  // log(receipt);
};

const prettyPrint = ({fileName, consolePrefix, gasUsed}) => {
  let prevGasEstimate = "";

  fs.writeFileSync(`estimate-gas/${fileName}`, gasUsed);

  try {
    prevGasEstimate = Number(fs.readFileSync(`estimate-gas/${fileName}`));
  } catch (err) {
    console.error(err);
  }

  let chalkColor = "";
  if (gasUsed > 100000) {
    chalkColor = "red";
  } else if (gasUsed > 80000) {
    chalkColor = "yellow";
  } else {
    chalkColor = "green";
  }

  const dollarCostEstimate = ((gasUsed * 30) / 1e9) * 470;
  log("* 💾 " + chalk.blue("GAS ANALYSIS") + " *");
  log(`${consolePrefix} gasUsed:`, chalk[chalkColor].bold(gasUsed));
  log(
    `${consolePrefix} @ 30 gwei $470/ETH : ~$${dollarCostEstimate.toFixed(2)}`
  );
  log(`${consolePrefix} with CHI: ~$${(dollarCostEstimate / 2).toFixed(2)}`);
  if (prevGasEstimate) {
    const prevColor = prevGasEstimate > gasUsed ? "green" : "red";
    log(
      `${consolePrefix} prev gasUsed:`,
      chalk[prevColor].bold(prevGasEstimate)
    );
    log(
      `${consolePrefix} diff :`,
      chalk[prevColor].bold((gasUsed - prevGasEstimate).toFixed(2))
    );
    log(
      `${consolePrefix} % :`,
      chalk[prevColor].bold(
        prevGasEstimate > gasUsed
          ? (-((1 - gasUsed / prevGasEstimate) * 100)).toFixed(2)
          : ((gasUsed / prevGasEstimate - 1) * 100).toFixed(2)
      )
    );
  }
};

const lendOne = async ({face, rent, accounts}) => {
  const {receipt} = await rent.lendOne(
    face.address, // nftAddress
    "1", // tokenId
    "42", // maxRentDuration
    "42", // dailyRentPrice
    "42", // nftPrice
    "0", // paymentToken
    rent.address, // gasSponsor,
    {from: accounts[0]}
  );
  const {gasUsed} = receipt;
  prettyPrint({
    fileName: "renft/lendOne.txt",
    consolePrefix: "[lendOne]",
    gasUsed
  });
};

const lendMultiple = async ({face, rent}) => {
  const {receipt} = await rent.lendMultiple(
    [
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address
    ], // nftAddress
    ["2", "3", "4", "5", "6", "7", "8", "9"], // tokenId
    ["42", "42", "42", "21", "21", "21", "21", "21"], // maxRentDuration
    ["42", "42", "42", "21", "21", "21", "21", "21"], // dailyRentPrice
    ["42", "42", "42", "21", "21", "21", "21", "21"], // nftPrice
    ["0", "0", "0", "0", "0", "0", "0", "0"], // paymentToken
    [
      rent.address,
      rent.address,
      rent.address,
      rent.address,
      rent.address,
      rent.address,
      rent.address,
      rent.address
    ] // gasSponsor
  );
  const {gasUsed} = receipt;
  prettyPrint({
    fileName: "renft/lendMultiple.txt",
    consolePrefix: "[lendMultiple 8]",
    gasUsed
  });

  await rent.lendMultiple(
    [
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address
    ], // nftAddress
    ["10", "11", "12", "13", "14", "15", "16", "17", "18"], // tokenId
    ["42", "42", "42", "21", "21", "21", "21", "21", "21"], // maxRentDuration
    ["42", "42", "42", "21", "21", "21", "21", "21", "21"], // dailyRentPrice
    ["42", "42", "42", "21", "21", "21", "21", "21", "21"], // nftPrice
    ["0", "0", "0", "0", "0", "0", "0", "0", "0"], // paymentToken
    [
      rent.address,
      rent.address,
      rent.address,
      rent.address,
      rent.address,
      rent.address,
      rent.address,
      rent.address,
      rent.address
    ] // gasSponsor
  );
};

const rentOne = async ({rent, face, accounts, verbose = true}) => {
  // nftAddress, tokenId, id, rentDuration
  const {receipt} = await rent.rentOne(face.address, "1", "1", "1", {
    from: accounts[1]
  });
  const {gasUsed} = receipt;
  if (verbose) {
    prettyPrint({
      fileName: "renft/rentOne.txt",
      consolePrefix: "[rentOne]",
      gasUsed
    });
  }
};

const rentMultiple = async ({rent, face, accounts, verbose = true}) => {
  const {receipt} = await rent.rentMultiple(
    [
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address
    ],
    ["2", "3", "4", "5", "6", "7", "8", "9"],
    ["2", "3", "4", "5", "6", "7", "8", "9"],
    ["1", "1", "1", "1", "1", "1", "1", "1"],
    {from: accounts[1]}
  );
  const {gasUsed} = receipt;
  if (verbose) {
    prettyPrint({
      fileName: "renft/rentMultiple.txt",
      consolePrefix: "[rentMultiple 8]",
      gasUsed
    });
  }
};

const returnOne = async ({rent, face, accounts}) => {
  const {receipt} = await rent.returnOne(face.address, "1", "1", {
    from: accounts[1]
  });
  const {gasUsed} = receipt;
  prettyPrint({
    fileName: "renft/returnOne.txt",
    consolePrefix: "[returnOne]",
    gasUsed
  });
};

const returnMultiple = async ({rent, face, accounts}) => {
  const {receipt} = await rent.returnMultiple(
    [
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address
    ],
    ["2", "3", "4", "5", "6", "7", "8", "9"],
    ["2", "3", "4", "5", "6", "7", "8", "9"],
    {from: accounts[1]}
  );
  const {gasUsed} = receipt;
  prettyPrint({
    fileName: "renft/returnMultiple.txt",
    consolePrefix: "[returnMultiple 8]",
    gasUsed
  });
};

const claimCollateralOne = async ({face, rent}) => {
  const {receipt} = await rent.claimCollateralOne(face.address, "1", "1");
  const {gasUsed} = receipt;
  prettyPrint({
    fileName: "renft/claimCollateralOne.txt",
    consolePrefix: "[claimCollateralOne]",
    gasUsed
  });
};

const claimCollateralMultiple = async ({face, rent}) => {
  const {receipt} = await rent.claimCollateralMultiple(
    [
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address,
      face.address
    ],
    ["2", "3", "4", "5", "6", "7", "8", "9"],
    ["2", "3", "4", "5", "6", "7", "8", "9"]
  );
  const {gasUsed} = receipt;
  prettyPrint({
    fileName: "renft/claimCollateralMultiple.txt",
    consolePrefix: "[claimCollateralMultiple 8]",
    gasUsed
  });
};

const stopLendingOne = async ({face, rent}) => {
  const {receipt} = await rent.stopLendingOne(face.address, "10", "10");
  const {gasUsed} = receipt;
  prettyPrint({
    fileName: "renft/stopLendingOne.txt",
    consolePrefix: "[stopLendingOne]",
    gasUsed
  });
};

const stopLendingMultiple = async ({face, rent}) => {
  const {receipt} = await rent.stopLendingMultiple(
    [face.address, face.address, face.address],
    ["11", "12", "13", "14", "15", "16", "17", "18"],
    ["11", "12", "13", "14", "15", "16", "17", "18"]
  );
  const {gasUsed} = receipt;
  prettyPrint({
    fileName: "renft/stopLendingMultiple.txt",
    consolePrefix: "[stopLendingMultiple 8]",
    gasUsed
  });
};

const main = async () => {
  log(divider);

  const {face, pmtToken, resolver, rent, accounts} = await init();

  await resolver.setPaymentToken("0", pmtToken.address);
  await pmtToken.approve(rent.address, ether(100000), {
    from: accounts[1]
  });
  await pmtToken.transfer(accounts[1], ether(1000), {from: accounts[0]});
  for (let i = 0; i < 20; i++) {
    await mintFace({face, accounts});
  }
  await face.setApprovalForAll(rent.address, "true", {from: accounts[0]});
  await face.setApprovalForAll(rent.address, "true", {from: accounts[1]});

  await lendOne({face, rent, accounts});
  await lendMultiple({face, rent});
  await rentOne({face, rent, accounts});
  await rentMultiple({face, rent, accounts});
  await returnOne({face, rent, accounts});
  await returnMultiple({face, rent, accounts});
  await rentOne({face, rent, accounts, verbose: false});
  await rentMultiple({face, rent, accounts, verbose: false});
  await claimCollateralOne({face, rent});
  await claimCollateralMultiple({face, rent});
  await stopLendingOne({face, rent});
  await stopLendingMultiple({face, rent});

  log(divider);
};

module.exports = () => {
  main()
    .then(() => {
      process.exit(0);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
};
