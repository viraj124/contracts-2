// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";

import "./RentNftResolver.sol";

contract RentNftV2 is ReentrancyGuard, Ownable, ERC721Holder, ERC1155Holder {
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
    uint256 nftPrice,
    // for erc 1155 for erc 721 will always be 1
    uint256 qty
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
    uint256 nftPrice,
    // for erc 1155 for erc 721 will always be 1
    uint256 qty
  );

  event Returned(
    uint256 lentIndex,
    uint256 rentIndex,
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed borrower,
    address lender,
    // for erc 1155 for erc 721 will always be 1
    uint256 qty
  );

  struct Listing {
    address lender;
    address nftAddress;
    uint256 tokenId;
    uint256 maxDuration; // max borrow duration in days
    uint256 dailyPrice; // how much the borrower has to pay irrevocably daily (per nft)
    uint256 nftPrice; // how much lender will receive as collateral if borrower does not return nft in time
    bool isERC1155; // else ERC721
    uint256 qtyLeft; // no. of NFTs left to be rented out. {max(qtyLeft) = 1 for ERC721}
    bool isRented;
  }
  Listing[] public listings;

  struct Rental {
    address borrower;
    uint256 listingIndex; // corresponding index in listings
    uint256 qty; // qty of NFTs borrowed
    uint256 actualDuration; // actual duration borrower will have the NFT for
    uint256 borrowedAt; // time at which nft is borrowed
  }
  Rental[] public rentals;

  RentNftResolver public resolver;

  constructor(address _resolverAddress) public {
    resolver = RentNftResolver(_resolverAddress);
  }

  // lend one nft (any qty) that you own to be borrowable on Rent NFT
  function lendOne(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _maxDuration,
    uint256 _dailyPrice,
    uint256 _nftPrice,
    bool _isERC1155,
    uint256 _totalQty
  ) public nonReentrant {
    require(_nftAddress != address(0), "invalid NFT address");
    require(_maxDuration > 0, "at least one day");

    uint256 qty = 1;
    // transfer nft to this contract. will fail if nft wasn't approved
    if (_isERC1155) {
      IERC1155(_nftAddress).safeTransferFrom(
        msg.sender,
        address(this),
        _tokenId,
        _totalQty,
        ""
      );
      qty = _totalQty;
    } else {
      IERC721(_nftAddress).safeTransferFrom(
        msg.sender,
        address(this),
        _tokenId
      );
    }

    listings.push(
      Listing({
        lender: msg.sender,
        nftAddress: _nftAddress,
        tokenId: _tokenId,
        maxDuration: _maxDuration,
        dailyPrice: _dailyPrice,
        nftPrice: _nftPrice,
        isERC1155: _isERC1155,
        qtyLeft: qty,
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
      _nftPrice,
      _totalQty
    );
  }

    // lend multiple nfts that you own to be borrowable by Rent NFT
  // for gas saving
  function lendMultiple(
    address[] calldata _nftAddresses,
    uint256[] calldata _tokenIds,
    uint256[] calldata _maxDurations,
    uint256[] calldata _dailyPrice,
    uint256[] calldata _nftPrices,
    bool[] calldata _isERC1155,
    uint256[] calldata _totalQty
  ) external {
    require(_nftAddresses.length == _tokenIds.length, "not equal length");
    require(_tokenIds.length == _maxDurations.length, "not equal length");
    require(_maxDurations.length == _dailyPrice.length, "not equal length");
    require(_dailyPrice.length == _nftPrices.length, "not equal length");
    require(_nftPrices.length == _isERC1155.length, "not equal length");
    require(_isERC1155.length == _totalQty.length, "not equal length");

    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      lendOne(
        _nftAddresses[i],
        _tokenIds[i],
        _maxDurations[i],
        _dailyPrice[i],
        _nftPrices[i],
        _isERC1155[i],
        _totalQty[i]
      );
    }
  }

  function rentOne(
    address _borrower,
    uint256 _listingIndex,
    uint256 _qtyToBorrow,
    uint256 _actualDuration
  ) public nonReentrant {
    Listing storage listing = listings[_listingIndex];
    // is NFT not listed, then too qtyLeft=0
    require(
      listing.qtyLeft >= _qtyToBorrow && _qtyToBorrow != 0,
      "Insuffient Qty"
    );
    require(_borrower != listing.lender, "can't borrow own nft");
    require(_actualDuration <= listing.maxDuration, "Max Duration exceeded");

    // ! will fail if wasn't approved
    // pay the NFT owner the rent price
    uint256 rentPrice = _actualDuration.mul(listing.dailyPrice).mul(
      _qtyToBorrow
    );
    IERC20(resolver.getDai()).safeTransferFrom(
      _borrower,
      listing.lender,
      rentPrice
    );
    // collateral, our contracts acts as an escrow
    IERC20(resolver.getDai()).safeTransferFrom(
      _borrower,
      address(this),
      listing.nftPrice.mul(_qtyToBorrow)
    );

    // save details
    listing.isRented = true;
    rentals.push(
      Rental({
        borrower: _borrower,
        listingIndex: _listingIndex,
        qty: _qtyToBorrow,
        actualDuration: _actualDuration,
        borrowedAt: now
      })
    );
    // deduct from total
    listing.qtyLeft = listing.qtyLeft.sub(_qtyToBorrow);

    // transfer NFT to borrower
    if (listing.isERC1155) {
      IERC1155(listing.nftAddress).safeTransferFrom(
        address(this),
        _borrower,
        listing.tokenId,
        _qtyToBorrow,
        ""
      );
    } else {
      IERC721(listing.nftAddress).safeTransferFrom(
        address(this),
        _borrower,
        listing.tokenId
      );
    }
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
      listing.nftPrice,
      _qtyToBorrow
    );
  }

  function rentMultiple(
    address _borrower,
    uint256[] calldata _listingIndexes,
    uint256[] calldata _qtysToBorrow,
    uint256[] calldata _actualDurations
  ) external {
    require(_listingIndexes.length == _qtysToBorrow.length, "not equal length");
    require(_qtysToBorrow.length == _actualDurations.length, "not equal length");
    for (uint256 i = 0; i < _listingIndexes.length; i++) {
      rentOne(_borrower, _listingIndexes[i], _qtysToBorrow[i], _actualDurations[i]);
    }
  }
  // return specific qty of NFTs back
  function returnNftOne(uint256 _rentalIndex, uint256 _qtyToReturn)
    public
    nonReentrant
  {
    Rental storage rental = rentals[_rentalIndex];
    Listing storage listing = listings[rental.listingIndex];

    require(rental.borrower == msg.sender, "not borrower");
    uint256 durationInDays = now.sub(rental.borrowedAt).div(86400);
    require(durationInDays <= rental.actualDuration, "duration exceeded");
    require(_qtyToReturn <= rental.qty, "excess qty");

    // we are returning back to the contract so that the owner does not have to add
    // it multiple times thus incurring the transaction costs
    uint256 qty = 1;
    if (listing.isERC1155) {
      IERC1155(listing.nftAddress).safeTransferFrom(
        msg.sender,
        address(this),
        listing.tokenId,
        _qtyToReturn,
        ""
      );
      qty = _qtyToReturn;
    } else {
      IERC721(listing.nftAddress).safeTransferFrom(
        msg.sender,
        address(this),
        listing.tokenId
      );
    }

    // update details
    rental.qty = rental.qty.sub(qty);
    // add back to total
    listing.qtyLeft = listing.qtyLeft.add(qty);
    listing.isRented = false;

    // send collateral back for the qty of NFTs returned
    IERC20(resolver.getDai()).safeTransfer(
      msg.sender,
      listing.nftPrice.mul(qty)
    );
    emit Returned(rental.listingIndex, _rentalIndex, listing.nftAddress, listing.tokenId, msg.sender, rental.borrower, _qtyToReturn);
  }

    function returnNftMultiple(uint256[] calldata _rentalIndexes, uint256[] calldata _tokenIds) external {
    require(_rentalIndexes.length == _tokenIds.length, "not equal length");
    for (uint256 i = 0; i < _rentalIndexes.length; i++) {
      returnNftOne(_rentalIndexes[i], _tokenIds[i]);
    }
  }

  function claimCollateral(uint256 _rentalIndex) public nonReentrant {
    Rental storage rental = rentals[_rentalIndex];
    Listing storage listing = listings[rental.listingIndex];

    require(listing.lender == msg.sender, "not lender");
    require(rental.qty > 0, "nft not lent out");

    uint256 durationInDays = now.sub(rental.borrowedAt).div(86400);
    require(durationInDays > rental.actualDuration, "duration not exceeded");

    IERC20(resolver.getDai()).safeTransfer(
      msg.sender,
      listing.nftPrice.mul(rental.qty)
    );
  }

  function stopLending(uint256 _listingIndex) public {
    Listing storage listing = listings[_listingIndex];

    require(listing.lender == msg.sender, "not lender");
    require(!listing.isRented, "nft rented out currently");
    if (listing.isERC1155) {
      IERC1155(listing.nftAddress).safeTransferFrom(
        address(this),
        listing.lender,
        listing.tokenId,
        listing.qtyLeft,
        ""
      );
    } else {
      // if NFT lent out, then this will revert:
      IERC721(listing.nftAddress).safeTransferFrom(
        address(this),
        listing.lender,
        listing.tokenId
      );
    }
  }

  function getListingCount() external view returns (uint256) {
    return listings.length;
  }

  function getRentalCount() external view returns (uint256) {
    return rentals.length;
  }
}
