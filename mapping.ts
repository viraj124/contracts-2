import {BigInt} from "@graphprotocol/graph-ts";
import {Lent, Borrowed, Returned} from "./generated/RentNft/RentNft";
import {
  NewFace,
  Approval as ApprovalEvent,
  ApprovalForAll
} from "./generated/GanFaceNft/GanFaceNft";
import {
  Face,
  Nft,
  User,
  Approval as ApprovalSchema,
  ApprovedAll
} from "./generated/schema";

const createUser = (id: string): User => {
  const user = new User(id);
  user.lending = new Array<string>();
  user.borrowing = new Array<string>();
  user.faces = new Array<string>();
  user.approvals = new Array<string>();
  user.approvedAll = new Array<string>();
  return user;
};

const resetBorrowedNft = (nft: Nft): Nft => {
  nft.borrower = null;
  nft.actualDuration = BigInt.fromI32(0);
  nft.borrowedAt = BigInt.fromI32(0);
  return nft;
};

// ! notes for self
// 1. string templating does not work
// 2. variables from function scope not visible inside of .filter
// 3. pushing directly into arrays won't work. Need to make a copy and then assign a copy to prop

const getFaceId = (nftAddr: string, tokenId: string): string =>
  nftAddr + "::" + tokenId;
const getNftId = (faceId: string, lender: string): string =>
  faceId + "::" + lender;
const getApprovedOneId = (
  nftAddress: string,
  owner: string,
  approved: string,
  tokenId: string
): string => nftAddress + "::" + tokenId + "::" + owner + "::" + approved;
const getApprovedAllId = (
  nftAddress: string,
  owner: string,
  approved: string
): string => nftAddress + "::" + owner + "::" + approved;

export function handleLent(event: Lent): void {
  // ! FACE MUST EXIST AT THIS POINT
  const lentParams = event.params;
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
  const lenderAddress = lentParams.lender.toHex();
  const faceId = getFaceId(
    lentParams.nftAddress.toHex(),
    lentParams.tokenId.toHex()
  );
  const nftId = getNftId(faceId, lenderAddress);

  // * ------------------------ NFT --------------------------
  // if the user previously lent out the NFT
  let nft = Nft.load(nftId);
  // creating a new nft, if this is the first time
  if (!nft) {
    nft = new Nft(nftId);
  }
  // -----------------------------------
  // for safety
  // ! does not work something about the explicit case from null...
  // nft = resetBorrowedNft(nft);
  nft.borrower = null;
  nft.actualDuration = BigInt.fromI32(0);
  nft.borrowedAt = BigInt.fromI32(0);
  // -----------------------------------

  nft.address = lentParams.nftAddress;
  nft.lender = lentParams.lender;
  nft.borrowPrice = lentParams.borrowPrice;
  nft.maxDuration = lentParams.maxDuration;
  nft.nftPrice = lentParams.nftPrice;

  // populating / creating lender
  let lender = User.load(lenderAddress);
  if (!lender) {
    lender = createUser(lenderAddress);
  }
  const newLending = lender.lending;
  newLending.push(nftId);
  lender.lending = newLending;
  // * --------------------------------------------------------

  // ! -------------------------------------------------------
  // ! production: remove the faces
  if (!lender.faces.includes(nftId)) {
    // ! FACE MUST EXIST. IF IT DOESN'T, IT WILL NOT HAVE A URI
    const newFaces = lender.faces;
    newFaces.push(faceId);
    lender.faces = newFaces;
  }
  nft.face = faceId;
  // ! -------------------------------------------------------

  nft.save();
  lender.save();
}

export function handleBorrowed(event: Borrowed): void {
  // ! FACE MUST EXIST AT THIS POINT
  const borrowedParams = event.params;
  const faceId = getFaceId(
    borrowedParams.nftAddress.toHex(),
    borrowedParams.tokenId.toHex()
  );
  const nftId = getNftId(faceId, borrowedParams.lender.toHex());
  const nft = Nft.load(nftId);

  nft.borrower = borrowedParams.borrower;
  nft.actualDuration = borrowedParams.actualDuration;
  nft.borrowedAt = borrowedParams.borrowedAt;

  // populating / creating borrower
  const borrowerAddr = borrowedParams.borrower.toHex();
  let borrower = User.load(borrowerAddr);
  if (!borrower) {
    borrower = createUser(borrowerAddr);
  }
  const newBorrowing = borrower.borrowing;
  newBorrowing.push(nftId);
  borrower.borrowing = newBorrowing;

  nft.save();
  borrower.save();
}

