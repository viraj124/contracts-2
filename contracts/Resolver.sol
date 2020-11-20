// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./configuration/AddressStorage.sol";

contract Resolver is Ownable, AddressStorage {
  enum DataType {PaymentToken}

  function getPaymentToken(uint8 _pt) public view returns (IERC20) {
    return
      IERC20(
        getAddress(keccak256(abi.encodePacked(DataType.PaymentToken, _pt)))
      );
  }

  function setPaymentToken(uint8 _pt, IERC20 _v) public onlyOwner {
    _setAddress(
      keccak256(abi.encodePacked(DataType.PaymentToken, _pt)),
      address(_v)
    );
  }
}
