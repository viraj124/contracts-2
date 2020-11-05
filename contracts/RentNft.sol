// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./RentNftAddressProvider.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";

contract RentNft is ReentrancyGuard, Ownable, ERC721Holder {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  // TODO: if thre are defaults, mark the address to forbid from renting

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
    uint256 actualDuration; // set by borrower. actual duration borrower will have the NFT for. This gets populated on the rent call
    uint256 borrowPrice; // set by lender. how much the borrower has to pay irrevocably daily
    uint256 borrowedAt; // set by borrower. time at which nft is borrowed
    uint256 nftPrice; // set by lender. how much lender will receive as collateral if borrower does not return nft in time
  }

  // mapping(address => address) public ownerBorrower;
  // nft address => token id => nft
  mapping(address => mapping(uint256 => Nft)) public nfts;

  RentNftAddressProvider public resolver;

  constructor(address _resolver) public {
    resolver = RentNftAddressProvider(_resolver);
  }

  /**
  * @dev See {IERC721Receiver-onERC721Received}.
  *
  * Always returns `IERC721Receiver.onERC721Received.selector`.
  */
  function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
    return this.onERC721Received.selector;
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

    nfts[_nftAddress][_tokenId] = Nft({
      lender: msg.sender,
      borrower: address(0),
      maxDuration: _maxDuration,
      actualDuration: 0,
      borrowPrice: _borrowPrice,
      borrowedAt: 0,
      nftPrice: _nftPrice
      });

    // transfer nft to this contract. will fail if nft wasn't approved
    ERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
    emit Lent(
      _nftAddress,
      _tokenId,
      msg.sender,
      _maxDuration,
      _borrowPrice,
      _nftPrice
    );
  }

  // lend multiple nfts that you own to be borrowable by Rent NFT
  // for gas saving
  function lendMultiple(
    address[] calldata _nftAddresses,
    uint256[] calldata _tokenIds,
    uint256[] calldata _maxDurations,
    uint256[] calldata _borrowPrices,
    uint256[] calldata _nftPrices
  ) external {
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

    require(nft.lender != address(0), "could not find an NFT");
    require(_borrower != nft.lender, "can't borrow own nft");
    require(_actualDuration <= nft.maxDuration, "Max Duration exceeded");

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
    address[] calldata _nftAddresses,
    uint256[] calldata _tokenIds,
    uint256[] calldata _actualDurations
  ) external {
    require(_nftAddresses.length == _tokenIds.length, "not equal length");
    require(_tokenIds.length == _actualDurations.length, "not equal length");
    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      rentOne(_borrower, _nftAddresses[i], _tokenIds[i], _actualDurations[i]);
    }
  }

  function returnNftOne(address _nftAddress, uint256 _tokenId)
    public
    nonReentrant
  {
    Nft storage nft = nfts[_nftAddress][_tokenId];

    require(nft.borrower == msg.sender, "not borrower");
    uint256 durationInDays = now.sub(nft.borrowedAt).div(86400);
    require(durationInDays <= nft.actualDuration, "duration exceeded");

    // we are returning back to the contract so that the owner does not have to add
    // it multiple times thus incurring the transaction costs
    ERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
    ERC20(resolver.getDai()).safeTransfer(nft.borrower, nft.nftPrice);

    resetBorrow(nft);
    emit Returned(_nftAddress, _tokenId, msg.sender, nft.borrower);
  }

  function returnNftMultiple(
    address[] calldata _nftAddresses,
    uint256[] calldata _tokenIds
  ) external {
    require(_nftAddresses.length == _tokenIds.length, "not equal length");
    for (uint256 i = 0; i < _nftAddresses.length; i++) {
      returnNftOne(_nftAddresses[i], _tokenIds[i]);
    }
  }

  function stopLending(address _nftAddress, uint256 _tokenId) public {
    Nft storage nft = nfts[_nftAddress][_tokenId];
    require(nft.lender == msg.sender, "not lender");
    ERC721(_nftAddress).safeTransferFrom(address(this), nft.lender, _tokenId);
  }

  // TODO: onlyOwner method to be called every day at midnight to automatically
  // default whoever has not returned the NFT in time
  function claimCollateral(address _nftAddress, uint256 _tokenId)
    public
    nonReentrant
  {
    Nft storage nft = nfts[_nftAddress][_tokenId];
    require(nft.lender == msg.sender, "not lender");
    require(nft.borrower != address(0), "nft not lent out");

    uint256 durationInDays = now.sub(nft.borrowedAt).div(86400);
    require(durationInDays > nft.actualDuration, "duration not exceeded");

    resetBorrow(nft);
    ERC20(resolver.getDai()).safeTransfer(msg.sender, nft.nftPrice);
  }

  function resetBorrow(Nft storage nft) internal {
    nft.borrower = address(0);
    nft.actualDuration = 0;
    nft.borrowedAt = 0;
  }
}
