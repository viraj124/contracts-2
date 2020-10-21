// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./utils/OwnableUpgradeSafe.sol";
import "./utils/Initializable.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/AToken.sol";

contract InterestCalculatorProxy is Initializable, OwnableUpgradeSafe {
  using SafeERC20 for ERC20;
  event Initialized(address indexed thisAddress);
  address public rentft;

  // proxy admin would be the owner to prevent in fraud cases where the borrower
  // doesn't return the nft back
  function initialize(address _owner) public initializer {
    OwnableUpgradeSafe.__Ownable_init();
    OwnableUpgradeSafe.transferOwnership(_owner);
    emit Initialized(address(this));
  }

  function deposit(
    address _reserve,
    address _lendingPool,
    address _lendingPoolCore,
    address _rentft
  ) public {
    rentft = _rentft;
    uint256 reserveBalance = ERC20(_reserve).balanceOf(address(this));
    ERC20(_reserve).approve(_lendingPoolCore, reserveBalance);
    ILendingPool(_lendingPool).deposit(_reserve, reserveBalance, 0);
  }

  // allow rentft to withdraw from aave
  function withdraw(address aDaiAddress, address daiAddress)
    public
    returns (uint256)
  {
    require(msg.sender == rentft, "Not Rentft");

    uint256 balance = IERC20(aDaiAddress).balanceOf(address(this));

    // withdraw dai from aDai
    AToken(aDaiAddress).redeem(balance);
    ERC20(daiAddress).safeTransfer(rentft, balance);

    return balance;
  }
}