pragma solidity ^0.6.0;

import "https://raw.githubusercontent.com/smartcontractkit/chainlink/develop/evm-contracts/src/v0.6/ChainlinkClient.sol";

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        int256 a,
        int256 b,
        string memory errorMessage
    ) internal pure returns (int256) {
        require(b <= a, errorMessage);
        int256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        int256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(int256 a, int256 b) internal pure returns (int256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        int256 a,
        int256 b,
        string memory errorMessage
    ) internal pure returns (int256) {
        require(b > 0, errorMessage);
        int256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(int256 a, int256 b) internal pure returns (int256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        int256 a,
        int256 b,
        string memory errorMessage
    ) internal pure returns (int256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

interface AToken {
    /**
     * @dev redirects the interest generated to a target address.
     * when the interest is redirected, the user's balance is added to
     * the recepient's redirected balance.
     * @param _to the address to which the interest will be redirected
     **/
    function redirectInterestStream(address _to) external;

    /**
     * @dev calculates the balance of the user, which is the
     * principal balance + interest generated by the principal balance +
     * interest generated by the redirected balance
     * @param _user the user for which the balance is being calculated
     * @return the total balance of the user
     **/
    function balanceOf(address _user) external view returns (uint256);
}

// Aave Lending Pool Interface
interface LendingPool {
    function deposit(
        address _reserve,
        uint256 _amount,
        uint16 _referralCode
    ) external;
}

// solium-disable security/no-inline-assembly
// solium-disable security/no-low-level-calls
// Open Zepplin proxy factory to create a proxy contract to monitor aave interest for a partcular owner - leasee pair
contract ProxyFactory {
    event ProxyCreated(address proxy);

    function deployMinimal(address _logic, bytes memory _data)
        public
        returns (address proxy)
    {
        // Adapted from https://github.com/optionality/clone-factory/blob/32782f82dfc5a00d103a7e61a17a5dedbd1e8e9d/contracts/CloneFactory.sol
        bytes20 targetBytes = bytes20(_logic);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            proxy := create(0, clone, 0x37)
        }

        emit ProxyCreated(address(proxy));

        if (_data.length > 0) {
            (bool success, ) = proxy.call(_data);
            require(success, "constructor call failed");
        }
    }
}

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

/**
 * @title Initializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 */
contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private initializing;

    /**
     * @dev Modifier to use in the initializer function of a contract.
     */
    modifier initializer() {
        require(
            initializing || isConstructor() || !initialized,
            "Contract instance has already been initialized"
        );

        bool isTopLevelCall = !initializing;
        if (isTopLevelCall) {
            initializing = true;
            initialized = true;
        }

        _;

        if (isTopLevelCall) {
            initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        assembly {
            cs := extcodesize(self)
        }
        return cs == 0;
    }

    // Reserved storage space to allow for layout changes in the future.
    uint256[50] private ______gap;
}

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract ContextUpgradeSafe is Initializable {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.

    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {}

    function _msgSender() internal virtual view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal virtual view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }

    uint256[50] private __gap;
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract OwnableUpgradeSafe is Initializable, ContextUpgradeSafe {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */

    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    uint256[49] private __gap;
}

contract InterestCalculatorProxy is Helper, Initializable, OwnableUpgradeSafe {
    event Initialized(address indexed thisAddress);

    // proxy admin would be thw owner to prevent in fraud cases where user doesn't return the nft back
    function initialize(address _owner) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        OwnableUpgradeSafe.transferOwnership(_owner);
        emit Initialized(address(this));
    }

    function claimInterest() external view returns (uint256) {
        // All calculations to be done in the parent contract
        return AToken(getADAI()).balanceOf(address(this));
    }
}

contract Rentft is ProxyFactory, ChainlinkClient, InterestCalculatorProxy {
    using SafeMath for uint256;

    uint256 nftPrice;

    struct Asset {
        address owner;
        address borrower;
        uint256 duration;
        uint256 price;
        uint256 rent;
    }

    // proxy details
    // owner => borrower => proxy
    mapping(address => mapping(address => address)) public proxyInfo;

    // nft address => token id => asset info struct
    mapping(address => mapping(uint256 => Asset)) public assets;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    /**
     * Network: Kovan
     * Oracle: Chainlink - 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e
     * Job ID: Chainlink - 29fa9aa13bf1468788b7cc4a500a45b8
     * Link: 0xa36085F69e2889c224210F603D836748e7dC0088
     * Fee: 0.1 LINK
     */
    constructor() public {
        setPublicChainlinkToken();
        oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10**18; // 0.1 LINK
    }

    // function to list the nft on the platform, url will be dynamic constructed on the js side
    function addProduct(
        address nftAddress,
        uint256 nftId,
        uint256 duration,
        string calldata _url
    ) external {
        require(nftAddress != address(0), "Invalid NFT Address");
        Chainlink.Request memory request = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );

        // Set the URL to perform the GET request on
        request.add("get", _url);

        // Set the path to find the desired data in the API response, where the response format is:
        request.add("path", "last_sale.payment_token.usd_price");

        // Multiply the result by 100 to remove decimals
        request.addInt("times", 1000000000000000000);

        // Sends the request
        sendChainlinkRequestTo(oracle, request, fee);

        // need to verify whether the nftPrice will have the latest value
        assets[nftAddress][nftId] = Asset(
            msg.sender,
            address(0),
            duration,
            nftPrice,
            0
        );
    }

    // create the proxy contract for managing interest when a user rents it out
    function createProxy(address _owner, address _user) internal {
        bytes memory _payload = abi.encodeWithSignature(
            "initialize(address)",
            _owner
        );
        // Deploy proxy
        // for testing the the address of the proxy contract whoch will be used to redirect interest will come here
        address _intermediate = deployMinimal(oracle, _payload);
        // user address is just recorded for tracking the proxy for the particular pair
        // TODO: need to test this for same owner but different user
        proxyInfo[_owner][_user] = _intermediate;
    }

    // check whether the proxy contract exists or not for a owner-user pair
    function getProxy(address _owner, address _user)
        public
        view
        returns (address)
    {
        return proxyInfo[_owner][_user];
    }

    /**
     * Receive the price response in the form of uint256
     */
    function fulfill(bytes32 _requestId, uint256 _price)
        public
        recordChainlinkFulfillment(_requestId)
    {
        nftPrice = _price;
    }
}
