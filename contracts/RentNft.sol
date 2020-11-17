// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract RentNft is ReentrancyGuard, Ownable, ERC721Holder {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;
  using Counters for Counters.Counter;

  struct Nft {
    address nftAddress;
    uint256 tokenId;
    address lender;
    address borrower;
    uint256 maxDuration;
    uint256 actualDuration;
    uint256 borrowPrice;
    uint256 borrowedAt;
    uint256 nftPrice;
  }

  // mapping(address => address) public ownerBorrower;
  // nft address => token id => nft
  mapping(uint256 => Nft) public nfts;

  Counters.Counter private lastId = Counters.Counter({_value: 0});
  uint256[] public allLending;

  constructor() public {}

  // lend one nft that you own to be borrowable on Rent NFT
  function lendOne(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _maxDuration,
    uint256 _borrowPrice,
    uint256 _nftPrice
  ) public nonReentrant {
    require(_nftAddress != address(0), "invalid nft address");
    require(_maxDuration > 0, "at least one day");

    lastId.increment();
    nfts[lastId.current()] = Nft({
      lender: msg.sender,
      borrower: address(0),
      maxDuration: _maxDuration,
      actualDuration: 0,
      borrowPrice: _borrowPrice,
      borrowedAt: 0,
      nftPrice: _nftPrice,
      nftAddress: _nftAddress,
      tokenId: _tokenId
    });
    ERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
    allLending.push(lastId.current());
  }

  function rentOne(
    address _borrower,
    uint256 _id,
    uint256 _actualDuration,
    address _paymentToken
  ) public nonReentrant {
    Nft storage nft = nfts[_id];

    require(nft.lender != address(0), "could not find an nft");
    require(_borrower != nft.lender, "can't borrow own nft");
    require(_actualDuration <= nft.maxDuration, "max duration exceeded");

    uint256 rentPrice = _actualDuration.mul(nft.borrowPrice);
    ERC20(_paymentToken).safeTransferFrom(_borrower, nft.lender, rentPrice);
    ERC20(_paymentToken).safeTransferFrom(
      _borrower,
      address(this),
      nft.nftPrice
    );

    nfts[_id].borrower = _borrower;
    nfts[_id].borrowedAt = now;
    nfts[_id].actualDuration = _actualDuration;

    ERC721(nft.nftAddress).safeTransferFrom(
      address(this),
      _borrower,
      nft.tokenId
    );
  }

  function returnOne(uint256 _id, address _paymentToken) public nonReentrant {
    Nft storage nft = nfts[_id];

    require(nft.borrower == msg.sender, "not borrower");
    uint256 durationInDays = now.sub(nft.borrowedAt).div(86400);
    require(durationInDays <= nft.actualDuration, "duration exceeded");

    // we are returning back to the contract so that the owner does not have to add
    // it multiple times thus incurring the transaction costs
    ERC721(nft.nftAddress).safeTransferFrom(
      msg.sender,
      address(this),
      nft.tokenId
    );
    ERC20(_paymentToken).safeTransfer(nft.borrower, nft.nftPrice);

    resetBorrow(nft);
  }

  function stopLending(uint256 _id) public {
    Nft storage nft = nfts[_id];
    require(nft.lender == msg.sender, "not lender");
    ERC721(nft.nftAddress).safeTransferFrom(
      address(this),
      nft.lender,
      nft.tokenId
    );
  }

  function claimCollateral(uint256 _id, address _paymentToken)
    public
    nonReentrant
  {
    Nft storage nft = nfts[_id];
    require(nft.lender == msg.sender, "not lender");
    require(nft.borrower != address(0), "nft not lent out");

    uint256 durationInDays = now.sub(nft.borrowedAt).div(86400);
    require(durationInDays > nft.actualDuration, "duration not exceeded");

    resetBorrow(nft);
    ERC20(_paymentToken).safeTransfer(msg.sender, nft.nftPrice);
  }

  function resetBorrow(Nft storage nft) internal {
    nft.borrower = address(0);
    nft.actualDuration = 0;
    nft.borrowedAt = 0;
  }

  function getAllLendingLength() external view returns (uint256) {
    return allLending.length;
  }
}