export function handleReturned(event: Returned): void {
  const returnParams = event.params;
  const faceId = getFaceId(
    returnParams.nftAddress.toHex(),
    returnParams.tokenId.toHex()
  );
  const nftId = getNftId(faceId, returnParams.lender.toHex());
  let nft = Nft.load(nftId);
  const user = User.load(nft.borrower.toHex());

  // -----------------------------------
  // nft = resetBorrowedNft(nft);
  nft.borrower = null;
  nft.actualDuration = BigInt.fromI32(0);
  nft.borrowedAt = BigInt.fromI32(0);
  // -----------------------------------

  // ----------------------------------------------------
  // when the user returns the item, we remove it from their borrowing field
  // ! it does not see nftId in scope
  const borrowing = user.borrowing.filter((item) => {
    // ? how do I remove nftId declaration here?
    const faceId = getFaceId(
      event.params.nftAddress.toHex(),
      event.params.tokenId.toHex()
    );
    const nftId = getNftId(faceId, event.params.lender.toHex());
    return item !== nftId;
  });
  user.borrowing = borrowing;
  // ----------------------------------------------------

  user.save();
  nft.save();
}

// TODO: handler for the opposite of handleLent
// i.e. for when the user removes the NFT from the platform
// when we return the NFT back to them

// ! ------------------------- remove in prod -----------------------------------
// gan face contract
export function handleNewFace(event: NewFace): void {
  const newFaceParams = event.params;
  // ! ensure that event.address is the address of the NFT
  const faceId = getFaceId(
    event.address.toHex(),
    newFaceParams.tokenId.toHex()
  );
  const face = new Face(faceId);
  face.uri = newFaceParams.tokenURI;

  const nftOwner = event.params.owner.toHex();
  let user = User.load(nftOwner);
  if (!user) {
    user = createUser(nftOwner);
  }
  const newFaces = user.faces;
  newFaces.push(faceId);
  user.faces = newFaces;

  face.save();
  user.save();
}
// ! --------------------------------------------------------------------------

export function handleApprovalOne(event: ApprovalEvent): void {
  const approvalParams = event.params;
  const nftOwner = approvalParams.owner;
  const approved = approvalParams.approved;
  const tokenId = approvalParams.tokenId;
  const nftOwnerHex = nftOwner.toHex();

  // ! check that the event.address is the NFT address (like above)
  const approvalId = getApprovedOneId(
    event.address.toHex(),
    tokenId.toHex(),
    nftOwnerHex,
    approved.toHex()
  );
  const approval = new ApprovalSchema(approvalId);
  approval.nftAddress = event.address;
  approval.owner = nftOwner;
  approval.approved = approved;
  approval.tokenId = tokenId;

  // now update the user if exists. If not, create them
  let user = User.load(nftOwnerHex);
  if (!user) {
    user = createUser(nftOwnerHex);
  }
  const newApprovals = user.approvals;
  newApprovals.push(approvalId);
  user.approvals = newApprovals;

  approval.save();
  user.save();
}

export function handleApprovalAll(event: ApprovalForAll): void {
  const nftOwner = event.params.owner;
  const approved = event.params.operator;
  const nftOwnerHex = nftOwner.toHex();

  const approveAllId = getApprovedAllId(
    event.address.toHex(),
    nftOwnerHex,
    approved.toHex()
  );
  const approvedAll = new ApprovedAll(approveAllId);
  approvedAll.nftAddress = event.address;
  approvedAll.owner = nftOwner;
  approvedAll.approved = approved;

  let user = User.load(nftOwnerHex);
  if (user == null) {
    user = createUser(nftOwnerHex);
  }
  const newApprovedAlls = user.approvedAll;
  newApprovedAlls.push(approveAllId);
  user.approvedAll = newApprovedAlls;

  approvedAll.save();
  user.save();
}
