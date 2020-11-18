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

  uint256 private SECONDS_IN_A_DAY = 86400;

  event Lent(
    uint256 id,
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed lenderAddress,
    uint256 maxRentDuration,
    uint256 dailyRentPrice,
    uint256 nftPrice,
    address paymentTokenAddress
  );

  event Rented(
    uint256 id,
    uint256 indexed lendingId,
    address indexed renterAddress,
    uint256 rentDuration,
    uint256 rentedAt
  );

  event Returned(
    uint256 lendingId,
    uint256 rentingId,
    address indexed nftAddress,
    uint256 indexed tokenId
  );

  struct Lending {
    address lenderAddress;
    address nftAddress;
    uint256 tokenId;
    uint256 maxRentDuration; // in days
    uint256 dailyRentPrice; // how much the renter has to pay irrevocably daily (per nft)
    uint256 nftPrice; // how much lender will receive as collateral if renter does not return the nft in time
    address paymentTokenAddress;
    uint256 isRented; // uint256 so that we know how many times this has been re-lent
  }

  struct Renting {
    uint256 lendingId;
    address renterAddress;
    uint256 rentDuration; // actual duration renter will have the NFT for
    uint256 rentedAt;
  }

  mapping(uint256 => Lending) private lendings;
  mapping(uint256 => Renting) private rentings;

  Counters.Counter private lastLendingId = Counters.Counter({_value: 1});
  Counters.Counter private lastRentingId = Counters.Counter({_value: 1});

  function lendOne(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _maxRentDuration,
    uint256 _dailyRentPrice,
    uint256 _nftPrice,
    address _paymentTokenAddress
  ) public nonReentrant {
    require(_nftAddress != address(0), "invalid nft address");
    require(_maxRentDuration > 0, "at least one day");

    IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);

    uint256 __lastLendingId = lastLendingId.current();

    lendings[__lastLendingId] = Lending({
      lenderAddress: msg.sender,
      nftAddress: _nftAddress,
      tokenId: _tokenId,
      maxRentDuration: _maxRentDuration,
      dailyRentPrice: _dailyRentPrice,
      nftPrice: _nftPrice,
      paymentTokenAddress: _paymentTokenAddress,
      isRented: 0
    });

    emit Lent(
      __lastLendingId,
      _nftAddress,
      _tokenId,
      msg.sender,
      _maxRentDuration,
      _dailyRentPrice,
      _nftPrice,
      _paymentTokenAddress
    );

    lastLendingId.increment();
  }

  function lendMultiple(
    address[] calldata _nftAddresses,
    uint256[] calldata _tokenIds,
    uint256[] calldata _maxRentDurations,
    uint256[] calldata _dailyRentPrice,
    uint256[] calldata _nftPrices,
    address[] calldata _paymentTokenAddresses
  ) external {
    require(_nftAddresses.length == _tokenIds.length, "not equal length");
    require(_tokenIds.length == _maxRentDurations.length, "not equal length");
    require(
      _maxRentDurations.length == _dailyRentPrice.length,
      "not equal length"
    );
    require(_dailyRentPrice.length == _nftPrices.length, "not equal length");
    require(
      _nftPrices.length == _paymentTokenAddresses.length,
      "not equal length"
    );

    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      lendOne(
        _nftAddresses[i],
        _tokenIds[i],
        _maxRentDurations[i],
        _dailyRentPrice[i],
        _nftPrices[i],
        _paymentTokenAddresses[i]
      );
    }
  }

  function rentOne(
    address _renterAddress,
    uint256 _lendingId,
    uint256 _rentDuration
  ) public nonReentrant {
    Lending storage lending = lendings[_lendingId];
    require(lending.lenderAddress != address(0), "could not find an nft");
    require(lending.isRented == 0, "nft already rented");
    require(_renterAddress != lending.lenderAddress, "can't rent own nft");
    require(_rentDuration <= lending.maxRentDuration, "max duration exceeded");

    // TODO: this should go to the contract as an escrow
    // on return, or on collateral claim, we either give
    // the lender the portion of the amounts, or all of them
    uint256 rentPrice = _rentDuration.mul(lending.dailyRentPrice);
    IERC20(lending.paymentTokenAddress).safeTransferFrom(
      _renterAddress,
      lending.lenderAddress,
      rentPrice
    );
    IERC20(lending.paymentTokenAddress).safeTransferFrom(
      _renterAddress,
      address(this),
      lending.nftPrice
    );

    uint256 rentedAt = block.timestamp;
    uint256 __lastRentingId = lastRentingId.current();

    lending.isRented = lending.isRented + 1;
    rentings[__lastRentingId] = Renting({
      renterAddress: _renterAddress,
      lendingId: _lendingId,
      rentDuration: _rentDuration,
      rentedAt: rentedAt
    });

    IERC721(lending.nftAddress).safeTransferFrom(
      address(this),
      _renterAddress,
      lending.tokenId
    );

    emit Rented(
      __lastRentingId,
      _lendingId,
      _renterAddress,
      _rentDuration,
      rentedAt
    );

    lastRentingId.increment();
  }

  function rentMultiple(
    address _renterAddress,
    uint256[] calldata _lendingIds,
    uint256[] calldata _rentDurations
  ) external {
    require(_lendingIds.length == _rentDurations.length, "not equal length");

    for (uint256 i = 0; i < _lendingIds.length; i++) {
      rentOne(_renterAddress, _lendingIds[i], _rentDurations[i]);
    }
  }

  function returnOne(uint256 _rentingId) public nonReentrant {
    Renting storage renting = rentings[_rentingId];
    Lending storage lending = lendings[renting.lendingId];

    require(lending.isRented > 0, "is not rented");
    require(renting.renterAddress == msg.sender, "not renter");
    uint256 durationInDays = block.timestamp.sub(renting.rentedAt).div(
      SECONDS_IN_A_DAY
    );
    require(durationInDays <= renting.rentDuration, "duration exceeded");

    // update details
    lending.isRented = lending.isRented - 1;
    delete rentings[_rentingId];

    // we are returning back to the contract so that the owner does not have to add
    // it multiple times thus incurring the transaction costs
    IERC721(lending.nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      lending.tokenId
    );
    IERC20(lending.paymentTokenAddress).safeTransfer(
      msg.sender,
      lending.nftPrice
    );

    emit Returned(
      renting.lendingId,
      _rentingId,
      lending.nftAddress,
      lending.tokenId
    );
  }

  function returnMultiple(uint256[] calldata _rentingIds) external {
    for (uint256 i = 0; i < _rentingIds.length; i++) {
      returnOne(_rentingIds[i]);
    }
  }

  function claimCollateral(uint256 _rentingId) public nonReentrant {
    Renting storage renting = rentings[_rentingId];
    Lending storage lending = lendings[renting.lendingId];

    require(lending.lenderAddress == msg.sender, "not lender");
    require(lending.isRented > 0, "nft not rented out");

    uint256 durationInDays = block.timestamp.sub(renting.rentedAt).div(
      SECONDS_IN_A_DAY
    );
    require(durationInDays > renting.rentDuration, "duration not exceeded");

    IERC20(lending.paymentTokenAddress).safeTransfer(
      msg.sender,
      lending.nftPrice
    );

    lending.isRented = lending.isRented - 1;
  }

  function stopLending(uint256 _lendingId) public {
    Lending storage lending = lendings[_lendingId];

    require(lending.lenderAddress == msg.sender, "not lender");
    require(lending.isRented == 0, "nft rented currently");

    IERC721(lending.nftAddress).safeTransferFrom(
      address(this),
      lending.lenderAddress,
      lending.tokenId
    );

    delete lendings[_lendingId];
  }
}
