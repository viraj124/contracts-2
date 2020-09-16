// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../libraries/CoreLibrary.sol";

interface ILendingPoolCore {
  function getReserveATokenAddress(address _reserve)
    external
    view
    returns (address);
}
