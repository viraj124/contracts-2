// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract RentNft is ReentrancyGuard, Ownable, ERC721Holder {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using Counters for Counters.Counter;

  event Lent(
    uint256 lendingId,
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed lenderAddress,
    uint256 maxBorrowDuration,
    uint256 dailyBorrowPrice,
    uint256 nftPrice
  );

  event Borrowed(
    uint256 borrowingId,
    uint256 indexed lendingId,
    address indexed borrowerAddress,
    uint256 borrowDuration,
    uint256 borrowedAt
  );

  event Returned(
    uint256 lendingId,
    uint256 borrowingId,
    address indexed nftAddress,
    uint256 indexed tokenId
  );

  // required to avoid the contract level bug
  // Address A lends their NFT
  // Address B borrows the NFT and immediately lends it
  // previously, the collateral would be locked from address A
  // as address B's actions would overwrite the original lender
  struct Lending {
    uint256 lendingId;
    address lenderAddress;
    address nftAddress;
    uint256 tokenId;
    uint256 maxBorrowDuration; // max borrow duration in days
    uint256 dailyBorrowPrice; // how much the borrower has to pay irrevocably daily (per nft)
    uint256 nftPrice; // how much lender will receive as collateral if borrower does not return nft in time
    address paymentTokenAddress;
    bool isBorrowed;
  }
  mapping(uint256 => Lending) public lendings;

  struct Borrowing {
    uint256 borrowingId;
    address borrowerAddress;
    uint256 lendingId; // corresponding index in lendings
    uint256 borrowDuration; // actual duration borrower will have the NFT for
    uint256 borrowedAt; // time at which nft is borrowed
  }
  mapping(uint256 => Borrowing) public borrowings;

  constructor() {}

  // lend one nft that you own to be borrowable on Rent NFT
  function lendOne(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _maxBorrowDuration,
    uint256 _dailyBorrowPrice,
    uint256 _nftPrice,
    address _paymentToken
  ) public nonReentrant {
    require(_nftAddress != address(0), "invalid nft address");
    require(_maxBorrowDuration > 0, "at least one day");

    // transfer nft to this contract. will fail if nft wasn't approved

    IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);

    uint256 lendingId = lendings.length + 1;

    lendings.push(
      Lending({
        lendingId: lendingId,
        lenderAddress: msg.sender,
        nftAddress: _nftAddress,
        tokenId: _tokenId,
        maxBorrowDuration: _maxBorrowDuration,
        dailyBorrowPrice: _dailyBorrowPrice,
        nftPrice: _nftPrice,
        paymentToken: _paymentToken,
        isBorrowed: false
      })
    );
    emit Lent(
      lendingId,
      _nftAddress,
      _tokenId,
      msg.sender,
      _maxBorrowDuration,
      _dailyBorrowPrice,
      _nftPrice
    );
  }

  // lend multiple nfts that you own to be borrowable by Rent NFT
  // for gas saving
  function lendMultiple(
    address[] calldata _nftAddresses,
    uint256[] calldata _tokenIds,
    uint256[] calldata _maxBorrowDurations,
    uint256[] calldata _dailyBorrowPrice,
    uint256[] calldata _nftPrices,
    address[] calldata _tokens
  ) external {
    require(_nftAddresses.length == _tokenIds.length, "not equal length");
    require(_tokenIds.length == _maxBorrowDurations.length, "not equal length");
    require(
      _maxBorrowDurations.length == _dailyBorrowPrice.length,
      "not equal length"
    );
    require(_dailyBorrowPrice.length == _nftPrices.length, "not equal length");
    require(_nftPrices.length == _tokens.length, "not equal length");

    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      lendOne(
        _nftAddresses[i],
        _tokenIds[i],
        _maxBorrowDurations[i],
        _dailyBorrowPrice[i],
        _nftPrices[i],
        _tokens[i]
      );
    }
  }

  function borrowOne(
    address _borrowerAddress,
    uint256 _lendingId,
    uint256 _borrowDuration
  ) public nonReentrant {
    Lending storage lending = lendings[_lendingId];
    require(lending.lenderAddress != address(0), "could not find an nft");
    require(!lending.isBorrowed, "nft already borrowed");
    require(_borrowerAddress != lending.lenderAddress, "can't borrow own nft");
    require(_borrowDuration <= lending.maxBorrowDuration, "max duration exceeded");

    // ! will fail if wasn't approved
    // pay the NFT owner the borrow price
    uint256 borrowPrice = _borrowDuration.mul(lending.dailyBorrowPrice);
    IERC20(lending.paymentTokenAddress).safeTransferFrom(
      _borrowerAddress,
      lending.lenderAddress,
      borrowPrice
    );
    // collateral, our contracts acts as an escrow
    IERC20(lending.paymentTokenAddress).safeTransferFrom(
      _borrowerAddress,
      address(this),
      lending.nftPrice
    );

    uint256 borrowedAt = block.timestamp;
    uint256 borrowingId = borrowings.length + 1;

    // save details
    lending.isBorrowed = true;
    borrowings.push(
      Borrowing({
        borrowingId: borrowingId,
        borrowerAddress: _borrowerAddress,
        lendingId: _lendingId,
        borrowDuration: _borrowDuration,
        borrowedAt: borrowedAt
      })
    );

    // transfer NFT to borrower
    IERC721(lending.nftAddress).safeTransferFrom(
      address(this),
      _borrowerAddress,
      lending.tokenId
    );

    emit Borrowed(
      borrowingId,
      lending.lendingId,
      _borrowerAddress,
      _borrowDuration,
      borrowedAt
    );
  }

  function borrowMultiple(
    address _borrowerAddress,
    uint256[] calldata _lendingIds,
    uint256[] calldata _borrowDurations
  ) external {
    require(
      _lendingIds.length == _borrowDurations.length,
      "not equal length"
    );

    for (uint256 i = 0; i < _lendingIds.length; i++) {
      borrowOne(_borrowerAddress, _lendingIds[i], _borrowDurations[i]);
    }
  }

  function returnOne(uint256 _borrowingId) public nonReentrant {
    Borrowing storage borrowing = borrowings[_borrowingId];
    Lending storage lending = lendings[borrowing.lendingId];

    require(borrowing.borrowerAddress == msg.sender, "not borrower");
    uint256 durationInDays = block.timestamp.sub(borrowing.borrowedAt).div(86400);
    require(durationInDays <= borrowing.borrowDuration, "duration exceeded");

    // we are returning back to the contract so that the owner does not have to add
    // it multiple times thus incurring the transaction costs
    IERC721(lending.nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      lending.tokenId
    );

    // update details
    lending.isBorrowed = false;
    delete borrowing.borrowerAddress;
    delete borrowing.lendingId;
    delete borrowing.borrowDuration;
    delete borrowing.borrowedAt;

    // send collateral back for the qty of NFTs returned
    IERC20(lending.paymentTokenAddress).safeTransfer(msg.sender, lending.nftPrice);
    emit Returned(
      borrowing.lendingId,
      _borrowingId,
      lending.nftAddress,
      lending.tokenId
    );
  }

  function returnMultiple(uint256[] calldata _borrowingIds) external {
    for (uint256 i = 0; i < _borrowingIds.length; i++) {
      returnOne(_borrowingIds[i]);
    }
  }

  function claimCollateral(uint256 _borrowingId) public nonReentrant {
    Borrowing storage borrowing = borrowings[_borrowingId];
    Lending storage lending = lendings[borrowing.lendingId];

    require(lending.lenderAddress == msg.sender, "not lender");
    require(lending.isBorrowed, "nft not borrowed out");

    uint256 durationInDays = block.timestamp.sub(borrowing.borrowedAt).div(86400);
    require(durationInDays > borrowing.borrowDuration, "duration not exceeded");

    IERC20(lending.paymentTokenAddress).safeTransfer(msg.sender, lending.nftPrice);
  }

  function stopLending(uint256 _lendingId) public {
    Lending storage lending = lendings[_lendingId];

    require(lending.lenderAddress == msg.sender, "not lender");
    require(!lending.isBorrowed, "nft borrowed currently");

    IERC721(lending.nftAddress).safeTransferFrom(
      address(this),
      lending.lenderAddress,
      lending.tokenId
    );

    delete lendings[_lendingId];
  }

  function getLendingLength() external view returns (uint256) {
    return lendings.length;
  }

  function getBorrowingLength() external view returns (uint256) {
    return borrowings.length;
  }
}
