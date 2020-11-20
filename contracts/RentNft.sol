// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "./ChiGasSaver.sol";
import "./Resolver.sol";

contract RentNft is ReentrancyGuard, Ownable, ERC721Holder, ChiGasSaver {
  using SafeERC20 for IERC20;

  // 256 bits -> 32 bytes
  // address - 20 byte value -> 160 bits
  uint32 private constant SECONDS_IN_A_DAY = 86400;
  uint256 private id = 1;
  Resolver private resolver;

  event Lent(
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed lenderAddress,
    uint256 id,
    uint16 maxRentDuration,
    uint32 dailyRentPrice,
    uint32 nftPrice,
    PaymentToken paymentToken
  );

  event Rented(
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed renterAddress,
    uint16 rentDuration,
    uint32 rentedAt
  );

  event Returned(
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed renterAddress,
    uint256 lendingId
  );

  struct Lending {
    // 160 bits
    address lenderAddress;
    // 176 bits
    uint16 maxRentDuration;
    // 208 bits
    uint32 dailyRentPrice;
    // 240 bits
    uint32 nftPrice;
    // 248 bits
    PaymentToken paymentToken;
  }

  struct Renting {
    // 160 bits
    address renterAddress;
    // 176 bits
    uint16 rentDuration;
    // 198 bits
    uint32 rentedAt;
  }

  struct LendingRenting {
    Lending lending;
    Renting renting;
  }

  enum PaymentToken {
    DAI, // 0
    USDC, // 1
    USDT, // 2
    TUSD, // 3
    ETH, // 4
    UNI, // 5
    YFI, // 6
    NAZ // 7
  }

  // 32 bytes key to 64 bytes struct
  mapping(bytes32 => LendingRenting) private lendingRenting;

  constructor(Resolver _resolver) {
    resolver = _resolver;
  }

  function lendOne(
    IERC721 _nftAddress,
    uint256 _tokenId,
    uint16 _maxRentDuration,
    uint32 _dailyRentPrice,
    uint32 _nftPrice,
    PaymentToken _paymentToken,
    address payable _gasSponsor
  ) public nonReentrant {
    require(_maxRentDuration > 0, "at least one day");

    // edge-cases analysis
    // 1. if I have lent out and try to lend out again. fail: since the nft was already transferred

    // 120k gas ...
    _nftAddress.safeTransferFrom(msg.sender, address(this), _tokenId);

    LendingRenting storage item = lendingRenting[keccak256(
      abi.encodePacked(address(_nftAddress), _tokenId, id)
    )];

    // 29.7k gas
    item.lending = Lending({
      lenderAddress: msg.sender,
      maxRentDuration: _maxRentDuration,
      dailyRentPrice: _dailyRentPrice,
      nftPrice: _nftPrice,
      paymentToken: _paymentToken
    });

    emit Lent(
      address(_nftAddress),
      _tokenId,
      msg.sender,
      id,
      _maxRentDuration,
      _dailyRentPrice,
      _nftPrice,
      _paymentToken
    );

    // changing from non-zero to something else costs 5000 gas
    // however, changing from zero to something else costs 20k gas
    id++;
  }

  function lendMultiple(
    IERC721[] calldata _nftAddresses,
    uint256[] calldata _tokenIds,
    uint16[] calldata _maxRentDurations,
    uint32[] calldata _dailyRentPrice,
    uint32[] calldata _nftPrices,
    PaymentToken[] calldata _paymentTokenAddresses,
    address payable[] calldata _gasSponsors
  ) external {
    require(_nftAddresses.length == _tokenIds.length, "length not equal");
    require(_tokenIds.length == _maxRentDurations.length, "length not equal");
    require(
      _maxRentDurations.length == _dailyRentPrice.length,
      "length not equal"
    );
    require(_dailyRentPrice.length == _nftPrices.length, "length not equal");
    require(
      _nftPrices.length == _paymentTokenAddresses.length,
      "length not equal"
    );

    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      lendOne(
        _nftAddresses[i],
        _tokenIds[i],
        _maxRentDurations[i],
        _dailyRentPrice[i],
        _nftPrices[i],
        _paymentTokenAddresses[i],
        _gasSponsors[i]
      );
    }
  }

  function rentOne(
    IERC721 _nftAddress,
    uint256 _tokenId,
    uint256 _id,
    uint16 _rentDuration
  ) public nonReentrant {
    // edge-cases analysis
    // 1. what if I rent, immediately lend, and immediately borrow from myself
    // - rent and lend steps will work with no issue; last rent step will fail
    // - this is because we have a require here that the currentLender != msg.sender
    // 2. acc A lends, acc B rents, acc B lends with maxDuration higher than original
    // - TODO: this is currently allowed, I strongly believe it should not be. Since this
    // increaes the risk of the platform

    LendingRenting storage item = lendingRenting[keccak256(
      abi.encodePacked(address(_nftAddress), _tokenId, _id)
    )];

    require(item.renting.rentDuration == 0, "already rented");

    // ! this means that you can rent your own NFT and purposefully avoid returning it
    // ! do we want such a mechanic?
    // ! currentLender may not be you, but you may be the original lender, so this
    // ! check would pass and so you could rent your own NFT
    // ! if the new lender set a lower collateral, then your profit would be
    // ! original collateral - borrow payments - current collateral
    // ! we should leave this in, because this would incentivise the new lenders
    // ! to consider the original quotes when setting their collateral, etc.
    require(msg.sender != item.lending.lenderAddress, "can't rent own nft");
    require(
      _rentDuration <= item.lending.maxRentDuration,
      "max duration exceeded"
    );

    // TODO: this should go to the contract as an escrow
    // on return, or on collateral claim, we either give
    // the lender the portion of the amounts, or all of them
    // ! uint256 rentPrice = _rentDuration.mul(item.lending.dailyRentPrice);
    uint256 rentPrice = 1 ether;
    IERC20 paymentToken = resolver.getPaymentToken(
      uint8(item.lending.paymentToken)
    );

    paymentToken.safeTransferFrom(
      msg.sender,
      item.lending.lenderAddress,
      rentPrice
    );
    paymentToken.safeTransferFrom(
      msg.sender,
      address(this),
      item.lending.nftPrice
    );

    // // // ! uint256 rentedAt = block.timestamp;
    uint16 rentedAt = 22;

    item.renting.renterAddress = msg.sender;
    item.renting.rentDuration = _rentDuration;
    item.renting.rentedAt = rentedAt;

    _nftAddress.safeTransferFrom(address(this), msg.sender, _tokenId);

    emit Rented(
      address(_nftAddress),
      _tokenId,
      msg.sender,
      _rentDuration,
      rentedAt
    );
  }

  function rentMultiple(
    IERC721[] calldata _nftAddress,
    uint256[] calldata _tokenId,
    uint256[] calldata _id,
    uint16[] calldata _rentDuration
  ) external {
    require(_nftAddress.length == _tokenId.length, "length not equal");
    require(_tokenId.length == _id.length, "length not equal");
    require(_id.length == _rentDuration.length, "length not equal");

    for (uint256 i = 0; i < _nftAddress.length; i++) {
      rentOne(_nftAddress[i], _tokenId[i], _id[i], _rentDuration[i]);
    }
  }

  function returnOne(
    IERC721 _nftAddress,
    uint256 _tokenId,
    uint256 _id
  ) public nonReentrant {
    LendingRenting storage item = lendingRenting[keccak256(
      abi.encodePacked(address(_nftAddress), _tokenId, _id)
    )];
    require(item.renting.renterAddress == msg.sender, "not renter");
    uint256 durationInDays = 1;
    // uint256 durationInDays = block
    //   .timestamp
    //   .sub(all.renting.rentedAt[numOfRentersLess1])
    //   .div(SECONDS_IN_A_DAY);
    require(durationInDays <= item.renting.rentDuration, "duration exceeded");

    _nftAddress.safeTransferFrom(msg.sender, address(this), _tokenId);

    IERC20 paymentToken = resolver.getPaymentToken(
      uint8(item.lending.paymentToken)
    );
    paymentToken.safeTransfer(msg.sender, item.lending.nftPrice);

    emit Returned(address(_nftAddress), _tokenId, msg.sender, _id);

    delete item.renting;
  }

  function returnMultiple(
    IERC721[] calldata _nftAddress,
    uint256[] calldata _tokenId,
    uint256[] calldata _id
  ) external {
    for (uint256 i = 0; i < _nftAddress.length; i++) {
      returnOne(_nftAddress[i], _tokenId[i], _id[i]);
    }
  }

  function claimCollateralOne(
    IERC721 _nftAddress,
    uint256 _tokenId,
    uint256 _id
  ) public nonReentrant {
    LendingRenting storage item = lendingRenting[keccak256(
      abi.encodePacked(address(_nftAddress), _tokenId, _id)
    )];

    require(item.renting.rentDuration != 0, "nft not rented out");
    require(item.lending.lenderAddress == msg.sender, "not lender");

    uint256 durationInDays = 333;
    // uint256 durationInDays = block
    //   .timestamp
    //   .sub(all.renting.rentedAt[numOfLendersLess1])
    //   .div(SECONDS_IN_A_DAY);
    // ? is this correct
    require(
      durationInDays > item.renting.rentDuration,
      "duration not exceeded"
    );

    IERC20 paymentToken = resolver.getPaymentToken(
      uint8(item.lending.paymentToken)
    );
    paymentToken.safeTransfer(msg.sender, item.lending.nftPrice);

    delete item.lending;
    delete item.renting;
  }

  function claimCollateralMultiple(
    IERC721[] calldata _nftAddress,
    uint256[] calldata _tokenId,
    uint256[] calldata _id
  ) external {
    for (uint256 i = 0; i < _nftAddress.length; i++) {
      claimCollateralOne(_nftAddress[i], _tokenId[i], _id[i]);
    }
  }

  function stopLendingOne(
    IERC721 _nftAddress,
    uint256 _tokenId,
    uint256 _id
  ) public {
    LendingRenting storage item = lendingRenting[keccak256(
      abi.encodePacked(_nftAddress, _tokenId, _id)
    )];

    require(item.renting.rentDuration == 0, "nft rented currently");
    require(item.lending.lenderAddress == msg.sender, "not lender");

    IERC721(_nftAddress).safeTransferFrom(address(this), msg.sender, _tokenId);

    delete item.lending;
  }

  function stopLendingMultiple(
    IERC721[] calldata _nftAddress,
    uint256[] calldata _tokenId,
    uint256[] calldata _id
  ) external {
    for (uint256 i = 0; i < _nftAddress.length; i++) {
      stopLendingOne(_nftAddress[i], _tokenId[i], _id[i]);
    }
  }
}
