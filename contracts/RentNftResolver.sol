// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract RentNftResolver {
  uint256 public networkId;

  constructor(uint256 _networkId) public {
    networkId = _networkId;
  }

  function getDai() public view returns (address) {
    if (networkId == 5) {
      return 0x88271d333C72e51516B67f5567c728E702b3eeE8;
    }
  }

  function getUsdc() public returns (address) {}

  function getUsdt() public returns (address) {}

  function getPax() public returns (address) {}

  function getBusd() public returns (address) {}
}
