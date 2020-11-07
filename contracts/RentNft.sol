// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";

import "./RentNftAddressProvider.sol";

contract RentNftV2 is ReentrancyGuard, Ownable, ERC721Holder {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // TODO: if there are defaults, mark the address to forbid from renting
  event Lent(
    uint256 lentIndex,
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed lender,
    uint256 maxDuration,
    uint256 dailyPrice,
    uint256 nftPrice
  );

  event Borrowed(
    uint256 rentIndex,
    address indexed nftAddress,
    uint256 indexed tokenId,
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

  struct Listing {
    address lender;
    address nftAddress;
    uint256 tokenId;
    uint256 maxDuration; // max borrow duration in days
    uint256 dailyPrice; // how much the borrower has to pay irrevocably daily (per nft)
    uint256 nftPrice; // how much lender will receive as collateral if borrower does not return nft in time
    bool isRented;
  }
  Listing[] public listings;

  struct Rental {
    address borrower;
    uint256 listingIndex; // corresponding index in listings
    uint256 actualDuration; // actual duration borrower will have the NFT for
    uint256 borrowedAt; // time at which nft is borrowed
  }
  Rental[] public rentals;

  RentNftAddressProvider public resolver;

  constructor(address _resolverAddress) public {
    resolver = RentNftAddressProvider(_resolverAddress);
  }

  // lend one nft that you own to be borrowable on Rent NFT
  function lendOne(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _maxDuration,
    uint256 _dailyPrice,
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
        dailyPrice: _dailyPrice,
        nftPrice: _nftPrice,
        isRented: false
      })
    );
    emit Lent(
      // getting the newly added lent index
      listings.length.sub(1),
      _nftAddress,
      _tokenId,
      msg.sender,
      _maxDuration,
      _dailyPrice,
      _nftPrice
    );
  }

  // lend multiple nfts that you own to be borrowable by Rent NFT
  // for gas saving
  function lendMultiple(
    address[] calldata _nftAddresses,
    uint256[] calldata _tokenIds,
    uint256[] calldata _maxDurations,
    uint256[] calldata _dailyPrice,
    uint256[] calldata _nftPrices
  ) external {
    require(_nftAddresses.length == _tokenIds.length, "not equal length");
    require(_tokenIds.length == _maxDurations.length, "not equal length");
    require(_maxDurations.length == _dailyPrice.length, "not equal length");
    require(_dailyPrice.length == _nftPrices.length, "not equal length");

    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      lendOne(
        _nftAddresses[i],
        _tokenIds[i],
        _maxDurations[i],
        _dailyPrice[i],
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
    require(!listing.isRented, "nft already rented");
    require(_borrower != listing.lender, "can't borrow own nft");
    require(_actualDuration <= listing.maxDuration, "max duration exceeded");

    // ! will fail if wasn't approved
    // pay the NFT owner the rent price
    uint256 rentPrice = _actualDuration.mul(listing.dailyPrice);
    IERC20(resolver.getDai()).safeTransferFrom(
      _borrower,
      listing.lender,
      rentPrice
    );
    // collateral, our contracts acts as an escrow
    IERC20(resolver.getDai()).safeTransferFrom(
      _borrower,
      address(this),
      listing.nftPrice
    );

    // save details
    listing.isRented = true;
    rentals.push(
      Rental({
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
      // getting the newly added rent index
      rentals.length.sub(1),
      listing.nftAddress,
      listing.tokenId,
      _borrower,
      listing.lender,
      now,
      listing.dailyPrice,
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
    Rental storage rental = rentals[_rentalIndex];
    Listing storage listing = listings[rental.listingIndex];

    require(rental.borrower == msg.sender, "not borrower");
    uint256 durationInDays = now.sub(rental.borrowedAt).div(86400);
    require(durationInDays <= rental.actualDuration, "duration exceeded");

    // we are returning back to the contract so that the owner does not have to add
    // it multiple times thus incurring the transaction costs
    IERC721(listing.nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      listing.tokenId
    );

    // update details
    listing.isRented = false;

    // send collateral back for the qty of NFTs returned
    IERC20(resolver.getDai()).safeTransfer(msg.sender, listing.nftPrice);
    emit Returned(
      rental.listingIndex,
      _rentalIndex,
      listing.nftAddress,
      listing.tokenId,
      msg.sender,
      rental.borrower
    );
  }

  function returnNftMultiple(uint256[] calldata _rentalIndexes) external {
    for (uint256 i = 0; i < _rentalIndexes.length; i++) {
      returnNftOne(_rentalIndexes[i]);
    }
  }

  function claimCollateral(uint256 _rentalIndex) public nonReentrant {
    Rental storage rental = rentals[_rentalIndex];
    Listing storage listing = listings[rental.listingIndex];

    require(listing.lender == msg.sender, "not lender");
    require(!listing.isRented, "nft not lent out");

    uint256 durationInDays = now.sub(rental.borrowedAt).div(86400);
    require(durationInDays > rental.actualDuration, "duration not exceeded");

    IERC20(resolver.getDai()).safeTransfer(msg.sender, listing.nftPrice);
  }

  function stopLending(uint256 _listingIndex) public {
    Listing storage listing = listings[_listingIndex];

    require(listing.lender == msg.sender, "not lender");
    require(!listing.isRented, "nft rented out currently");

    IERC721(listing.nftAddress).safeTransferFrom(
      address(this),
      listing.lender,
      listing.tokenId
    );
  }

  function getListingCount() external view returns (uint256) {
    return listings.length;
  }

  function getRentalCount() external view returns (uint256) {
    return rentals.length;
  }
}
