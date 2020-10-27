// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GanFaceNft is ERC721, ReentrancyGuard {
  using Counters for Counters.Counter;
  Counters.Counter private __tokenIds;

  event NewFace(
    address indexed owner,
    uint256 indexed tokenId,
    string tokenURI
  );

  constructor() public ERC721("GANFACE", "GF") {}

  function awardGanFace(address _minter, string memory _tokenURI)
    public
    nonReentrant
    returns (uint256)
  {
    __tokenIds.increment();

    uint256 newItemId = __tokenIds.current();
    _mint(_minter, newItemId);
    _setTokenURI(newItemId, _tokenURI);

    emit NewFace(_minter, newItemId, _tokenURI);

    return newItemId;
  }
}
