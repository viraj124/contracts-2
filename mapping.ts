import {BigInt} from "@graphprotocol/graph-ts";
import {Lent, Borrowed, Returned} from "./generated/RentNft/RentNft";
import {NewFace} from "./generated/GanFaceNft/GanFaceNft";
import {Face, Lending, Borrowing, User} from "./generated/schema";

let createUser = (id: string): User => {
  let user = new User(id);
  user.lending = new Array<string>();
  user.borrowing = new Array<string>();
  user.faces = new Array<string>();
  user.approvals = new Array<string>();
  user.approvedAll = new Array<string>();
  return user;
};

// ! notes for self
// 1. string templating does not work
// 2. variables from function scope not visible inside of .filter
// 3. pushing directly into arrays won't work. Need to make a copy and then assign a copy to prop

let getFaceId = (nftAddr: string, tokenId: string): string =>
  nftAddr + "::" + tokenId;
let getNftId = (faceId: string, lender: string): string =>
  faceId + "::" + lender;

export function handleLent(event: Lent): void {
  // ! FACE MUST EXIST AT THIS POINT
  let lentParams = event.params;
  // imagine the following: contract A & contract B
  // contract A is the owner of the NFT
  // they lend it out. They don't see it in their Lend tab
  // contract B borrows. Now they can lend it out
  // they lend it out, and now contrct A can see it and rent it out
  // if contract A defaults, they will pay the collateral
  // this will trigger contract B default, which means contract
  // A can now claim the collateral
  // For this reason the NFT id must have additional information
  // this means that the same actual NFT may have more than one
  // entry in the graph. Number of entries is determined by how
  // many times it was lent out. The so-called NFT "hot-potato"
  // AKA mortgage backed security
  let lenderAddress = lentParams.lender.toHex();
  let faceId = getFaceId(
    lentParams.nftAddress.toHex(),
    lentParams.tokenId.toHex()
  );
  let lendingId = lentParams.lentIndex;

  let nftId = getNftId(faceId, lenderAddress);

  // * ------------------------ NFT --------------------------
  // if the user previously lent out the NFT
  let lending = Lending.load(lendingId.toHex());
  // creating a new nft, if this is the first time
  if (!lending) {
    lending = new lending(lendingId.toHex());
  }
  lending.address = lentParams.nftAddress;
  lending.lender = lentParams.lender;
  lending.dailyBorrowPrice = lentParams.dailyBorrowPrice;
  lending.maxDuration = lentParams.maxDuration;
  lending.nftPrice = lentParams.nftPrice;
  lending.tokenId = lentParams.tokenId;
  lending.rentStatus = false;

  // populating / creating lender
  let lender = User.load(lenderAddress);
  if (!lender) {
    lender = createUser(lenderAddress);
  }
  let newLending = lender.lending;
  newLending.push(lending.id);
  lender.lending = newLending;
  // * --------------------------------------------------------

  // ! -------------------------------------------------------
  // ! production: remove the faces
  if (!lender.faces.includes(nftId)) {
    // ! FACE MUST EXIST. IF IT DOESN'T, IT WILL NOT HAVE A URI
    let newFaces = lender.faces;
    newFaces.push(faceId);
    lender.faces = newFaces;
  }
  lending.face = faceId;
  // ! -------------------------------------------------------

  lending.save();
  lender.save();
}

export function handleBorrowed(event: Borrowed): void {
  // ! FACE MUST EXIST AT THIS POINT
  let borrowedParams = event.params;

  let borrowId = borrowedParams.rentIndex;
  let lendingId = borrowedParams.lentIndex;
  let lending = Lending.load(lendingId.toHex());
  lending.rentStatus = true;
  let borrowing = new Borrowing(borrowId.toHex());
  borrowing.borrower = borrowedParams.borrower;
  borrowing.lendingId = lending.id;
  borrowing.actualDuration = borrowedParams.actualDuration;
  borrowing.borrowedAt = borrowing.borrowedAt;

  // populating / creating borrower
  let borrowerAddr = borrowedParams.borrower.toHex();
  let borrower = User.load(borrowerAddr);
  if (!borrower) {
    borrower = createUser(borrowerAddr);
  }
  let newBorrowing = borrower.borrowing;
  newBorrowing.push(borrow.id);
  borrower.borrowing = newBorrowing;
  lending.save();
  borrowing.save();
  borrower.save();
}

export function handleReturned(event: Returned): void {
  let returnParams = event.params;
  let lending = lending.load(returnParams.lentIndex.toHex());
  lending.rentStatus = false;
  let borrow = borrow.load(returnParams.rentIndex.toHex());

  let user = User.load(borrow.borrower.toHex());

  // when the user returns the item, we remove it from their borrowing field
  let borrowed = user.borrowing;
  let borrowingIndex = borrowed.indexOf(borrow.id);
  borrowed.splice(borrowingIndex, 1);

  user.borrowing = borrowed;
  borrow.borrower = null;
  borrow.actualDuration = BigInt.fromI32(0);
  borrow.borrowedAt = BigInt.fromI32(0);
  // ----------------------------------------------------

  user.save();
  lending.save();
  borrow.save();
}

// gan face contract
export function handleNewFace(event: NewFace): void {
  let newFaceParams = event.params;
  // ! ensure that event.address is the address of the NFT
  let faceId = getFaceId(event.address.toHex(), newFaceParams.tokenId.toHex());
  let face = new Face(faceId);
  face.uri = newFaceParams.tokenURI;

  let nftOwner = event.params.owner.toHex();
  let user = User.load(nftOwner);
  if (!user) {
    user = createUser(nftOwner);
  }
  let newFaces = user.faces;
  newFaces.push(faceId);
  user.faces = newFaces;

  face.save();
  user.save();
}
