// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "./ChiGasSaver.sol";

contract RentNft is ReentrancyGuard, Ownable, ERC721Holder, ChiGasSaver {
  using SafeERC20 for IERC20;

  // 256 bits -> 32 bytes
  // address - 20 byte value -> 160 bits
  uint32 private constant SECONDS_IN_A_DAY = 86400;

  event Lent(
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed lenderAddress,
    uint16 maxRentDuration,
    uint32 dailyRentPrice,
    uint32 nftPrice,
    uint8 paymentTokenAddress
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
    address indexed renterAddress
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
    uint8 paymentToken;
    // 256 bits
    uint8 id;
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
    uint8[16] lending;
    uint8[16] renting;
  }

  // keccak256(abi.encodePacked(nft, tokenId, lendingId)) => Lending
  mapping(bytes => Lending) private lendings;
  // keccak256(abi.encodePacked(nft, tokenId, rentingId)) => Lending
  mapping(bytes => Renting) private rentings;
  // keccak256(abi.enocdePacked(nft, tokenId)) => lendingId => true / false
  mapping(bytes => LendingRenting) private lendingRenting;

  function lendOne(
    IERC721 _nftAddress,
    uint256 _tokenId,
    uint16 _maxRentDuration,
    uint32 _dailyRentPrice,
    uint32 _nftPrice,
    uint8 _paymentToken,
    address payable _gasSponsor
  ) public nonReentrant {
    require(_maxRentDuration > 0, "at least one day");

    // edge-cases analysis
    // 1. if I have lent out and try to lend out again. fail: since the nft was already transferred

    // 120k gas ...
    _nftAddress.safeTransferFrom(msg.sender, address(this), _tokenId);

    // 29.7k gas
    lendings[abi.encodePacked(_nftAddress, _tokenId, uint8(0))] = Lending({
      id: uint8(0),
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
      _maxRentDuration,
      _dailyRentPrice,
      _nftPrice,
      _paymentToken
    );
  }

  // function lendMultiple(
  //   address[] calldata _nftAddresses,
  //   uint256[] calldata _tokenIds,
  //   uint256[] calldata _maxRentDurations,
  //   uint256[] calldata _dailyRentPrice,
  //   uint256[] calldata _nftPrices,
  //   address[] calldata _paymentTokenAddresses
  // ) external {
  //   require(_nftAddresses.length == _tokenIds.length, "length not equal");
  //   require(_tokenIds.length == _maxRentDurations.length, "length not equal");
  //   require(
  //     _maxRentDurations.length == _dailyRentPrice.length,
  //     "length not equal"
  //   );
  //   require(_dailyRentPrice.length == _nftPrices.length, "length not equal");
  //   require(
  //     _nftPrices.length == _paymentTokenAddresses.length,
  //     "length not equal"
  //   );

  //   for (uint256 i = 0; i < _nftAddresses.length; i++) {
  //     lendOne(
  //       _nftAddresses[i],
  //       _tokenIds[i],
  //       _maxRentDurations[i],
  //       _dailyRentPrice[i],
  //       _nftPrices[i],
  //       _paymentTokenAddresses[i]
  //     );
  //   }
  // }

  // function rentOne(
  //   address _nftAddress,
  //   uint256 _tokenId,
  //   uint256 _rentDuration
  // ) public nonReentrant {
  //   // edge-cases analysis
  //   // 1. what if I rent, immediately lend, and immediately borrow from myself
  //   // - rent and lend steps will work with no issue; last rent step will fail
  //   // - this is because we have a require here that the currentLender != msg.sender
  //   // 2. acc A lends, acc B rents, acc B lends with maxDuration higher than original
  //   // - TODO: this is currently allowed, I strongly believe it should not be. Since this
  //   // increaes the risk of the platform

  //   LendingRenting storage all = lendingRenting[_nftAddress][_tokenId];

  //   (uint256 numOfLenders, , bool isRented) = _isRented(_nftAddress, _tokenId);
  //   require(numOfLenders > 0, "could not find an nft");
  //   require(!isRented, "already rented");

  //   uint256 numOfLendersLess1 = numOfLenders - 1;
  //   address currentLender = all.lending.lenderAddress[numOfLendersLess1];
  //   // ! this means that you can rent your own NFT and purposefully avoid returning it
  //   // ! do we want such a mechanic?
  //   // ! currentLender may not be you, but you may be the original lender, so this
  //   // ! check would pass and so you could rent your own NFT
  //   // ! if the new lender set a lower collateral, then your profit would be
  //   // ! original collateral - borrow payments - current collateral
  //   // ! we should leave this in, because this would incentivise the new lenders
  //   // ! to consider the original quotes when setting their collateral, etc.
  //   require(msg.sender != currentLender, "can't rent own nft");
  //   require(
  //     _rentDuration <= all.lending.maxRentDuration[numOfLendersLess1],
  //     "max duration exceeded"
  //   );

  //   // TODO: this should go to the contract as an escrow
  //   // on return, or on collateral claim, we either give
  //   // the lender the portion of the amounts, or all of them
  //   uint256 rentPrice = _rentDuration.mul(
  //     all.lending.dailyRentPrice[numOfLendersLess1]
  //   );
  //   address paymentToken = all.lending.paymentTokenAddress[numOfLendersLess1];
  //   IERC20(paymentToken).safeTransferFrom(msg.sender, currentLender, rentPrice);
  //   IERC20(paymentToken).safeTransferFrom(
  //     msg.sender,
  //     address(this),
  //     all.lending.nftPrice[numOfLendersLess1]
  //   );

  //   uint256 rentedAt = block.timestamp;

  //   all.renting.renterAddress.push(msg.sender);
  //   all.renting.rentDuration.push(_rentDuration);
  //   all.renting.rentedAt.push(rentedAt);

  //   IERC721(_nftAddress).safeTransferFrom(address(this), msg.sender, _tokenId);

  //   emit Rented(_nftAddress, _tokenId, msg.sender, _rentDuration, rentedAt);
  // }

  // function rentMultiple(
  //   address[] calldata _nftAddress,
  //   uint256[] calldata _tokenId,
  //   uint256[] calldata _rentDuration
  // ) external {
  //   require(_nftAddress.length == _tokenId.length, "length not equal");
  //   require(_tokenId.length == _rentDuration.length, "length not equal");

  //   for (uint256 i = 0; i < _nftAddress.length; i++) {
  //     rentOne(_nftAddress[i], _tokenId[i], _rentDuration[i]);
  //   }
  // }

  // function returnOne(address _nftAddress, uint256 _tokenId)
  //   public
  //   nonReentrant
  // {
  //   LendingRenting storage all = lendingRenting[_nftAddress][_tokenId];

  //   (uint256 numOfLenders, uint256 numOfRenters, bool isRented) = _isRented(
  //     _nftAddress,
  //     _tokenId
  //   );
  //   require(isRented, "is not rented");
  //   uint256 numOfRentersLess1 = numOfRenters - 1;
  //   require(
  //     all.renting.renterAddress[numOfRentersLess1] == msg.sender,
  //     "not renter"
  //   );
  //   uint256 durationInDays = block
  //     .timestamp
  //     .sub(all.renting.rentedAt[numOfRentersLess1])
  //     .div(SECONDS_IN_A_DAY);
  //   require(
  //     durationInDays <= all.renting.rentDuration[numOfRentersLess1],
  //     "duration exceeded"
  //   );

  //   _deleteLastRenting(_nftAddress, _tokenId);

  //   // - if this is not the original lender, then we return the NFT back to them
  //   // so that they get a chance to return this NFT back to the original owner.
  //   // At the same time, we delete their lending entries from the arrays
  //   address sendNftBackTo;
  //   uint256 numOfLendersLess1 = numOfLenders - 1;
  //   address paymentToken = all.lending.paymentTokenAddress[numOfLendersLess1];
  //   uint256 collateral = all.lending.nftPrice[numOfLendersLess1];

  //   if (numOfLenders > 1) {
  //     sendNftBackTo = all.lending.lenderAddress[numOfLendersLess1];
  //     _deleteLastLending(_nftAddress, _tokenId);
  //   } else {
  //     sendNftBackTo = address(this);
  //   }

  //   IERC721(_nftAddress).safeTransferFrom(msg.sender, sendNftBackTo, _tokenId);
  //   IERC20(paymentToken).safeTransfer(msg.sender, collateral);

  //   emit Returned(_nftAddress, _tokenId, msg.sender);
  // }

  // function returnMultiple(
  //   address[] calldata _nftAddress,
  //   uint256[] calldata _tokenId
  // ) external {
  //   for (uint256 i = 0; i < _nftAddress.length; i++) {
  //     returnOne(_nftAddress[i], _tokenId[i]);
  //   }
  // }

  // function claimCollateral(address _nftAddress, uint256 _tokenId)
  //   public
  //   nonReentrant
  // {
  //   LendingRenting storage all = lendingRenting[_nftAddress][_tokenId];

  //   (uint256 numOfLenders, , bool isRented) = _isRented(_nftAddress, _tokenId);
  //   require(isRented, "nft not rented out");
  //   uint256 numOfLendersLess1 = numOfLenders - 1;
  //   require(
  //     all.lending.lenderAddress[numOfLendersLess1] == msg.sender,
  //     "not lender"
  //   );

  //   uint256 durationInDays = block
  //     .timestamp
  //     .sub(all.renting.rentedAt[numOfLendersLess1])
  //     .div(SECONDS_IN_A_DAY);
  //   // ? is this correct
  //   require(
  //     durationInDays > all.renting.rentDuration[numOfLendersLess1],
  //     "duration not exceeded"
  //   );

  //   IERC20(all.lending.paymentTokenAddress[numOfLendersLess1]).safeTransfer(
  //     msg.sender,
  //     all.lending.nftPrice[numOfLendersLess1]
  //   );

  //   _delteLastAll(_nftAddress, _tokenId);
  // }

  // function stopLending(address _nftAddress, uint256 _tokenId) public {
  //   LendingRenting storage all = lendingRenting[_nftAddress][_tokenId];

  //   (uint256 numOfLenders, , bool isRented) = _isRented(_nftAddress, _tokenId);

  //   require(!isRented, "nft rented currently");
  //   require(
  //     all.lending.lenderAddress[numOfLenders - 1] == msg.sender,
  //     "not lender"
  //   );

  //   IERC721(_nftAddress).safeTransferFrom(address(this), msg.sender, _tokenId);

  //   _deleteLastLending(_nftAddress, _tokenId);
  // }

  // function _isRented(address _nftAddress, uint256 _tokenId)
  //   internal
  //   view
  //   returns (
  //     uint256 numOfLenders,
  //     uint256 numOfRenters,
  //     bool isRented
  //   )
  // {
  //   LendingRenting storage all = lendingRenting[_nftAddress][_tokenId];

  //   numOfLenders = all.lending.lenderAddress.length;
  //   numOfRenters = all.renting.renterAddress.length;
  //   isRented = (numOfLenders == numOfRenters) && (numOfLenders > 0);
  // }

  // function _deleteLastLending(address _nftAddress, uint256 _tokenId) internal {
  //   LendingRenting storage all = lendingRenting[_nftAddress][_tokenId];

  //   uint256 lendingLength = all.lending.lenderAddress.length;
  //   require(lendingLength > 0, "nothing to delete");
  //   uint256 lendingLengthLess1 = lendingLength - 1;

  //   delete all.lending.lenderAddress[lendingLengthLess1];
  //   delete all.lending.maxRentDuration[lendingLengthLess1];
  //   delete all.lending.dailyRentPrice[lendingLengthLess1];
  //   delete all.lending.nftPrice[lendingLengthLess1];
  //   delete all.lending.paymentTokenAddress[lendingLengthLess1];
  // }

  // function _deleteLastRenting(address _nftAddress, uint256 _tokenId) internal {
  //   LendingRenting storage all = lendingRenting[_nftAddress][_tokenId];

  //   uint256 rentingLength = all.renting.renterAddress.length;
  //   require(rentingLength > 0, "nothing to delte");
  //   uint256 rentingLengthLess1 = rentingLength - 1;

  //   delete all.renting.renterAddress[rentingLengthLess1];
  //   delete all.renting.rentDuration[rentingLengthLess1];
  //   delete all.renting.rentedAt[rentingLengthLess1];
  // }

  // function _delteLastAll(address _nftAddress, uint256 _tokenId) internal {
  //   _deleteLastLending(_nftAddress, _tokenId);
  //   _deleteLastRenting(_nftAddress, _tokenId);
  // }
}
