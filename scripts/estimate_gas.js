const fs = require("fs");
const chalk = require("chalk");

const GanFaceNft = artifacts.require("GanFaceNft");
const PaymentToken = artifacts.require("PaymentToken");
const Faucet = artifacts.require("Faucet");
const RentNft = artifacts.require("RentNft");

const log = console.log;
const divider = "----------------------------------------";

// mint a face from one account
// lend a face from that same account, estimate gas

const init = async () => {
  const face = await GanFaceNft.deployed();
  const pmtToken = await PaymentToken.deployed();
  const faucet = await Faucet.deployed();
  const rent = await RentNft.deployed();

  return {
    face,
    pmtToken,
    faucet,
    rent
  };
};

const mintFace = async ({face}) => {
  const receipt = await face.awardGanFace("");
};

const main = async () => {
  log(divider);

  const {face, pmtToken, rent} = await init();

  await mintFace({face});

  await face.approve(rent.address, "1");

  const gasEstimate = await rent.lendOne.estimateGas(
    face.address,
    "1",
    "42",
    "42",
    "42",
    "1",
    rent.address
  );

  let prevGasEstimate = "";

  try {
    prevGasEstimate = Number(fs.readFileSync("estimate-gas/renft/lendOne.txt"));
  } catch (err) {
    console.error(err);
  }

  fs.writeFileSync("estimate-gas/renft/lendOne.txt", gasEstimate);

  let chalkColor = "";
  if (gasEstimate > 100000) {
    chalkColor = "red";
  } else if (gasEstimate > 80000) {
    chalkColor = "yellow";
  } else {
    chalkColor = "green";
  }

  log("lendOne gasEstimate:", chalk[chalkColor].bold(gasEstimate));

  if (prevGasEstimate) {
    const prevColor = prevGasEstimate > gasEstimate ? "green" : "red";
    log("lendOne prev gasEstimate:", chalk[prevColor].bold(prevGasEstimate));
    log(
      "lendOne diff:",
      chalk[prevColor].bold((gasEstimate - prevGasEstimate).toFixed(2))
    );
    log(
      "lendOne ",
      chalk[prevColor].bold(
        prevGasEstimate > gasEstimate
          ? (-((1 - gasEstimate / prevGasEstimate) * 100)).toFixed(2)
          : ((gasEstimate / prevGasEstimate - 1) * 100).toFixed(2)
      ),
      "%"
    );
  }

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
