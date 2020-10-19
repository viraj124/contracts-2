// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

/**
 * @title CoreLibrary library
 * @author Aave
 * @notice Defines the data structures of the reserves and the user data
 **/
library CoreLibrary {
  enum InterestRateMode {NONE, STABLE, VARIABLE}

  uint256 internal constant SECONDS_PER_YEAR = 365 days;

  struct UserReserveData {
    //principal amount borrowed by the user.
    uint256 principalBorrowBalance;
    //cumulated variable borrow index for the user. Expressed in ray
    uint256 lastVariableBorrowCumulativeIndex;
    //origination fee cumulated by the user
    uint256 originationFee;
    // stable borrow rate at which the user has borrowed. Expressed in ray
    uint256 stableBorrowRate;
    uint40 lastUpdateTimestamp;
    //defines if a specific deposit should or not be used as a collateral in borrows
    bool useAsCollateral;
  }

  struct ReserveData {
    // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
    //the liquidity index. Expressed in ray
    uint256 lastLiquidityCumulativeIndex;
    //the current supply rate. Expressed in ray
    uint256 currentLiquidityRate;
    //the total borrows of the reserve at a stable rate. Expressed in the currency decimals
    uint256 totalBorrowsStable;
    //the total borrows of the reserve at a variable rate. Expressed in the currency decimals
    uint256 totalBorrowsVariable;
    //the current variable borrow rate. Expressed in ray
    uint256 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint256 currentStableBorrowRate;
    //the current average stable borrow rate (weighted average of all the different stable rate loans). Expressed in ray
    uint256 currentAverageStableBorrowRate;
    //variable borrow index. Expressed in ray
    uint256 lastVariableBorrowCumulativeIndex;
    //the ltv of the reserve. Expressed in percentage (0-100)
    uint256 baseLTVasCollateral;
    //the liquidation threshold of the reserve. Expressed in percentage (0-100)
    uint256 liquidationThreshold;
    //the liquidation bonus of the reserve. Expressed in percentage
    uint256 liquidationBonus;
    //the decimals of the reserve asset
    uint256 decimals;
    // address of the aToken representing the asset
    address aTokenAddress;
    // address of the interest rate strategy contract
    address interestRateStrategyAddress;
    uint40 lastUpdateTimestamp;
    // borrowingEnabled = true means users can borrow from this reserve
    bool borrowingEnabled;
    // usageAsCollateralEnabled = true means users can use this reserve as collateral
    bool usageAsCollateralEnabled;
    // isStableBorrowRateEnabled = true means users can borrow at a stable rate
    bool isStableBorrowRateEnabled;
    // isActive = true means the reserve has been activated and properly configured
    bool isActive;
    // isFreezed = true means the reserve only allows repays and redeems, but not deposits, new borrowings or rate swap
    bool isFreezed;
  }
}
