// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyTestNFT is ERC721 {
  constructor() public ERC721("MyTestNFT", "NAZ") {
    _mint(msg.sender, 0);
    _mint(msg.sender, 1);
    _mint(msg.sender, 2);
    _mint(msg.sender, 3);
    _mint(msg.sender, 4);
  }
}
