import {BigInt} from "@graphprotocol/graph-ts";
import {Lent, Borrowed, Returned} from "./generated/RentNft/RentNft";
import {
  NewFace,
  Approval as ApprovalEvent,
  ApprovalForAll
} from "./generated/GanFaceNft/GanFaceNft";
import {
  Face,
  Listing,
  Rental,
  User,
  Approval as ApprovalSchema,
  ApprovedAll
} from "./generated/schema";

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
let getApprovedOneId = (
  nftAddress: string,
  owner: string,
  approved: string,
  tokenId: string
): string => nftAddress + "::" + tokenId + "::" + owner + "::" + approved;
let getApprovedAllId = (
  nftAddress: string,
  owner: string,
  approved: string
): string => nftAddress + "::" + owner + "::" + approved;

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
  let listingId = lentParams.lentIndex;

  let nftId = getNftId(faceId, lenderAddress);

  // * ------------------------ NFT --------------------------
  // if the user previously lent out the NFT
  let listing = Listing.load(listingId.toHex());
  // creating a new nft, if this is the first time
  if (!listing) {
    listing = new Listing(listingId.toHex());
  }
  listing.address = lentParams.nftAddress;
  listing.lender = lentParams.lender;
  listing.dailyBorrowPrice = lentParams.dailyBorrowPrice;
  listing.maxDuration = lentParams.maxDuration;
  listing.nftPrice = lentParams.nftPrice;
  listing.tokenId = lentParams.tokenId;
  listing.rentStatus = false;
  // -----------------------------------
  // // for safety
  // // ! does not work something about the explicit case from null...
  // // nft = resetBorrowedNft(nft);
  // nft.borrower = null;
  // nft.actualDuration = BigInt.fromI32(0);
  // nft.borrowedAt = BigInt.fromI32(0);
  // -----------------------------------

  // populating / creating lender
  let lender = User.load(lenderAddress);
  if (!lender) {
    lender = createUser(lenderAddress);
  }
  let newLending = lender.lending;
  newLending.push(listing.id);
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
  listing.face = faceId;
  // ! -------------------------------------------------------

  listing.save();
  lender.save();
}

export function handleBorrowed(event: Borrowed): void {
  // ! FACE MUST EXIST AT THIS POINT
  let borrowedParams = event.params;

  let rentalId = borrowedParams.rentIndex;
  let listingId = borrowedParams.lentIndex;
  let listing = Listing.load(listingId.toHex());
  listing.rentStatus = true;
  let rental = new Rental(rentalId.toHex());
  rental.borrower = borrowedParams.borrower;
  rental.listingIndex = listing.id;
  rental.actualDuration = borrowedParams.actualDuration;
  rental.borrowedAt = rental.borrowedAt;

  // populating / creating borrower
  let borrowerAddr = borrowedParams.borrower.toHex();
  let borrower = User.load(borrowerAddr);
  if (!borrower) {
    borrower = createUser(borrowerAddr);
  }
  let newBorrowing = borrower.borrowing;
  newBorrowing.push(rental.id);
  borrower.borrowing = newBorrowing;
  listing.save();
  rental.save();
  borrower.save();
}

export function handleReturned(event: Returned): void {
  let returnParams = event.params;
  let listing = Listing.load(returnParams.lentIndex.toHex());
  listing.rentStatus = false;
  let rental = Rental.load(returnParams.rentIndex.toHex());
  rental.borrower = null;
  rental.actualDuration = BigInt.fromI32(0);
  rental.borrowedAt = BigInt.fromI32(0);
  let user = User.load(rental.borrower.toHex());

  // -----------------------------------
  // nft = resetBorrowedNft(nft);

  // -----------------------------------

  // ----------------------------------------------------
  // when the user returns the item, we remove it from their borrowing field
  // ! it does not see nftId in scope
  let borrowed = user.borrowing;
  let borrowingIndex = borrowed.indexOf(rental.id);
  borrowed.splice(borrowingIndex, 1);

  user.borrowing = borrowed;
  // ----------------------------------------------------

  user.save();
  listing.save();
  rental.save();
}

// TODO: handler for the opposite of handleLent
// i.e. for when the user removes the NFT from the platform
// when we return the NFT back to them

// ! ------------------------- remove in prod -----------------------------------
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
// ! --------------------------------------------------------------------------

export function handleApprovalOne(event: ApprovalEvent): void {
  let approvalParams = event.params;
  let nftOwner = approvalParams.owner;
  let approved = approvalParams.approved;
  let tokenId = approvalParams.tokenId;
  let nftOwnerHex = nftOwner.toHex();

  // ! check that the event.address is the NFT address (like above)
  let approvalId = getApprovedOneId(
    event.address.toHex(),
    tokenId.toHex(),
    nftOwnerHex,
    approved.toHex()
  );
  let approval = new ApprovalSchema(approvalId);
  approval.nftAddress = event.address;
  approval.owner = nftOwner;
  approval.approved = approved;
  approval.tokenId = tokenId;

  // now update the user if exists. If not, create them
  let user = User.load(nftOwnerHex);
  if (!user) {
    user = createUser(nftOwnerHex);
  }
  let newApprovals = user.approvals;
  newApprovals.push(approvalId);
  user.approvals = newApprovals;

  approval.save();
  user.save();
}

export function handleApprovalAll(event: ApprovalForAll): void {
  let nftOwner = event.params.owner;
  let approved = event.params.operator;
  let nftOwnerHex = nftOwner.toHex();

  let approveAllId = getApprovedAllId(
    event.address.toHex(),
    nftOwnerHex,
    approved.toHex()
  );
  let approvedAll = new ApprovedAll(approveAllId);
  approvedAll.nftAddress = event.address;
  approvedAll.owner = nftOwner;
  approvedAll.approved = approved;

  let user = User.load(nftOwnerHex);
  if (user == null) {
    user = createUser(nftOwnerHex);
  }
  let newApprovedAlls = user.approvedAll;
  newApprovedAlls.push(approveAllId);
  user.approvedAll = newApprovedAlls;

  approvedAll.save();
  user.save();
}
