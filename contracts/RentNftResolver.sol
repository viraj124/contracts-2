// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract RentNftResolver {
  uint256 public networkId;

  constructor(uint256 _networkId) public {
    networkId = _networkId;
  }

  function getDaiAddress() public returns (address) {}

  function getUsdcAddress() public returns (address) {}

  function getUsdtAddress() public returns (address) {}

  function getPaxAddress() public returns (address) {}

  function getBusdAddress() public returns (address) {}
}
