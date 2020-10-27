import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
    Lent,
    Borrowed,
    Returned
} from "./generated/RentNft/RentNft"
import {
    NewFace
} from "./generated/GanFaceNft/GanFaceNft"
import { Nft, User } from "./generated/schema"

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

    let lender = User.load(event.params.lender.toHex());
    if (lender == null) {
        lender = new User(event.params.lender.toHex());
        lender.lending = new Array<string>();
        lender.borrowing = new Array<string>();
        lender.faces = new Array<BigInt>();
    }
    lender.lending.push(nft.id);
    lender.faces.push(id);

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
        borrower.faces = new Array<BigInt>();
    }
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

export function handleNewFace(event: NewFace): void {
    const id = event.params.tokenId;
    const nft = Nft.load(id.toHex());

    nft.faceUri = event.params.tokenURI;

    let user = User.load(event.params.owner.toHex());
    if (user == null) {
        user = new User(event.params.owner.toHex());
        user.lending = new Array<string>();
        user.borrowing = new Array<string>();
        user.faces = new Array<BigInt>();
    }
    user.faces.push(id);

    nft.save();
    user.save();
}
