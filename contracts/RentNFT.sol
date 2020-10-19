// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./utils/ProxyFactory.sol";
import "./utils/ContextUpgradeSafe.sol";
import "./interfaces/ILendingPoolAddressProvider.sol";
import "./interfaces/ILendingPoolCore.sol";
import "./interfaces/ILendingPool.sol";
import "./InterestCalculatorProxy.sol";

contract RentNFT is ProxyFactory, ReentrancyGuard, Ownable {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  // ? we can move to renting in higher frequencies like minutes
  // but then depositing with AAVE does not make sense
  event ProductAdded(
    address indexed nftAddress,
    uint256 indexed nftId,
    address indexed owner,
    uint256 maxRentDuration,
    uint256 dailyRentPrice,
    uint256 nftPrice,
    uint256 collateral
  );
  event Rent(
    address indexed nftAddress,
    uint256 indexed nftId,
    address indexed borrower,
    address owner,
    uint256 borrowedAt,
    uint256 dailyRentPrice,
    uint256 actualRentDuration,
    uint256 nftPrice,
    uint256 collateral
  );
  event Return(
    address indexed nftAddress,
    uint256 indexed nftId,
    address borrower,
    address owner
  );

  struct Asset {
    address owner;
    address borrower;
    uint256 maxRentDuration; // in days
    uint256 actualRentDuration; // actual duration lender rented out the NFT for
    uint256 dailyRentPrice; // how much the lender has to pay irrevocably daily
    uint256 borrowedAt; // borrowed time to be verifed by returning
    uint256 nftPrice;
    uint256 collateral;
  }

  // proxy details
  // owner => borrower => proxy
  mapping(address => mapping(address => address)) public proxyInfo;
  address public proxyBaseAddress;

  // nft address => token id => asset info struct
  mapping(address => mapping(uint256 => Asset)) public assets;

  // TODO: make setting of these addresses dynamic in constructor
  // it will set automatically as per network the contract is deployed on
  address public daiAddress = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
  address public aDaiAddress = 0x58AD4cB396411B691A9AAb6F74545b2C5217FE6a;

  ILendingPoolAddressesProvider public lendingPoolAddressProvider;
  ILendingPool public lendingPool;
  ILendingPoolCore public lendingPoolCore;

  // provide aave address provider for the network you are working on
  // get all aave related addresses through addressesProvider state var
  // get all aToken reserve addresses through the core state var
  constructor(address _proxyBaseAddress) public {
    proxyBaseAddress = _proxyBaseAddress;
    // do we need this at the moment  ?
    lendingPoolAddressProvider = ILendingPoolAddressesProvider(
      0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5
    );
    lendingPool = ILendingPool(lendingPoolAddressProvider.getLendingPool());
    lendingPoolCore = ILendingPoolCore(
      lendingPoolAddressProvider.getLendingPoolCore()
    );
  }

  // function to list the nft on the platform
  // url will be the api endpoint to fetch nft price
  function addProduct(
    address _nftAddress,
    uint256 _nftId,
    uint256 _maxRentDurationInDays,
    uint256 _dailyRentPrice,
    uint256 _nftPrice,
    uint256 _collateral
  ) external {
    require(_nftAddress != address(0), "Invalid NFT Address");

    assets[_nftAddress][_nftId] = Asset(
      msg.sender, // owner
      address(0), // borrower
      _maxRentDurationInDays,
      0, // actualRentDuration. This gets populated on the rent call
      _dailyRentPrice,
      0, // borrowedAt
      _nftPrice,
      _collateral
    );

    // transfer nft to this contract
    ERC721(_nftAddress).transferFrom(msg.sender, address(this), _nftId);
    emit ProductAdded(
      _nftAddress,
      _nftId,
      msg.sender,
      _maxRentDurationInDays,
      _dailyRentPrice,
      _nftPrice,
      _collateral
    );
  }

  function rent(
    address _borrower,
    address _nftAddress,
    uint256 _tokenId,
    uint256 _actualRentDuration
  ) external nonReentrant {
    Asset storage nft = assets[_nftAddress][_tokenId];

    require(_borrower != nft.owner, "can't rent own nft");
    require(nft.maxRentDuration > 0, "could not find an NFT");

    createProxy(nft.owner, _borrower);

    // pay the NFT owner the rent price
    uint256 rentPrice = _actualRentDuration.mul(nft.dailyRentPrice);
    ERC20(daiAddress).safeTransferFrom(_borrower, nft.owner, rentPrice);

    // ! will fail if the msg.sender hasn't approved us as the spender of their ERC20 tokens
    transferToProxy(
      daiAddress,
      msg.sender,
      nft.collateral,
      proxyInfo[nft.owner][_borrower]
    );
    // deposit to aave
    InterestCalculatorProxy(proxyInfo[nft.owner][_borrower]).deposit(
      daiAddress,
      address(lendingPool),
      address(lendingPoolCore),
      address(this)
    );

    assets[_nftAddress][_tokenId].borrower = _borrower;
    assets[_nftAddress][_tokenId].borrowedAt = now;
    assets[_nftAddress][_tokenId].actualRentDuration = _actualRentDuration;

    ERC721(_nftAddress).transferFrom(address(this), _borrower, _tokenId);
    emit Rent(
      _nftAddress,
      _tokenId,
      _borrower,
      nft.owner,
      nft.borrowedAt,
      nft.dailyRentPrice,
      nft.actualRentDuration,
      nft.nftPrice,
      nft.collateral
    );
  }

  function returnNFT(address _nftAddress, uint256 _tokenId) external {
    Asset storage nft = assets[_nftAddress][_tokenId];

    require(nft.maxRentDuration > 0, "could not find an NFT");
    require(nft.borrower == msg.sender, "not borrower");
    // TODO: make them pay daily penalty for every day that they are late to return the NFT
    // TODO: compensate them if they return the NFT earlier

    // redeem aDai to Dai in Proxy
    uint256 daiReceived = InterestCalculatorProxy(
      proxyInfo[nft.owner][msg.sender]
    )
      .withdraw(aDaiAddress, daiAddress);

    uint256 interest = daiReceived.sub(nft.collateral);

    ERC721(_nftAddress).transferFrom(msg.sender, nft.owner, _tokenId);
    ERC20(daiAddress).safeTransfer(nft.owner, interest);
    ERC20(daiAddress).safeTransfer(nft.borrower, nft.collateral);

    nft.actualRentDuration = 0;
    emit Return(_nftAddress, _tokenId, msg.sender, nft.owner);
  }

  // allow contract owner to withdraw collateral in case of a fraud. We resolve disputes to begin with
  function redeemCollateral(address _nftAddress, uint256 _tokenId)
    external
    onlyOwner
  {
    Asset storage nft = assets[_nftAddress][_tokenId];

    require(nft.maxRentDuration > 0, "could not find an NFT");

    uint256 durationInDays = now
      .sub(assets[_nftAddress][_tokenId].borrowedAt)
      .div(86400);
    require(durationInDays >= nft.actualRentDuration, "duration not exceeded");

    // redeem aDai to Dai in Proxy
    uint256 daiReceived = InterestCalculatorProxy(
      proxyInfo[msg.sender][nft.borrower]
    )
      .withdraw(aDaiAddress, daiAddress);

    // onlyOwner ensures that this will be sent to rentNFT contract
    // we must control this contract to resolve the disputes
    ERC20(daiAddress).safeTransfer(msg.sender, daiReceived);
  }

  /**
   * @dev transfers an amount from a user to the destination proxy address where it
   * subsequently gets deposited into Aave
   * @param _reserve the address of the reserve where the amount is being transferred
   * @param _user the address of the user from where the transfer is happening
   * @param _amount the amount being transferred
   **/
  function transferToProxy(
    address _reserve,
    address payable _user,
    uint256 _amount,
    address _proxy
  ) private {
    require(msg.value == 0, "don't send ETH");
    // ! our contract should be approved to move his ERC20 funds
    ERC20(_reserve).safeTransferFrom(_user, _proxy, _amount);
  }

  // create the proxy contract for managing interest when a borrower rents it out
  function createProxy(address _owner, address _borrower) internal {
    bytes memory _payload = abi.encodeWithSignature(
      "initialize(address)",
      _owner
    );
    // proxy is used for easy interest handling. Interest gets redirected to it
    address _intermediate = deployMinimal(proxyBaseAddress, _payload);
    // user address is just recorded for tracking the proxy for the particular pair
    // TODO: need to test this for same owner but different user
    proxyInfo[_owner][_borrower] = _intermediate;
  }

  // check whether the proxy contract exists or not for a owner-borrower pair
  function getProxy(address _owner, address _borrower)
    internal
    view
    returns (address)
  {
    return proxyInfo[_owner][_borrower];
  }
}
