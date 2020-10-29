// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

contract AddressStorage {
  mapping(bytes32 => address) private addresses;

  function getAddress(bytes32 _key) public view returns (address) {
    return addresses[_key];
  }

  function _setAddress(bytes32 _key, address _value) internal {
    addresses[_key] = _value;
  }
}