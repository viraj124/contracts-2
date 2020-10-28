// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "./RentNftResolver.sol";

contract RentNft is Initializable, ReentrancyGuardUpgradeSafe, OwnableUpgradeSafe {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  // TODO: if there are defaults, mark the address to forbid from renting

  event Lent(
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed lender,
    uint256 maxDuration,
    uint256 borrowPrice,
    uint256 nftPrice
  );

  event Borrowed(
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
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed borrower,
    address lender
  );

  struct Nft {
    address lender;
    address borrower;
    uint256 maxDuration; // set by lender. max borrow duration in days
    uint256 actualDuration; // set by borrower. actual duration borrower will have the NFT for
    uint256 borrowPrice; // set by lender. how much the borrower has to pay irrevocably daily
    uint256 borrowedAt; // set by borrower. borrowed time to be verifed by returning
    uint256 nftPrice; // set by lender. how much lender will receive if borrower does not return in time
  }

  // mapping(address => address) public ownerBorrower;
  // nft address => token id => nft
  mapping(address => mapping(uint256 => Nft)) public nfts;

  RentNftResolver public resolver;

  function initialize(address _resolverAddress) initializer public {
    resolver = RentNftResolver(_resolverAddress);
  }

  // lend one nft that you own to be borrowable on Rent NFT
  function lendOne(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _maxDuration,
    uint256 _borrowPrice,
    uint256 _nftPrice
  ) public nonReentrant {
    require(_nftAddress != address(0), "invalid NFT address");
    require(_maxDuration > 0, "at least one day");

    nfts[_nftAddress][_tokenId] = Nft(
      msg.sender, // lender
      address(0), // borrower
      _maxDuration, // max rent duration
      0, // actual rent duration. This gets populated on the rent call
      _borrowPrice, // this is the daily borrow price
      0, // time at which this is borrowed
      _nftPrice // this is the collateral that gets sent to lender if borrower fails to return the NFT
    );

    // transfer nft to this contract. will fail if nft wasn't approved
    ERC721(_nftAddress).transferFrom(msg.sender, address(this), _tokenId);
    emit Lent(
      _nftAddress,
      _tokenId,
      msg.sender,
      _maxDuration,
      _borrowPrice,
      _nftPrice
    );
  }

  // ! TODO: reentrancy danger since this calls lendOne
  // lend multiple nfts that you own to be borrowable by Rent NFT
  // for gas saving
  function lendMultiple(
    address[] memory _nftAddresses,
    uint256[] memory _tokenIds,
    uint256[] memory _maxDurations,
    uint256[] memory _borrowPrices,
    uint256[] memory _nftPrices
  ) external {
    // ! TODO: needed to remove nonReentrant for tests?
    require(_nftAddresses.length == _tokenIds.length, "not equal length");
    require(_tokenIds.length == _maxDurations.length, "not equal length");
    require(_maxDurations.length == _borrowPrices.length, "not equal length");
    require(_borrowPrices.length == _nftPrices.length, "not equal length");

    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      lendOne(
        _nftAddresses[i],
        _tokenIds[i],
        _maxDurations[i],
        _borrowPrices[i],
        _nftPrices[i]
      );
    }
  }

  function rentOne(
    address _borrower,
    address _nftAddress,
    uint256 _tokenId,
    uint256 _actualDuration
  ) public nonReentrant {
    Nft storage nft = nfts[_nftAddress][_tokenId];

    require(_borrower != nft.lender, "can't borrow own nft");
    require(_borrower > address(0), "could not find an NFT");

    // ! will fail if wasn't approved
    // pay the NFT owner the rent price
    uint256 rentPrice = _actualDuration.mul(nft.borrowPrice);
    ERC20(resolver.getDai()).safeTransferFrom(_borrower, nft.lender, rentPrice);
    // collateral, our contracts acts as an escrow
    ERC20(resolver.getDai()).safeTransferFrom(
      _borrower,
      address(this),
      nft.nftPrice
    );

    nfts[_nftAddress][_tokenId].borrower = _borrower;
    nfts[_nftAddress][_tokenId].borrowedAt = now;
    nfts[_nftAddress][_tokenId].actualDuration = _actualDuration;

    ERC721(_nftAddress).safeTransferFrom(address(this), _borrower, _tokenId);

    emit Borrowed(
      _nftAddress,
      _tokenId,
      _borrower,
      nft.lender,
      nft.borrowedAt,
      nft.borrowPrice,
      nft.actualDuration,
      nft.nftPrice
    );
  }

  function rentMultiple(
    address _borrower,
    address[] memory _nftAddresses,
    uint256[] memory _tokenIds,
    uint256[] memory _actualDurations
  ) external nonReentrant {
    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      rentOne(_borrower, _nftAddresses[i], _tokenIds[i], _actualDurations[0]);
    }
  }

  function returnNftOne(address _nftAddress, uint256 _tokenId)
    public
    nonReentrant
  {
    Nft storage nft = nfts[_nftAddress][_tokenId];

    require(nft.borrower == msg.sender, "not borrower");

    // we are returning back to the contract so that the owner does not have to add
    // it multiple times thus incurring the transaction costs
    ERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
    ERC20(resolver.getDai()).safeTransfer(nft.borrower, nft.nftPrice);

    resetBorrow(nft);
    emit Returned(_nftAddress, _tokenId, msg.sender, nft.borrower);
  }

  function returnNftMultiple(
    address[] memory _nftAddresses,
    uint256[] memory _tokenIds
  ) external nonReentrant {
    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      returnNftOne(_nftAddresses[i], _tokenIds[i]);
    }
  }

  // TODO: onlyOwner method to be called every day at midnight to automatically
  // default whoever has not returned the NFT in time

  function resetBorrow(Nft storage nft) internal {
    nft.borrower = address(0);
    nft.actualDuration = 0;
    nft.borrowedAt = 0;
  }
}
