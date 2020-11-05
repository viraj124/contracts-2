// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./configuration/AddressStorage.sol";

contract RentNftAddressProvider is Ownable, AddressStorage {
  event DaiUpdated(address indexed newAddress);
  event UsdcUpdated(address indexed newAddress);
  event UsdtUpdated(address indexed newAddress);

  uint8 private networkId;

  constructor(uint8 _networkId) public {
    networkId = _networkId;
  }

  function getDai() public view returns (address) {
    return getAddress(keccak256(abi.encodePacked("DAI", networkId)));
  }

  function getUsdc() public view returns (address) {
    return getAddress(keccak256(abi.encodePacked("USDC", networkId)));
  }

  function getUsdt() public view returns (address) {
    return getAddress(keccak256(abi.encodePacked("USDT", networkId)));
  }

  function setDai(address _dai) public onlyOwner {
    _setAddress(keccak256(abi.encodePacked("DAI", networkId)), _dai);
    emit DaiUpdated(_dai);
  }

  function setUsdc(address _usdc) public onlyOwner {
    _setAddress(keccak256(abi.encodePacked("USDC", networkId)), _usdc);
    emit UsdcUpdated(_usdc);
  }

  function setUsdt(address _usdt) public onlyOwner {
    _setAddress(keccak256(abi.encodePacked("USDT", networkId)), _usdt);
    emit UsdtUpdated(_usdt);
  }
}
