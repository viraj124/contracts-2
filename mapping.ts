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

export function handleLent(event: Lent): void {
  const id = event.params.tokenId;
  const nft = new Nft(id.toHex());

  nft.address = event.params.nftAddress;
  nft.lender = event.params.lender;
  nft.borrowPrice = event.params.borrowPrice;
  nft.maxDuration = event.params.maxDuration;
  nft.nftPrice = event.params.nftPrice;
  nft.borrower = null;
  nft.borrowedAt = BigInt.fromI32(0);
  nft.actualDuration = BigInt.fromI32(0);
  nft.face = id.toHex();

  let lender = User.load(event.params.lender.toHex());
  if (lender == null) {
    lender = new User(event.params.lender.toHex());
    lender.lending = new Array<string>();
    lender.borrowing = new Array<string>();
    lender.approvals = new Array<string>();
    lender.approvedAll = new Array<string>();
  }

  let lending = lender.lending;
  lending.push(nft.id);
  lender.lending = lending;

  nft.save();
  lender.save();
}

export function handleBorrowed(event: Borrowed): void {
  const id = event.params.tokenId;
  const nft = Nft.load(id.toHex());

  nft.actualDuration = event.params.actualDuration;
  nft.borrowedAt = event.params.borrowedAt;
  nft.borrower = event.params.borrower;

  let borrower = User.load(event.params.borrower.toHex());
  if (borrower == null) {
    borrower = new User(event.params.borrower.toHex());
    borrower.lending = new Array<string>();
    borrower.borrowing = new Array<string>();
    borrower.approvals = new Array<string>();
    borrower.approvedAll = new Array<string>();
  }

  let borrowing = borrower.borrowing;
  borrowing.push(nft.id);
  borrower.borrowing = borrowing;

  borrower.borrowing.push(nft.id);

  nft.save();
  borrower.save();
}

export function handleReturned(event: Returned): void {
  const id = event.params.tokenId;
  const nft = Nft.load(id.toHex());

  nft.actualDuration = BigInt.fromI32(0);
  nft.borrower = null;
  nft.borrowedAt = BigInt.fromI32(0);

  nft.save();
}

// gan face contract
export function handleNewFace(event: NewFace): void {
  const id = event.params.tokenId;
  const face = new Face(id.toHex());
  face.uri = event.params.tokenURI;
  face.save();

  let user = User.load(event.params.owner.toHex());
  if (user == null) {
    user = new User(event.params.owner.toHex());
    user.lending = new Array<string>();
    user.borrowing = new Array<string>();
    user.faces = new Array<string>();
    user.approvals = new Array<string>();
    user.approvedAll = new Array<string>();
  }
  let faces = user.faces;
  faces.push(face.id);
  user.faces = faces;

  user.save();
}

export function handleApproval(event: ApprovalEvent): void {
  const nftOwner = event.params.owner;
  const approved = event.params.approved;
  const tokenId = event.params.tokenId;

  const id = nftOwner.toHex().concat(approved.toHex()).concat(tokenId.toHex());
  const approval = new ApprovalSchema(id);

  approval.owner = nftOwner;
  approval.approved = approved;
  approval.tokenId = tokenId;
  approval.save();

  // now update the user if exists. If not, create them
  let user = User.load(nftOwner.toHex());
  if (user == null) {
    user = new User(nftOwner.toHex());
    user.lending = new Array<string>();
    user.borrowing = new Array<string>();
    user.faces = new Array<string>();
    user.approvals = new Array<string>();
    user.approvedAll = new Array<string>();
  }

  user.approvals.push(approval.id);
  user.save();
}

export function handleApprovalForAll(event: ApprovalForAll): void {
  const nftOwner = event.params.owner;
  const approved = event.params.operator;

  const id = nftOwner.toHex().concat(approved.toHex());

  const approvedAll = new ApprovedAll(id);
  approvedAll.owner = nftOwner;
  approvedAll.approved = approved;

  approvedAll.save();

  let user = User.load(nftOwner.toHex());
  if (user == null) {
    user = new User(nftOwner.toHex());
    user.lending = new Array<string>();
    user.borrowing = new Array<string>();
    user.faces = new Array<string>();
    user.approvals = new Array<string>();
    user.approvedAll = new Array<string>();
  }

  user.approvedAll.push(approvedAll.id);

  user.save();
}
