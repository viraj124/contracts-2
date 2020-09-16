// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Helper {
  /**
   * @dev get Lending Pool kovan address
   */
  function getLendingPool() public pure returns (address lendingpool) {
    lendingpool = 0x580D4Fdc4BF8f9b5ae2fb9225D584fED4AD5375c;
  }

  /**
   * @dev get adai kovan address
   */
  function getADAI() public pure returns (address adai) {
    adai = 0x58AD4cB396411B691A9AAb6F74545b2C5217FE6a;
  }
}
