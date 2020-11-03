// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../node_modules/@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";

import "./RentNftResolver.sol";

contract RentNftV2 is ReentrancyGuard, Ownable, ERC721Holder, ERC1155Holder {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // TODO: if there are defaults, mark the address to forbid from renting

    struct Listing {
        address lender;
        address nftAddress;
        uint256 tokenId;
        uint256 maxDuration;    // max borrow duration in days
        uint256 dailyPrice;     // how much the borrower has to pay irrevocably daily (per nft)
        uint256 nftPrice;       // how much lender will receive as collateral if borrower does not return nft in time
        bool isERC1155;         // else ERC721
        uint256 qtyLeft;        // no. of NFTs left to be rented out. {max(qtyLeft) = 1 for ERC721}
    }
    Listing[] public listings;
    
    struct Rental {
        address borrower;
        uint256 listingIndex;       // corresponding index in listings
        uint256 qty;                // qty of NFTs borrowed
        uint256 actualDuration;     // actual duration borrower will have the NFT for
        uint256 borrowedAt;         // time at which nft is borrowed
    }
    Rental[] public rentals;
    
    RentNftResolver public resolver;
    constructor(address _resolverAddress) public {
        resolver = RentNftResolver(_resolverAddress);
    }
    
    // lend one nft (any qty) that you own to be borrowable on Rent NFT
    function lendOne(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _maxDuration,
        uint256 _dailyPrice,
        uint256 _nftPrice,
        bool _isERC1155,
        uint256 _totalQty
    ) public nonReentrant {
        require(_nftAddress != address(0), "invalid NFT address");
        require(_maxDuration > 0, "at least one day");
        
        uint256 qty = 1;
        // transfer nft to this contract. will fail if nft wasn't approved
        if(_isERC1155) {
            IERC1155(_nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                _tokenId,
                _totalQty,
                ""
            );
            qty = _totalQty;
        } else {
            IERC721(_nftAddress).safeTransferFrom(
                msg.sender, 
                address(this), 
                _tokenId
            );
        }
        
        listings.push(Listing({
            lender: msg.sender,
            nftAddress: _nftAddress,
            tokenId: _tokenId,
            maxDuration: _maxDuration,
            dailyPrice: _dailyPrice,
            nftPrice: _nftPrice,
            isERC1155: _isERC1155,
            qtyLeft: qty
        }));
    }
    
    function rentOne(
        address _borrower,
        uint256 _listingIndex,
        uint256 _qtyToBorrow,
        uint256 _actualDuration
    ) public nonReentrant {
        Listing storage listing = listings[_listingIndex];
        // is NFT not listed, then too qtyLeft=0
        require(listing.qtyLeft >= _qtyToBorrow && _qtyToBorrow != 0, "Insuffient Qty");
        require(_borrower != listing.lender, "can't borrow own nft");
        require(_actualDuration <= listing.maxDuration, "Max Duration exceeded");
        
        // ! will fail if wasn't approved
        // pay the NFT owner the rent price
        uint256 rentPrice = _actualDuration.mul(listing.dailyPrice).mul(_qtyToBorrow);
        IERC20(resolver.getDai()).safeTransferFrom(
            _borrower, 
            listing.lender, 
            rentPrice
        );
        // collateral, our contracts acts as an escrow
        IERC20(resolver.getDai()).safeTransferFrom(
          _borrower,
          address(this),
          listing.nftPrice.mul(_qtyToBorrow)
        );
        
        // save details
        rentals.push(Rental({
            borrower: _borrower,
            listingIndex: _listingIndex,
            qty: _qtyToBorrow,
            actualDuration: _actualDuration,
            borrowedAt: now
        }));
        // deduct from total
        listing.qtyLeft = listing.qtyLeft.sub(_qtyToBorrow);
        
        // transfer NFT to borrower
        if(listing.isERC1155) {
            IERC1155(listing.nftAddress).safeTransferFrom(
                address(this),
                _borrower,
                listing.tokenId,
                _qtyToBorrow,
                ""
            );
        } else {
            IERC721(listing.nftAddress).safeTransferFrom(
                address(this),
                _borrower,
                listing.tokenId
            );
        }
    }
    
    // return specific qty of NFTs back
    function returnNftOne(
        uint256 _rentalIndex,
        uint256 _qtyToReturn
    ) public nonReentrant {
        Rental storage rental = rentals[_rentalIndex];
        Listing storage listing = listings[rental.listingIndex];
        
        require(rental.borrower == msg.sender, "not borrower");
        uint256 durationInDays = now.sub(rental.borrowedAt).div(86400);
        require(durationInDays <= rental.actualDuration, "duration exceeded");
        require(_qtyToReturn <= rental.qty, "excess qty");
        
        // we are returning back to the contract so that the owner does not have to add
        // it multiple times thus incurring the transaction costs
        uint256 qty = 1;
        if(listing.isERC1155) {
            IERC1155(listing.nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                listing.tokenId,
                _qtyToReturn,
                ""
            );
            qty = _qtyToReturn;
        } else {
            IERC721(listing.nftAddress).safeTransferFrom(
                msg.sender,
                address(this),
                listing.tokenId
            );
        }
        
        // update details
        rental.qty = rental.qty.sub(qty);
        // add back to total
        listing.qtyLeft = listing.qtyLeft.add(qty);
        
        
        // send collateral back for the qty of NFTs returned
        IERC20(resolver.getDai()).safeTransfer(
            msg.sender,
            listing.nftPrice.mul(qty)
        );
    }
    
    function claimCollateral(
        uint256 _rentalIndex
    ) public nonReentrant {
        Rental storage rental = rentals[_rentalIndex];
        Listing storage listing = listings[rental.listingIndex];
        
        require(listing.lender == msg.sender, "not lender");
        require(rental.qty > 0, "nft not lent out");
        
        uint256 durationInDays = now.sub(rental.borrowedAt).div(86400);
        require(durationInDays > rental.actualDuration, "duration not exceeded");
    
        IERC20(resolver.getDai()).safeTransfer(
            msg.sender,
            listing.nftPrice.mul(rental.qty)
        );
    }
    
    function getListingCount() external view returns (uint256) {
        return listings.length;
    }
    function getRentalCount() external view returns (uint256) {
        return rentals.length;
    }
}