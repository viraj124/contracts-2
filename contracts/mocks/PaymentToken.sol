// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PaymentToken is ERC20 {
  constructor() public ERC20("DAI", "DAI") {
    _mint(address(msg.sender), 1000000000000000000000000000000000);
  }
}
