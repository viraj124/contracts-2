// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";

import "./RentNftAddressProvider.sol";

contract RentNft is ReentrancyGuard, Ownable, ERC721Holder {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // TODO: if there are defaults, mark the address to forbid from borrowing
  event Lent(
    uint256 lentIndex,
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed lender,
    uint256 maxDuration,
    uint256 dailyBorrowPrice,
    uint256 nftPrice
  );

  event Borrowed(
    uint256 rentIndex,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 lentIndex,
    address indexed borrower,
    address lender,
    uint256 borrowedAt,
    uint256 borrowPrice,
    uint256 actualDuration,
    uint256 nftPrice
  );

  event Returned(
    uint256 lentIndex,
    uint256 rentIndex,
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed borrower,
    address lender
  );

  // required to avoid the contract level bug
  // Address A lends their NFT
  // Address B borrows the NFT and immediately lends it
  // previously, the collateral would be locked from address A
  // as address B's actions would overwrite the original lender
  struct Listing {
    address lender;
    address nftAddress;
    uint256 tokenId;
    uint256 maxDuration; // max borrow duration in days
    uint256 dailyBorrowPrice; // how much the borrower has to pay irrevocably daily (per nft)
    uint256 nftPrice; // how much lender will receive as collateral if borrower does not return nft in time
    bool isBorrowed;
  }
  Listing[] public listings;

  struct Borrow {
    address borrower;
    uint256 listingIndex; // corresponding index in listings
    uint256 actualDuration; // actual duration borrower will have the NFT for
    uint256 borrowedAt; // time at which nft is borrowed
  }
  Borrow[] public borrows;

  RentNftAddressProvider public resolver;

  constructor(address _resolverAddress) public {
    resolver = RentNftAddressProvider(_resolverAddress);
  }

  // lend one nft that you own to be borrowable on Rent NFT
  function lendOne(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _maxDuration,
    uint256 _dailyBorrowPrice,
    uint256 _nftPrice
  ) public nonReentrant {
    require(_nftAddress != address(0), "invalid nft address");
    require(_maxDuration > 0, "at least one day");

    // transfer nft to this contract. will fail if nft wasn't approved

    IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);

    listings.push(
      Listing({
        lender: msg.sender,
        nftAddress: _nftAddress,
        tokenId: _tokenId,
        maxDuration: _maxDuration,
        dailyBorrowPrice: _dailyBorrowPrice,
        nftPrice: _nftPrice,
        isBorrowed: false
      })
    );
    emit Lent(
      // getting the newly added lent index
      listings.length.sub(1),
      _nftAddress,
      _tokenId,
      msg.sender,
      _maxDuration,
      _dailyBorrowPrice,
      _nftPrice
    );
  }

  // lend multiple nfts that you own to be borrowable by Rent NFT
  // for gas saving
  function lendMultiple(
    address[] calldata _nftAddresses,
    uint256[] calldata _tokenIds,
    uint256[] calldata _maxDurations,
    uint256[] calldata _dailyBorrowPrice,
    uint256[] calldata _nftPrices
  ) external {
    require(_nftAddresses.length == _tokenIds.length, "not equal length");
    require(_tokenIds.length == _maxDurations.length, "not equal length");
    require(
      _maxDurations.length == _dailyBorrowPrice.length,
      "not equal length"
    );
    require(_dailyBorrowPrice.length == _nftPrices.length, "not equal length");

    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      lendOne(
        _nftAddresses[i],
        _tokenIds[i],
        _maxDurations[i],
        _dailyBorrowPrice[i],
        _nftPrices[i]
      );
    }
  }

  function rentOne(
    address _borrower,
    uint256 _listingIndex,
    uint256 _actualDuration
  ) public nonReentrant {
    Listing storage listing = listings[_listingIndex];
    require(listing.lender != address(0), "could not find an nft");
    require(!listing.isBorrowed, "nft already borrowed");
    require(_borrower != listing.lender, "can't borrow own nft");
    require(_actualDuration <= listing.maxDuration, "max duration exceeded");

    // ! will fail if wasn't approved
    // pay the NFT owner the borrow price
    uint256 borrowPrice = _actualDuration.mul(listing.dailyBorrowPrice);
    IERC20(resolver.getDai()).safeTransferFrom(
      _borrower,
      listing.lender,
      borrowPrice
    );
    // collateral, our contracts acts as an escrow
    IERC20(resolver.getDai()).safeTransferFrom(
      _borrower,
      address(this),
      listing.nftPrice
    );

    // save details
    listing.isBorrowed = true;
    borrows.push(
      Borrow({
        borrower: _borrower,
        listingIndex: _listingIndex,
        actualDuration: _actualDuration,
        borrowedAt: now
      })
    );

    // transfer NFT to borrower
    IERC721(listing.nftAddress).safeTransferFrom(
      address(this),
      _borrower,
      listing.tokenId
    );

    emit Borrowed(
      // getting the newly added borrow index
      borrows.length.sub(1),
      listing.nftAddress,
      listing.tokenId,
      _listingIndex,
      _borrower,
      listing.lender,
      now,
      listing.dailyBorrowPrice,
      _actualDuration,
      listing.nftPrice
    );
  }

  function rentMultiple(
    address _borrower,
    uint256[] calldata _listingIndexes,
    uint256[] calldata _actualDurations
  ) external {
    require(
      _listingIndexes.length == _actualDurations.length,
      "not equal length"
    );

    for (uint256 i = 0; i < _listingIndexes.length; i++) {
      rentOne(_borrower, _listingIndexes[i], _actualDurations[i]);
    }
  }

  // return NFT back
  function returnNftOne(uint256 _rentalIndex) public nonReentrant {
    Borrow storage borrow = borrows[_rentalIndex];
    Listing storage listing = listings[borrow.listingIndex];

    require(borrow.borrower == msg.sender, "not borrower");
    uint256 durationInDays = now.sub(borrow.borrowedAt).div(86400);
    require(durationInDays <= borrow.actualDuration, "duration exceeded");

    // we are returning back to the contract so that the owner does not have to add
    // it multiple times thus incurring the transaction costs
    IERC721(listing.nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      listing.tokenId
    );

    // update details
    listing.isBorrowed = false;
    delete borrow.borrower;
    delete borrow.listingIndex;
    delete borrow.actualDuration;
    delete borrow.borrowedAt;

    // send collateral back for the qty of NFTs returned
    IERC20(resolver.getDai()).safeTransfer(msg.sender, listing.nftPrice);
    emit Returned(
      borrow.listingIndex,
      _rentalIndex,
      listing.nftAddress,
      listing.tokenId,
      msg.sender,
      borrow.borrower
    );
  }

  function returnNftMultiple(uint256[] calldata _rentalIndexes) external {
    for (uint256 i = 0; i < _rentalIndexes.length; i++) {
      returnNftOne(_rentalIndexes[i]);
    }
  }

  function claimCollateral(uint256 _rentalIndex) public nonReentrant {
    Borrow storage borrow = borrows[_rentalIndex];
    Listing storage listing = listings[borrow.listingIndex];

    require(listing.lender == msg.sender, "not lender");
    require(listing.isBorrowed, "nft not lent out");

    uint256 durationInDays = now.sub(borrow.borrowedAt).div(86400);
    require(durationInDays > borrow.actualDuration, "duration not exceeded");

    IERC20(resolver.getDai()).safeTransfer(msg.sender, listing.nftPrice);
  }

  function stopLending(uint256 _listingIndex) public {
    Listing storage listing = listings[_listingIndex];

    require(listing.lender == msg.sender, "not lender");
    require(!listing.isBorrowed, "nft borrowed currently");

    IERC721(listing.nftAddress).safeTransferFrom(
      address(this),
      listing.lender,
      listing.tokenId
    );

    delete listing.lender;
    delete listing.nftAddress;
    delete listing.tokenId;
    delete listing.maxDuration;
    delete listing.dailyBorrowPrice;
    delete listing.nftPrice;
  }

  function getListingCount() external view returns (uint256) {
    return listings.length;
  }

  function getBorrowCount() external view returns (uint256) {
    return borrows.length;
  }
}
