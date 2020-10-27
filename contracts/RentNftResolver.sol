// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract RentNftResolver {
  uint256 public networkId;
  address private testDai;
  address private testUsdc;
  address private testUsdt;
  address private testPax;
  address private testBusd;

  constructor(
    uint256 _networkId,
    address _testDai,
    address _testUsdc,
    address _testUsdt,
    address _testPax,
    address _testBusd
  ) public {
    if (networkId != 0) {
      networkId = _networkId;
    } else {
      testDai = _testDai;
      testUsdc = _testUsdc;
      testUsdt = _testUsdt;
      testPax = _testPax;
      testBusd = _testBusd;
    }
  }

  function getDai() public view returns (address) {
    if (networkId == 5) {
      return 0x88271d333C72e51516B67f5567c728E702b3eeE8;
    } else {
      return testDai;
    }
  }

  function getUsdc() public view returns (address) {
    return testUsdc;
  }

  function getUsdt() public view returns (address) {
    return testUsdt;
  }

  function getPax() public view returns (address) {
    return testPax;
  }

  function getBusd() public view returns (address) {
    return testBusd;
  }
}
