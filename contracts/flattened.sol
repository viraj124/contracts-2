// File: @chainlink/contracts/src/v0.6/vendor/Buffer.sol

pragma solidity ^0.6.0;

/**
* @dev A library for working with mutable byte buffers in Solidity.
*
* Byte buffers are mutable and expandable, and provide a variety of primitives
* for writing to them. At any time you can fetch a bytes object containing the
* current contents of the buffer. The bytes object should not be stored between
* operations, as it may change due to resizing of the buffer.
*/
library Buffer_Chainlink {
  /**
  * @dev Represents a mutable buffer. Buffers have a current value (buf) and
  *      a capacity. The capacity may be longer than the current value, in
  *      which case it can be extended without the need to allocate more memory.
  */
  struct buffer {
    bytes buf;
    uint capacity;
  }

  /**
  * @dev Initializes a buffer with an initial capacity.
  * @param buf The buffer to initialize.
  * @param capacity The number of bytes of space to allocate the buffer.
  * @return The buffer, for chaining.
  */
  function init(buffer memory buf, uint capacity) internal pure returns(buffer memory) {
    if (capacity % 32 != 0) {
      capacity += 32 - (capacity % 32);
    }
    // Allocate space for the buffer data
    buf.capacity = capacity;
    assembly {
      let ptr := mload(0x40)
      mstore(buf, ptr)
      mstore(ptr, 0)
      mstore(0x40, add(32, add(ptr, capacity)))
    }
    return buf;
  }

  /**
  * @dev Initializes a new buffer from an existing bytes object.
  *      Changes to the buffer may mutate the original value.
  * @param b The bytes object to initialize the buffer with.
  * @return A new buffer.
  */
  function fromBytes(bytes memory b) internal pure returns(buffer memory) {
    buffer memory buf;
    buf.buf = b;
    buf.capacity = b.length;
    return buf;
  }

  function resize(buffer memory buf, uint capacity) private pure {
    bytes memory oldbuf = buf.buf;
    init(buf, capacity);
    append(buf, oldbuf);
  }

  function max(uint a, uint b) private pure returns(uint) {
    if (a > b) {
      return a;
    }
    return b;
  }

  /**
  * @dev Sets buffer length to 0.
  * @param buf The buffer to truncate.
  * @return The original buffer, for chaining..
  */
  function truncate(buffer memory buf) internal pure returns (buffer memory) {
    assembly {
      let bufptr := mload(buf)
      mstore(bufptr, 0)
    }
    return buf;
  }

  /**
  * @dev Writes a byte string to a buffer. Resizes if doing so would exceed
  *      the capacity of the buffer.
  * @param buf The buffer to append to.
  * @param off The start offset to write to.
  * @param data The data to append.
  * @param len The number of bytes to copy.
  * @return The original buffer, for chaining.
  */
  function write(buffer memory buf, uint off, bytes memory data, uint len) internal pure returns(buffer memory) {
    require(len <= data.length);

    if (off + len > buf.capacity) {
      resize(buf, max(buf.capacity, len + off) * 2);
    }

    uint dest;
    uint src;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Start address = buffer address + offset + sizeof(buffer length)
      dest := add(add(bufptr, 32), off)
      // Update buffer length if we're extending it
      if gt(add(len, off), buflen) {
        mstore(bufptr, add(len, off))
      }
      src := add(data, 32)
    }

    // Copy word-length chunks while possible
    for (; len >= 32; len -= 32) {
      assembly {
        mstore(dest, mload(src))
      }
      dest += 32;
      src += 32;
    }

    // Copy remaining bytes
    uint mask = 256 ** (32 - len) - 1;
    assembly {
      let srcpart := and(mload(src), not(mask))
      let destpart := and(mload(dest), mask)
      mstore(dest, or(destpart, srcpart))
    }

    return buf;
  }

  /**
  * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
  *      the capacity of the buffer.
  * @param buf The buffer to append to.
  * @param data The data to append.
  * @param len The number of bytes to copy.
  * @return The original buffer, for chaining.
  */
  function append(buffer memory buf, bytes memory data, uint len) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, len);
  }

  /**
  * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
  *      the capacity of the buffer.
  * @param buf The buffer to append to.
  * @param data The data to append.
  * @return The original buffer, for chaining.
  */
  function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, data.length);
  }

  /**
  * @dev Writes a byte to the buffer. Resizes if doing so would exceed the
  *      capacity of the buffer.
  * @param buf The buffer to append to.
  * @param off The offset to write the byte at.
  * @param data The data to append.
  * @return The original buffer, for chaining.
  */
  function writeUint8(buffer memory buf, uint off, uint8 data) internal pure returns(buffer memory) {
    if (off >= buf.capacity) {
      resize(buf, buf.capacity * 2);
    }

    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Length of existing buffer data
      let buflen := mload(bufptr)
      // Address = buffer address + sizeof(buffer length) + off
      let dest := add(add(bufptr, off), 32)
      mstore8(dest, data)
      // Update buffer length if we extended it
      if eq(off, buflen) {
        mstore(bufptr, add(buflen, 1))
      }
    }
    return buf;
  }

  /**
  * @dev Appends a byte to the buffer. Resizes if doing so would exceed the
  *      capacity of the buffer.
  * @param buf The buffer to append to.
  * @param data The data to append.
  * @return The original buffer, for chaining.
  */
  function appendUint8(buffer memory buf, uint8 data) internal pure returns(buffer memory) {
    return writeUint8(buf, buf.buf.length, data);
  }

  /**
  * @dev Writes up to 32 bytes to the buffer. Resizes if doing so would
  *      exceed the capacity of the buffer.
  * @param buf The buffer to append to.
  * @param off The offset to write at.
  * @param data The data to append.
  * @param len The number of bytes to write (left-aligned).
  * @return The original buffer, for chaining.
  */
  function write(buffer memory buf, uint off, bytes32 data, uint len) private pure returns(buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    uint mask = 256 ** len - 1;
    // Right-align data
    data = data >> (8 * (32 - len));
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Address = buffer address + sizeof(buffer length) + off + len
      let dest := add(add(bufptr, off), len)
      mstore(dest, or(and(mload(dest), not(mask)), data))
      // Update buffer length if we extended it
      if gt(add(off, len), mload(bufptr)) {
        mstore(bufptr, add(off, len))
      }
    }
    return buf;
  }

  /**
  * @dev Writes a bytes20 to the buffer. Resizes if doing so would exceed the
  *      capacity of the buffer.
  * @param buf The buffer to append to.
  * @param off The offset to write at.
  * @param data The data to append.
  * @return The original buffer, for chaining.
  */
  function writeBytes20(buffer memory buf, uint off, bytes20 data) internal pure returns (buffer memory) {
    return write(buf, off, bytes32(data), 20);
  }

  /**
  * @dev Appends a bytes20 to the buffer. Resizes if doing so would exceed
  *      the capacity of the buffer.
  * @param buf The buffer to append to.
  * @param data The data to append.
  * @return The original buffer, for chhaining.
  */
  function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, bytes32(data), 20);
  }

  /**
  * @dev Appends a bytes32 to the buffer. Resizes if doing so would exceed
  *      the capacity of the buffer.
  * @param buf The buffer to append to.
  * @param data The data to append.
  * @return The original buffer, for chaining.
  */
  function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory) {
    return write(buf, buf.buf.length, data, 32);
  }

  /**
  * @dev Writes an integer to the buffer. Resizes if doing so would exceed
  *      the capacity of the buffer.
  * @param buf The buffer to append to.
  * @param off The offset to write at.
  * @param data The data to append.
  * @param len The number of bytes to write (right-aligned).
  * @return The original buffer, for chaining.
  */
  function writeInt(buffer memory buf, uint off, uint data, uint len) private pure returns(buffer memory) {
    if (len + off > buf.capacity) {
      resize(buf, (len + off) * 2);
    }

    uint mask = 256 ** len - 1;
    assembly {
      // Memory address of the buffer data
      let bufptr := mload(buf)
      // Address = buffer address + off + sizeof(buffer length) + len
      let dest := add(add(bufptr, off), len)
      mstore(dest, or(and(mload(dest), not(mask)), data))
      // Update buffer length if we extended it
      if gt(add(off, len), mload(bufptr)) {
        mstore(bufptr, add(off, len))
      }
    }
    return buf;
  }

  /**
    * @dev Appends a byte to the end of the buffer. Resizes if doing so would
    * exceed the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @return The original buffer.
    */
  function appendInt(buffer memory buf, uint data, uint len) internal pure returns(buffer memory) {
    return writeInt(buf, buf.buf.length, data, len);
  }
}

// File: @chainlink/contracts/src/v0.6/vendor/CBOR.sol

pragma solidity ^0.6.0;


library CBOR {
  using Buffer_Chainlink for Buffer_Chainlink.buffer;

  uint8 private constant MAJOR_TYPE_INT = 0;
  uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
  uint8 private constant MAJOR_TYPE_BYTES = 2;
  uint8 private constant MAJOR_TYPE_STRING = 3;
  uint8 private constant MAJOR_TYPE_ARRAY = 4;
  uint8 private constant MAJOR_TYPE_MAP = 5;
  uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

  function encodeType(Buffer_Chainlink.buffer memory buf, uint8 major, uint value) private pure {
    if(value <= 23) {
      buf.appendUint8(uint8((major << 5) | value));
    } else if(value <= 0xFF) {
      buf.appendUint8(uint8((major << 5) | 24));
      buf.appendInt(value, 1);
    } else if(value <= 0xFFFF) {
      buf.appendUint8(uint8((major << 5) | 25));
      buf.appendInt(value, 2);
    } else if(value <= 0xFFFFFFFF) {
      buf.appendUint8(uint8((major << 5) | 26));
      buf.appendInt(value, 4);
    } else if(value <= 0xFFFFFFFFFFFFFFFF) {
      buf.appendUint8(uint8((major << 5) | 27));
      buf.appendInt(value, 8);
    }
  }

  function encodeIndefiniteLengthType(Buffer_Chainlink.buffer memory buf, uint8 major) private pure {
    buf.appendUint8(uint8((major << 5) | 31));
  }

  function encodeUInt(Buffer_Chainlink.buffer memory buf, uint value) internal pure {
    encodeType(buf, MAJOR_TYPE_INT, value);
  }

  function encodeInt(Buffer_Chainlink.buffer memory buf, int value) internal pure {
    if(value >= 0) {
      encodeType(buf, MAJOR_TYPE_INT, uint(value));
    } else {
      encodeType(buf, MAJOR_TYPE_NEGATIVE_INT, uint(-1 - value));
    }
  }

  function encodeBytes(Buffer_Chainlink.buffer memory buf, bytes memory value) internal pure {
    encodeType(buf, MAJOR_TYPE_BYTES, value.length);
    buf.append(value);
  }

  function encodeString(Buffer_Chainlink.buffer memory buf, string memory value) internal pure {
    encodeType(buf, MAJOR_TYPE_STRING, bytes(value).length);
    buf.append(bytes(value));
  }

  function startArray(Buffer_Chainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_ARRAY);
  }

  function startMap(Buffer_Chainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_MAP);
  }

  function endSequence(Buffer_Chainlink.buffer memory buf) internal pure {
    encodeIndefiniteLengthType(buf, MAJOR_TYPE_CONTENT_FREE);
  }
}

// File: @chainlink/contracts/src/v0.6/Chainlink.sol

pragma solidity ^0.6.0;



/**
 * @title Library for common Chainlink functions
 * @dev Uses imported CBOR library for encoding to buffer
 */
library Chainlink {
  uint256 internal constant defaultBufferSize = 256; // solhint-disable-line const-name-snakecase

  using CBOR for Buffer_Chainlink.buffer;

  struct Request {
    bytes32 id;
    address callbackAddress;
    bytes4 callbackFunctionId;
    uint256 nonce;
    Buffer_Chainlink.buffer buf;
  }

  /**
   * @notice Initializes a Chainlink request
   * @dev Sets the ID, callback address, and callback function signature on the request
   * @param self The uninitialized request
   * @param _id The Job Specification ID
   * @param _callbackAddress The callback address
   * @param _callbackFunction The callback function signature
   * @return The initialized request
   */
  function initialize(
    Request memory self,
    bytes32 _id,
    address _callbackAddress,
    bytes4 _callbackFunction
  ) internal pure returns (Chainlink.Request memory) {
    Buffer_Chainlink.init(self.buf, defaultBufferSize);
    self.id = _id;
    self.callbackAddress = _callbackAddress;
    self.callbackFunctionId = _callbackFunction;
    return self;
  }

  /**
   * @notice Sets the data for the buffer without encoding CBOR on-chain
   * @dev CBOR can be closed with curly-brackets {} or they can be left off
   * @param self The initialized request
   * @param _data The CBOR data
   */
  function setBuffer(Request memory self, bytes memory _data)
    internal pure
  {
    Buffer_Chainlink.init(self.buf, _data.length);
    Buffer_Chainlink.append(self.buf, _data);
  }

  /**
   * @notice Adds a string value to the request with a given key name
   * @param self The initialized request
   * @param _key The name of the key
   * @param _value The string value to add
   */
  function add(Request memory self, string memory _key, string memory _value)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.encodeString(_value);
  }

  /**
   * @notice Adds a bytes value to the request with a given key name
   * @param self The initialized request
   * @param _key The name of the key
   * @param _value The bytes value to add
   */
  function addBytes(Request memory self, string memory _key, bytes memory _value)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.encodeBytes(_value);
  }

  /**
   * @notice Adds a int256 value to the request with a given key name
   * @param self The initialized request
   * @param _key The name of the key
   * @param _value The int256 value to add
   */
  function addInt(Request memory self, string memory _key, int256 _value)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.encodeInt(_value);
  }

  /**
   * @notice Adds a uint256 value to the request with a given key name
   * @param self The initialized request
   * @param _key The name of the key
   * @param _value The uint256 value to add
   */
  function addUint(Request memory self, string memory _key, uint256 _value)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.encodeUInt(_value);
  }

  /**
   * @notice Adds an array of strings to the request with a given key name
   * @param self The initialized request
   * @param _key The name of the key
   * @param _values The array of string values to add
   */
  function addStringArray(Request memory self, string memory _key, string[] memory _values)
    internal pure
  {
    self.buf.encodeString(_key);
    self.buf.startArray();
    for (uint256 i = 0; i < _values.length; i++) {
      self.buf.encodeString(_values[i]);
    }
    self.buf.endSequence();
  }
}

// File: @chainlink/contracts/src/v0.6/interfaces/ENSInterface.sol

pragma solidity ^0.6.0;

interface ENSInterface {

  // Logged when the owner of a node assigns a new owner to a subnode.
  event NewOwner(bytes32 indexed node, bytes32 indexed label, address owner);

  // Logged when the owner of a node transfers ownership to a new account.
  event Transfer(bytes32 indexed node, address owner);

  // Logged when the resolver for a node changes.
  event NewResolver(bytes32 indexed node, address resolver);

  // Logged when the TTL of a node changes
  event NewTTL(bytes32 indexed node, uint64 ttl);


  function setSubnodeOwner(bytes32 node, bytes32 label, address _owner) external;
  function setResolver(bytes32 node, address _resolver) external;
  function setOwner(bytes32 node, address _owner) external;
  function setTTL(bytes32 node, uint64 _ttl) external;
  function owner(bytes32 node) external view returns (address);
  function resolver(bytes32 node) external view returns (address);
  function ttl(bytes32 node) external view returns (uint64);

}

// File: @chainlink/contracts/src/v0.6/interfaces/LinkTokenInterface.sol

pragma solidity ^0.6.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);
  function approve(address spender, uint256 value) external returns (bool success);
  function balanceOf(address owner) external view returns (uint256 balance);
  function decimals() external view returns (uint8 decimalPlaces);
  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);
  function increaseApproval(address spender, uint256 subtractedValue) external;
  function name() external view returns (string memory tokenName);
  function symbol() external view returns (string memory tokenSymbol);
  function totalSupply() external view returns (uint256 totalTokensIssued);
  function transfer(address to, uint256 value) external returns (bool success);
  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);
  function transferFrom(address from, address to, uint256 value) external returns (bool success);
}

// File: @chainlink/contracts/src/v0.6/interfaces/ChainlinkRequestInterface.sol

pragma solidity ^0.6.0;

interface ChainlinkRequestInterface {
  function oracleRequest(
    address sender,
    uint256 requestPrice,
    bytes32 serviceAgreementID,
    address callbackAddress,
    bytes4 callbackFunctionId,
    uint256 nonce,
    uint256 dataVersion, // Currently unused, always "1"
    bytes calldata data
  ) external;

  function cancelOracleRequest(
    bytes32 requestId,
    uint256 payment,
    bytes4 callbackFunctionId,
    uint256 expiration
  ) external;
}

// File: @chainlink/contracts/src/v0.6/interfaces/PointerInterface.sol

pragma solidity ^0.6.0;

interface PointerInterface {
  function getAddress() external view returns (address);
}

// File: @chainlink/contracts/src/v0.6/vendor/ENSResolver.sol

pragma solidity ^0.6.0;

abstract contract ENSResolver {
  function addr(bytes32 node) public view virtual returns (address);
}

// File: @chainlink/contracts/src/v0.6/vendor/SafeMath.sol

pragma solidity ^0.6.0;

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
    * - Addition cannot overflow.
    */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
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
    * - Subtraction cannot overflow.
    */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a, "SafeMath: subtraction overflow");
    uint256 c = a - b;

    return c;
  }

  /**
    * @dev Returns the multiplication of two unsigned integers, reverting on
    * overflow.
    *
    * Counterpart to Solidity's `*` operator.
    *
    * Requirements:
    * - Multiplication cannot overflow.
    */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
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
    * - The divisor cannot be zero.
    */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // Solidity only automatically asserts when dividing by 0
    require(b > 0, "SafeMath: division by zero");
    uint256 c = a / b;
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
    * - The divisor cannot be zero.
    */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, "SafeMath: modulo by zero");
    return a % b;
  }
}

// File: @chainlink/contracts/src/v0.6/ChainlinkClient.sol

pragma solidity ^0.6.0;



/**
 * @title The ChainlinkClient contract
 * @notice Contract writers can inherit this contract in order to create requests for the
 * Chainlink network
 */
contract ChainlinkClient {
  using Chainlink for Chainlink.Request;
  using SafeMath for uint256;

  uint256 constant internal LINK = 10**18;
  uint256 constant private AMOUNT_OVERRIDE = 0;
  address constant private SENDER_OVERRIDE = address(0);
  uint256 constant private ARGS_VERSION = 1;
  bytes32 constant private ENS_TOKEN_SUBNAME = keccak256("link");
  bytes32 constant private ENS_ORACLE_SUBNAME = keccak256("oracle");
  address constant private LINK_TOKEN_POINTER = 0xC89bD4E1632D3A43CB03AAAd5262cbe4038Bc571;

  ENSInterface private ens;
  bytes32 private ensNode;
  LinkTokenInterface private link;
  ChainlinkRequestInterface private oracle;
  uint256 private requestCount = 1;
  mapping(bytes32 => address) private pendingRequests;

  event ChainlinkRequested(bytes32 indexed id);
  event ChainlinkFulfilled(bytes32 indexed id);
  event ChainlinkCancelled(bytes32 indexed id);

  /**
   * @notice Creates a request that can hold additional parameters
   * @param _specId The Job Specification ID that the request will be created for
   * @param _callbackAddress The callback address that the response will be sent to
   * @param _callbackFunctionSignature The callback function signature to use for the callback address
   * @return A Chainlink Request struct in memory
   */
  function buildChainlinkRequest(
    bytes32 _specId,
    address _callbackAddress,
    bytes4 _callbackFunctionSignature
  ) internal pure returns (Chainlink.Request memory) {
    Chainlink.Request memory req;
    return req.initialize(_specId, _callbackAddress, _callbackFunctionSignature);
  }

  /**
   * @notice Creates a Chainlink request to the stored oracle address
   * @dev Calls `chainlinkRequestTo` with the stored oracle address
   * @param _req The initialized Chainlink Request
   * @param _payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendChainlinkRequest(Chainlink.Request memory _req, uint256 _payment)
    internal
    returns (bytes32)
  {
    return sendChainlinkRequestTo(address(oracle), _req, _payment);
  }

  /**
   * @notice Creates a Chainlink request to the specified oracle address
   * @dev Generates and stores a request ID, increments the local nonce, and uses `transferAndCall` to
   * send LINK which creates a request on the target oracle contract.
   * Emits ChainlinkRequested event.
   * @param _oracle The address of the oracle for the request
   * @param _req The initialized Chainlink Request
   * @param _payment The amount of LINK to send for the request
   * @return requestId The request ID
   */
  function sendChainlinkRequestTo(address _oracle, Chainlink.Request memory _req, uint256 _payment)
    internal
    returns (bytes32 requestId)
  {
    requestId = keccak256(abi.encodePacked(this, requestCount));
    _req.nonce = requestCount;
    pendingRequests[requestId] = _oracle;
    emit ChainlinkRequested(requestId);
    require(link.transferAndCall(_oracle, _payment, encodeRequest(_req)), "unable to transferAndCall to oracle");
    requestCount += 1;

    return requestId;
  }

  /**
   * @notice Allows a request to be cancelled if it has not been fulfilled
   * @dev Requires keeping track of the expiration value emitted from the oracle contract.
   * Deletes the request from the `pendingRequests` mapping.
   * Emits ChainlinkCancelled event.
   * @param _requestId The request ID
   * @param _payment The amount of LINK sent for the request
   * @param _callbackFunc The callback function specified for the request
   * @param _expiration The time of the expiration for the request
   */
  function cancelChainlinkRequest(
    bytes32 _requestId,
    uint256 _payment,
    bytes4 _callbackFunc,
    uint256 _expiration
  )
    internal
  {
    ChainlinkRequestInterface requested = ChainlinkRequestInterface(pendingRequests[_requestId]);
    delete pendingRequests[_requestId];
    emit ChainlinkCancelled(_requestId);
    requested.cancelOracleRequest(_requestId, _payment, _callbackFunc, _expiration);
  }

  /**
   * @notice Sets the stored oracle address
   * @param _oracle The address of the oracle contract
   */
  function setChainlinkOracle(address _oracle) internal {
    oracle = ChainlinkRequestInterface(_oracle);
  }

  /**
   * @notice Sets the LINK token address
   * @param _link The address of the LINK token contract
   */
  function setChainlinkToken(address _link) internal {
    link = LinkTokenInterface(_link);
  }

  /**
   * @notice Sets the Chainlink token address for the public
   * network as given by the Pointer contract
   */
  function setPublicChainlinkToken() internal {
    setChainlinkToken(PointerInterface(LINK_TOKEN_POINTER).getAddress());
  }

  /**
   * @notice Retrieves the stored address of the LINK token
   * @return The address of the LINK token
   */
  function chainlinkTokenAddress()
    internal
    view
    returns (address)
  {
    return address(link);
  }

  /**
   * @notice Retrieves the stored address of the oracle contract
   * @return The address of the oracle contract
   */
  function chainlinkOracleAddress()
    internal
    view
    returns (address)
  {
    return address(oracle);
  }

  /**
   * @notice Allows for a request which was created on another contract to be fulfilled
   * on this contract
   * @param _oracle The address of the oracle contract that will fulfill the request
   * @param _requestId The request ID used for the response
   */
  function addChainlinkExternalRequest(address _oracle, bytes32 _requestId)
    internal
    notPendingRequest(_requestId)
  {
    pendingRequests[_requestId] = _oracle;
  }

  /**
   * @notice Sets the stored oracle and LINK token contracts with the addresses resolved by ENS
   * @dev Accounts for subnodes having different resolvers
   * @param _ens The address of the ENS contract
   * @param _node The ENS node hash
   */
  function useChainlinkWithENS(address _ens, bytes32 _node)
    internal
  {
    ens = ENSInterface(_ens);
    ensNode = _node;
    bytes32 linkSubnode = keccak256(abi.encodePacked(ensNode, ENS_TOKEN_SUBNAME));
    ENSResolver resolver = ENSResolver(ens.resolver(linkSubnode));
    setChainlinkToken(resolver.addr(linkSubnode));
    updateChainlinkOracleWithENS();
  }

  /**
   * @notice Sets the stored oracle contract with the address resolved by ENS
   * @dev This may be called on its own as long as `useChainlinkWithENS` has been called previously
   */
  function updateChainlinkOracleWithENS()
    internal
  {
    bytes32 oracleSubnode = keccak256(abi.encodePacked(ensNode, ENS_ORACLE_SUBNAME));
    ENSResolver resolver = ENSResolver(ens.resolver(oracleSubnode));
    setChainlinkOracle(resolver.addr(oracleSubnode));
  }

  /**
   * @notice Encodes the request to be sent to the oracle contract
   * @dev The Chainlink node expects values to be in order for the request to be picked up. Order of types
   * will be validated in the oracle contract.
   * @param _req The initialized Chainlink Request
   * @return The bytes payload for the `transferAndCall` method
   */
  function encodeRequest(Chainlink.Request memory _req)
    private
    view
    returns (bytes memory)
  {
    return abi.encodeWithSelector(
      oracle.oracleRequest.selector,
      SENDER_OVERRIDE, // Sender value - overridden by onTokenTransfer by the requesting contract's address
      AMOUNT_OVERRIDE, // Amount value - overridden by onTokenTransfer by the actual amount of LINK sent
      _req.id,
      _req.callbackAddress,
      _req.callbackFunctionId,
      _req.nonce,
      ARGS_VERSION,
      _req.buf.buf);
  }

  /**
   * @notice Ensures that the fulfillment is valid for this contract
   * @dev Use if the contract developer prefers methods instead of modifiers for validation
   * @param _requestId The request ID for fulfillment
   */
  function validateChainlinkCallback(bytes32 _requestId)
    internal
    recordChainlinkFulfillment(_requestId)
    // solhint-disable-next-line no-empty-blocks
  {}

  /**
   * @dev Reverts if the sender is not the oracle of the request.
   * Emits ChainlinkFulfilled event.
   * @param _requestId The request ID for fulfillment
   */
  modifier recordChainlinkFulfillment(bytes32 _requestId) {
    require(msg.sender == pendingRequests[_requestId],
            "Source must be the oracle of the request");
    delete pendingRequests[_requestId];
    emit ChainlinkFulfilled(_requestId);
    _;
  }

  /**
   * @dev Reverts if the request is already pending
   * @param _requestId The request ID for fulfillment
   */
  modifier notPendingRequest(bytes32 _requestId) {
    require(pendingRequests[_requestId] == address(0), "Request is already pending");
    _;
  }
}

// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File: @openzeppelin/contracts/utils/Address.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies in extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// File: @openzeppelin/contracts/token/ERC20/SafeERC20.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// File: @openzeppelin/contracts/GSN/Context.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;





/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// File: @openzeppelin/contracts/introspection/IERC165.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/token/ERC721/IERC721.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;


/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
      * @dev Safely transfers `tokenId` token from `from` to `to`.
      *
      * Requirements:
      *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
      * - `tokenId` token must exist and be owned by `from`.
      * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
      * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
      *
      * Emits a {Transfer} event.
      */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// File: @openzeppelin/contracts/token/ERC721/IERC721Metadata.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;


/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// File: @openzeppelin/contracts/token/ERC721/IERC721Enumerable.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;


/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {

    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
    external returns (bytes4);
}

// File: @openzeppelin/contracts/introspection/ERC165.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
contract ERC165 is IERC165 {
    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    constructor () internal {
        // Derived contracts need only register support for their own interfaces,
        // we register support for ERC165 itself here
        _registerInterface(_INTERFACE_ID_ERC165);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     *
     * Time complexity O(1), guaranteed to always use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See {IERC165-supportsInterface}.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}

// File: @openzeppelin/contracts/utils/EnumerableSet.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.0.0, only sets of type `address` (`AddressSet`) and `uint256`
 * (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;

        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) { // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            // When the value to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            bytes32 lastvalue = set._values[lastIndex];

            // Move the last value to the index where the value to delete is
            set._values[toDeleteIndex] = lastvalue;
            // Update the index for the moved value
            set._indexes[lastvalue] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        require(set._values.length > index, "EnumerableSet: index out of bounds");
        return set._values[index];
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(value)));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint256(_at(set._inner, index)));
    }


    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

   /**
    * @dev Returns the value stored at position `index` in the set. O(1).
    *
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }
}

// File: @openzeppelin/contracts/utils/EnumerableMap.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev Library for managing an enumerable variant of Solidity's
 * https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
 * type.
 *
 * Maps have the following properties:
 *
 * - Entries are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Entries are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableMap for EnumerableMap.UintToAddressMap;
 *
 *     // Declare a set state variable
 *     EnumerableMap.UintToAddressMap private myMap;
 * }
 * ```
 *
 * As of v3.0.0, only maps of type `uint256 -> address` (`UintToAddressMap`) are
 * supported.
 */
library EnumerableMap {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Map type with
    // bytes32 keys and values.
    // The Map implementation uses private functions, and user-facing
    // implementations (such as Uint256ToAddressMap) are just wrappers around
    // the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit
    // in bytes32.

    struct MapEntry {
        bytes32 _key;
        bytes32 _value;
    }

    struct Map {
        // Storage of map keys and values
        MapEntry[] _entries;

        // Position of the entry defined by a key in the `entries` array, plus 1
        // because index 0 means a key is not in the map.
        mapping (bytes32 => uint256) _indexes;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function _set(Map storage map, bytes32 key, bytes32 value) private returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];

        if (keyIndex == 0) { // Equivalent to !contains(map, key)
            map._entries.push(MapEntry({ _key: key, _value: value }));
            // The entry is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            map._indexes[key] = map._entries.length;
            return true;
        } else {
            map._entries[keyIndex - 1]._value = value;
            return false;
        }
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function _remove(Map storage map, bytes32 key) private returns (bool) {
        // We read and store the key's index to prevent multiple reads from the same storage slot
        uint256 keyIndex = map._indexes[key];

        if (keyIndex != 0) { // Equivalent to contains(map, key)
            // To delete a key-value pair from the _entries array in O(1), we swap the entry to delete with the last one
            // in the array, and then remove the last entry (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = keyIndex - 1;
            uint256 lastIndex = map._entries.length - 1;

            // When the entry to delete is the last one, the swap operation is unnecessary. However, since this occurs
            // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

            MapEntry storage lastEntry = map._entries[lastIndex];

            // Move the last entry to the index where the entry to delete is
            map._entries[toDeleteIndex] = lastEntry;
            // Update the index for the moved entry
            map._indexes[lastEntry._key] = toDeleteIndex + 1; // All indexes are 1-based

            // Delete the slot where the moved entry was stored
            map._entries.pop();

            // Delete the index for the deleted slot
            delete map._indexes[key];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function _contains(Map storage map, bytes32 key) private view returns (bool) {
        return map._indexes[key] != 0;
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function _length(Map storage map) private view returns (uint256) {
        return map._entries.length;
    }

   /**
    * @dev Returns the key-value pair stored at position `index` in the map. O(1).
    *
    * Note that there are no guarantees on the ordering of entries inside the
    * array, and it may change when more entries are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function _at(Map storage map, uint256 index) private view returns (bytes32, bytes32) {
        require(map._entries.length > index, "EnumerableMap: index out of bounds");

        MapEntry storage entry = map._entries[index];
        return (entry._key, entry._value);
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function _get(Map storage map, bytes32 key) private view returns (bytes32) {
        return _get(map, key, "EnumerableMap: nonexistent key");
    }

    /**
     * @dev Same as {_get}, with a custom error message when `key` is not in the map.
     */
    function _get(Map storage map, bytes32 key, string memory errorMessage) private view returns (bytes32) {
        uint256 keyIndex = map._indexes[key];
        require(keyIndex != 0, errorMessage); // Equivalent to contains(map, key)
        return map._entries[keyIndex - 1]._value; // All indexes are 1-based
    }

    // UintToAddressMap

    struct UintToAddressMap {
        Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(UintToAddressMap storage map, uint256 key, address value) internal returns (bool) {
        return _set(map._inner, bytes32(key), bytes32(uint256(value)));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToAddressMap storage map, uint256 key) internal returns (bool) {
        return _remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool) {
        return _contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToAddressMap storage map) internal view returns (uint256) {
        return _length(map._inner);
    }

   /**
    * @dev Returns the element stored at position `index` in the set. O(1).
    * Note that there are no guarantees on the ordering of values inside the
    * array, and it may change when more values are added or removed.
    *
    * Requirements:
    *
    * - `index` must be strictly less than {length}.
    */
    function at(UintToAddressMap storage map, uint256 index) internal view returns (uint256, address) {
        (bytes32 key, bytes32 value) = _at(map._inner, index);
        return (uint256(key), address(uint256(value)));
    }

    /**
     * @dev Returns the value associated with `key`.  O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToAddressMap storage map, uint256 key) internal view returns (address) {
        return address(uint256(_get(map._inner, bytes32(key))));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     */
    function get(UintToAddressMap storage map, uint256 key, string memory errorMessage) internal view returns (address) {
        return address(uint256(_get(map._inner, bytes32(key), errorMessage)));
    }
}

// File: @openzeppelin/contracts/utils/Strings.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

/**
 * @dev String operations.
 */
library Strings {
    /**
     * @dev Converts a `uint256` to its ASCII `string` representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = byte(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }
}

// File: @openzeppelin/contracts/token/ERC721/ERC721.sol

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;












/**
 * @title ERC721 Non-Fungible Token Standard basic implementation
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata, IERC721Enumerable {
    using SafeMath for uint256;
    using Address for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using Strings for uint256;

    // Equals to `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    // which can be also obtained as `IERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

    // Mapping from token ID to approved address
    mapping (uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping (address => mapping (address => bool)) private _operatorApprovals;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _baseURI;

    /*
     *     bytes4(keccak256('balanceOf(address)')) == 0x70a08231
     *     bytes4(keccak256('ownerOf(uint256)')) == 0x6352211e
     *     bytes4(keccak256('approve(address,uint256)')) == 0x095ea7b3
     *     bytes4(keccak256('getApproved(uint256)')) == 0x081812fc
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('transferFrom(address,address,uint256)')) == 0x23b872dd
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256)')) == 0x42842e0e
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,bytes)')) == 0xb88d4fde
     *
     *     => 0x70a08231 ^ 0x6352211e ^ 0x095ea7b3 ^ 0x081812fc ^
     *        0xa22cb465 ^ 0xe985e9c5 ^ 0x23b872dd ^ 0x42842e0e ^ 0xb88d4fde == 0x80ac58cd
     */
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd == 0x5b5e139f
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x5b5e139f;

    /*
     *     bytes4(keccak256('totalSupply()')) == 0x18160ddd
     *     bytes4(keccak256('tokenOfOwnerByIndex(address,uint256)')) == 0x2f745c59
     *     bytes4(keccak256('tokenByIndex(uint256)')) == 0x4f6ccce7
     *
     *     => 0x18160ddd ^ 0x2f745c59 ^ 0x4f6ccce7 == 0x780e9d63
     */
    bytes4 private constant _INTERFACE_ID_ERC721_ENUMERABLE = 0x780e9d63;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor (string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;

        // register the supported interfaces to conform to ERC721 via ERC165
        _registerInterface(_INTERFACE_ID_ERC721);
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);
        _registerInterface(_INTERFACE_ID_ERC721_ENUMERABLE);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");

        return _holderTokens[owner].length();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _tokenOwners.get(tokenId, "ERC721: owner query for nonexistent token");
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];

        // If there is no base URI, return the token URI.
        if (bytes(_baseURI).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(_baseURI, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(_baseURI, tokenId.toString()));
    }

    /**
    * @dev Returns the base URI set via {_setBaseURI}. This will be
    * automatically added as a prefix in {tokenURI} to each token's URI, or
    * to the token ID if no specific URI is set for that token ID.
    */
    function baseURI() public view returns (string memory) {
        return _baseURI;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        return _holderTokens[owner].at(index);
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
        return _tokenOwners.length();
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view override returns (uint256) {
        (uint256 tokenId, ) = _tokenOwners.at(index);
        return tokenId;
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _tokenOwners.contains(tokenId);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     d*
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory _data) internal virtual {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        // Clear metadata (if any)
        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }

        _holderTokens[owner].remove(tokenId);

        _tokenOwners.remove(tokenId);

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _tokenOwners.set(tokenId, to);

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev Internal function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     */
    function _setBaseURI(string memory baseURI_) internal virtual {
        _baseURI = baseURI_;
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private returns (bool)
    {
        if (!to.isContract()) {
            return true;
        }
        bytes memory returndata = to.functionCall(abi.encodeWithSelector(
            IERC721Receiver(to).onERC721Received.selector,
            _msgSender(),
            from,
            tokenId,
            _data
        ), "ERC721: transfer to non ERC721Receiver implementer");
        bytes4 retval = abi.decode(returndata, (bytes4));
        return (retval == _ERC721_RECEIVED);
    }

    function _approve(address to, uint256 tokenId) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual { }
}

// File: contracts/utils/ProxyFactory.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

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

// File: contracts/utils/Initializable.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

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

// File: contracts/utils/ContextUpgradeSafe.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


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

// File: contracts/utils/OwnableUpgradeSafe.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;



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
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }

  uint256[49] private __gap;
}

// File: contracts/interfaces/ILendingPoolAddressProvider.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface ILendingPoolAddressesProvider {
  function getLendingPool() external view returns (address);

  function setLendingPoolImpl(address _pool) external;

  function getLendingPoolCore() external view returns (address payable);

  function setLendingPoolCoreImpl(address _lendingPoolCore) external;

  function getLendingPoolConfigurator() external view returns (address);

  function setLendingPoolConfiguratorImpl(address _configurator) external;

  function getLendingPoolDataProvider() external view returns (address);

  function setLendingPoolDataProviderImpl(address _provider) external;

  function getLendingPoolParametersProvider() external view returns (address);

  function setLendingPoolParametersProviderImpl(address _parametersProvider)
    external;

  function getTokenDistributor() external view returns (address);

  function setTokenDistributor(address _tokenDistributor) external;

  function getFeeProvider() external view returns (address);

  function setFeeProviderImpl(address _feeProvider) external;

  function getLendingPoolLiquidationManager() external view returns (address);

  function setLendingPoolLiquidationManager(address _manager) external;

  function getLendingPoolManager() external view returns (address);

  function setLendingPoolManager(address _lendingPoolManager) external;

  function getPriceOracle() external view returns (address);

  function setPriceOracle(address _priceOracle) external;

  function getLendingRateOracle() external view returns (address);

  function setLendingRateOracle(address _lendingRateOracle) external;
}

// File: contracts/libraries/CoreLibrary.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

// import "../utils/math/SafeMath.sol";
// import "../utils/math/WadRayMath.sol";

/**
 * @title CoreLibrary library
 * @author Aave
 * @notice Defines the data structures of the reserves and the user data
 **/
library CoreLibrary {
  //   using SafeMath for uint256;
  //   using WadRayMath for uint256;

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
    /**
     * @dev refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
     **/
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
    /**
     * @dev address of the aToken representing the asset
     **/
    address aTokenAddress;
    /**
     * @dev address of the interest rate strategy contract
     **/
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

  //   /**
  //    * @dev returns the ongoing normalized income for the reserve.
  //    * a value of 1e27 means there is no income. As time passes, the income is accrued.
  //    * A value of 2*1e27 means that the income of the reserve is double the initial amount.
  //    * @param _reserve the reserve object
  //    * @return the normalized income. expressed in ray
  //    **/
  //   function getNormalizedIncome(CoreLibrary.ReserveData storage _reserve)
  //     internal
  //     view
  //     returns (uint256)
  //   {
  //     uint256 cumulated = calculateLinearInterest(
  //       _reserve
  //         .currentLiquidityRate,
  //       _reserve
  //         .lastUpdateTimestamp
  //     )
  //       .rayMul(_reserve.lastLiquidityCumulativeIndex);

  //     return cumulated;
  //   }

  //   /**
  //    * @dev Updates the liquidity cumulative index Ci and variable borrow cumulative index Bvc. Refer to the whitepaper for
  //    * a formal specification.
  //    * @param _self the reserve object
  //    **/
  //   function updateCumulativeIndexes(ReserveData storage _self) internal {
  //     uint256 totalBorrows = getTotalBorrows(_self);

  //     if (totalBorrows > 0) {
  //       //only cumulating if there is any income being produced
  //       uint256 cumulatedLiquidityInterest = calculateLinearInterest(
  //         _self.currentLiquidityRate,
  //         _self.lastUpdateTimestamp
  //       );

  //       _self.lastLiquidityCumulativeIndex = cumulatedLiquidityInterest.rayMul(
  //         _self.lastLiquidityCumulativeIndex
  //       );

  //       uint256 cumulatedVariableBorrowInterest = calculateCompoundedInterest(
  //         _self.currentVariableBorrowRate,
  //         _self.lastUpdateTimestamp
  //       );
  //       _self.lastVariableBorrowCumulativeIndex = cumulatedVariableBorrowInterest
  //         .rayMul(_self.lastVariableBorrowCumulativeIndex);
  //     }
  //   }

  //   /**
  //    * @dev accumulates a predefined amount of asset to the reserve as a fixed, one time income. Used for example to accumulate
  //    * the flashloan fee to the reserve, and spread it through the depositors.
  //    * @param _self the reserve object
  //    * @param _totalLiquidity the total liquidity available in the reserve
  //    * @param _amount the amount to accomulate
  //    **/
  //   function cumulateToLiquidityIndex(
  //     ReserveData storage _self,
  //     uint256 _totalLiquidity,
  //     uint256 _amount
  //   ) internal {
  //     uint256 amountToLiquidityRatio = _amount.wadToRay().rayDiv(
  //       _totalLiquidity.wadToRay()
  //     );

  //     uint256 cumulatedLiquidity = amountToLiquidityRatio.add(WadRayMath.ray());

  //     _self.lastLiquidityCumulativeIndex = cumulatedLiquidity.rayMul(
  //       _self.lastLiquidityCumulativeIndex
  //     );
  //   }

  //   /**
  //    * @dev initializes a reserve
  //    * @param _self the reserve object
  //    * @param _aTokenAddress the address of the overlying atoken contract
  //    * @param _decimals the number of decimals of the underlying asset
  //    * @param _interestRateStrategyAddress the address of the interest rate strategy contract
  //    **/
  //   function init(
  //     ReserveData storage _self,
  //     address _aTokenAddress,
  //     uint256 _decimals,
  //     address _interestRateStrategyAddress
  //   ) external {
  //     require(
  //       _self.aTokenAddress == address(0),
  //       "Reserve has already been initialized"
  //     );

  //     if (_self.lastLiquidityCumulativeIndex == 0) {
  //       //if the reserve has not been initialized yet
  //       _self.lastLiquidityCumulativeIndex = WadRayMath.ray();
  //     }

  //     if (_self.lastVariableBorrowCumulativeIndex == 0) {
  //       _self.lastVariableBorrowCumulativeIndex = WadRayMath.ray();
  //     }

  //     _self.aTokenAddress = _aTokenAddress;
  //     _self.decimals = _decimals;

  //     _self.interestRateStrategyAddress = _interestRateStrategyAddress;
  //     _self.isActive = true;
  //     _self.isFreezed = false;
  //   }

  //   /**
  //    * @dev enables borrowing on a reserve
  //    * @param _self the reserve object
  //    * @param _stableBorrowRateEnabled true if the stable borrow rate must be enabled by default, false otherwise
  //    **/
  //   function enableBorrowing(
  //     ReserveData storage _self,
  //     bool _stableBorrowRateEnabled
  //   ) external {
  //     require(_self.borrowingEnabled == false, "Reserve is already enabled");

  //     _self.borrowingEnabled = true;
  //     _self.isStableBorrowRateEnabled = _stableBorrowRateEnabled;
  //   }

  //   /**
  //    * @dev disables borrowing on a reserve
  //    * @param _self the reserve object
  //    **/
  //   function disableBorrowing(ReserveData storage _self) external {
  //     _self.borrowingEnabled = false;
  //   }

  //   /**
  //    * @dev enables a reserve to be used as collateral
  //    * @param _self the reserve object
  //    * @param _baseLTVasCollateral the loan to value of the asset when used as collateral
  //    * @param _liquidationThreshold the threshold at which loans using this asset as collateral will be considered undercollateralized
  //    * @param _liquidationBonus the bonus liquidators receive to liquidate this asset
  //    **/
  //   function enableAsCollateral(
  //     ReserveData storage _self,
  //     uint256 _baseLTVasCollateral,
  //     uint256 _liquidationThreshold,
  //     uint256 _liquidationBonus
  //   ) external {
  //     require(
  //       _self.usageAsCollateralEnabled == false,
  //       "Reserve is already enabled as collateral"
  //     );

  //     _self.usageAsCollateralEnabled = true;
  //     _self.baseLTVasCollateral = _baseLTVasCollateral;
  //     _self.liquidationThreshold = _liquidationThreshold;
  //     _self.liquidationBonus = _liquidationBonus;

  //     if (_self.lastLiquidityCumulativeIndex == 0)
  //       _self.lastLiquidityCumulativeIndex = WadRayMath.ray();
  //   }

  //   /**
  //    * @dev disables a reserve as collateral
  //    * @param _self the reserve object
  //    **/
  //   function disableAsCollateral(ReserveData storage _self) external {
  //     _self.usageAsCollateralEnabled = false;
  //   }

  //   /**
  //    * @dev calculates the compounded borrow balance of a user
  //    * @param _self the userReserve object
  //    * @param _reserve the reserve object
  //    * @return the user compounded borrow balance
  //    **/
  //   function getCompoundedBorrowBalance(
  //     CoreLibrary.UserReserveData storage _self,
  //     CoreLibrary.ReserveData storage _reserve
  //   ) internal view returns (uint256) {
  //     if (_self.principalBorrowBalance == 0) return 0;

  //     uint256 principalBorrowBalanceRay = _self.principalBorrowBalance.wadToRay();
  //     uint256 compoundedBalance = 0;
  //     uint256 cumulatedInterest = 0;

  //     if (_self.stableBorrowRate > 0) {
  //       cumulatedInterest = calculateCompoundedInterest(
  //         _self.stableBorrowRate,
  //         _self.lastUpdateTimestamp
  //       );
  //     } else {
  //       //variable interest
  //       cumulatedInterest = calculateCompoundedInterest(
  //         _reserve
  //           .currentVariableBorrowRate,
  //         _reserve
  //           .lastUpdateTimestamp
  //       )
  //         .rayMul(_reserve.lastVariableBorrowCumulativeIndex)
  //         .rayDiv(_self.lastVariableBorrowCumulativeIndex);
  //     }

  //     compoundedBalance = principalBorrowBalanceRay
  //       .rayMul(cumulatedInterest)
  //       .rayToWad();

  //     if (compoundedBalance == _self.principalBorrowBalance) {
  //       //solium-disable-next-line
  //       if (_self.lastUpdateTimestamp != block.timestamp) {
  //         //no interest cumulation because of the rounding - we add 1 wei
  //         //as symbolic cumulated interest to avoid interest free loans.

  //         return _self.principalBorrowBalance.add(1 wei);
  //       }
  //     }

  //     return compoundedBalance;
  //   }

  //   /**
  //    * @dev increases the total borrows at a stable rate on a specific reserve and updates the
  //    * average stable rate consequently
  //    * @param _reserve the reserve object
  //    * @param _amount the amount to add to the total borrows stable
  //    * @param _rate the rate at which the amount has been borrowed
  //    **/
  //   function increaseTotalBorrowsStableAndUpdateAverageRate(
  //     ReserveData storage _reserve,
  //     uint256 _amount,
  //     uint256 _rate
  //   ) internal {
  //     uint256 previousTotalBorrowStable = _reserve.totalBorrowsStable;
  //     //updating reserve borrows stable
  //     _reserve.totalBorrowsStable = _reserve.totalBorrowsStable.add(_amount);

  //     //update the average stable rate
  //     //weighted average of all the borrows
  //     uint256 weightedLastBorrow = _amount.wadToRay().rayMul(_rate);
  //     uint256 weightedPreviousTotalBorrows = previousTotalBorrowStable
  //       .wadToRay()
  //       .rayMul(_reserve.currentAverageStableBorrowRate);

  //     _reserve.currentAverageStableBorrowRate = weightedLastBorrow
  //       .add(weightedPreviousTotalBorrows)
  //       .rayDiv(_reserve.totalBorrowsStable.wadToRay());
  //   }

  //   /**
  //    * @dev decreases the total borrows at a stable rate on a specific reserve and updates the
  //    * average stable rate consequently
  //    * @param _reserve the reserve object
  //    * @param _amount the amount to substract to the total borrows stable
  //    * @param _rate the rate at which the amount has been repaid
  //    **/
  //   function decreaseTotalBorrowsStableAndUpdateAverageRate(
  //     ReserveData storage _reserve,
  //     uint256 _amount,
  //     uint256 _rate
  //   ) internal {
  //     require(
  //       _reserve.totalBorrowsStable >= _amount,
  //       "Invalid amount to decrease"
  //     );

  //     uint256 previousTotalBorrowStable = _reserve.totalBorrowsStable;

  //     //updating reserve borrows stable
  //     _reserve.totalBorrowsStable = _reserve.totalBorrowsStable.sub(_amount);

  //     if (_reserve.totalBorrowsStable == 0) {
  //       _reserve.currentAverageStableBorrowRate = 0; //no income if there are no stable rate borrows
  //       return;
  //     }

  //     //update the average stable rate
  //     //weighted average of all the borrows
  //     uint256 weightedLastBorrow = _amount.wadToRay().rayMul(_rate);
  //     uint256 weightedPreviousTotalBorrows = previousTotalBorrowStable
  //       .wadToRay()
  //       .rayMul(_reserve.currentAverageStableBorrowRate);

  //     require(
  //       weightedPreviousTotalBorrows >= weightedLastBorrow,
  //       "The amounts to subtract don't match"
  //     );

  //     _reserve.currentAverageStableBorrowRate = weightedPreviousTotalBorrows
  //       .sub(weightedLastBorrow)
  //       .rayDiv(_reserve.totalBorrowsStable.wadToRay());
  //   }

  //   /**
  //    * @dev increases the total borrows at a variable rate
  //    * @param _reserve the reserve object
  //    * @param _amount the amount to add to the total borrows variable
  //    **/
  //   function increaseTotalBorrowsVariable(
  //     ReserveData storage _reserve,
  //     uint256 _amount
  //   ) internal {
  //     _reserve.totalBorrowsVariable = _reserve.totalBorrowsVariable.add(_amount);
  //   }

  //   /**
  //    * @dev decreases the total borrows at a variable rate
  //    * @param _reserve the reserve object
  //    * @param _amount the amount to substract to the total borrows variable
  //    **/
  //   function decreaseTotalBorrowsVariable(
  //     ReserveData storage _reserve,
  //     uint256 _amount
  //   ) internal {
  //     require(
  //       _reserve.totalBorrowsVariable >= _amount,
  //       "The amount that is being subtracted from the variable total borrows is incorrect"
  //     );
  //     _reserve.totalBorrowsVariable = _reserve.totalBorrowsVariable.sub(_amount);
  //   }

  //   /**
  //    * @dev function to calculate the interest using a linear interest rate formula
  //    * @param _rate the interest rate, in ray
  //    * @param _lastUpdateTimestamp the timestamp of the last update of the interest
  //    * @return the interest rate linearly accumulated during the timeDelta, in ray
  //    **/

  //   function calculateLinearInterest(uint256 _rate, uint40 _lastUpdateTimestamp)
  //     internal
  //     view
  //     returns (uint256)
  //   {
  //     //solium-disable-next-line
  //     uint256 timeDifference = block.timestamp.sub(uint256(_lastUpdateTimestamp));

  //     uint256 timeDelta = timeDifference.wadToRay().rayDiv(
  //       SECONDS_PER_YEAR.wadToRay()
  //     );

  //     return _rate.rayMul(timeDelta).add(WadRayMath.ray());
  //   }

  //   /**
  //    * @dev function to calculate the interest using a compounded interest rate formula
  //    * @param _rate the interest rate, in ray
  //    * @param _lastUpdateTimestamp the timestamp of the last update of the interest
  //    * @return the interest rate compounded during the timeDelta, in ray
  //    **/
  //   function calculateCompoundedInterest(
  //     uint256 _rate,
  //     uint40 _lastUpdateTimestamp
  //   ) internal view returns (uint256) {
  //     //solium-disable-next-line
  //     uint256 timeDifference = block.timestamp.sub(uint256(_lastUpdateTimestamp));

  //     uint256 ratePerSecond = _rate.div(SECONDS_PER_YEAR);

  //     return ratePerSecond.add(WadRayMath.ray()).rayPow(timeDifference);
  //   }

  //   /**
  //    * @dev returns the total borrows on the reserve
  //    * @param _reserve the reserve object
  //    * @return the total borrows (stable + variable)
  //    **/
  //   function getTotalBorrows(CoreLibrary.ReserveData storage _reserve)
  //     internal
  //     view
  //     returns (uint256)
  //   {
  //     return _reserve.totalBorrowsStable.add(_reserve.totalBorrowsVariable);
  //   }
}

// File: contracts/interfaces/ILendingPoolCore.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;


interface ILendingPoolCore {
  function getReserveATokenAddress(address _reserve)
    external
    view
    returns (address);
}

// File: contracts/interfaces/ILendingPool.sol

pragma solidity ^0.6.0;

interface ILendingPool {
  function deposit(
    address _reserve,
    uint256 _amount,
    uint16 _referralCode
  ) external;
}

// File: contracts/interfaces/AToken.sol

pragma solidity ^0.6.0;

interface AToken {
  /**
   * @dev calculates the balance of the user, which is the
   * principal balance + interest generated by the principal balance +
   * interest generated by the redirected balance
   * @param _user the user for which the balance is being calculated
   * @return the total balance of the user
   **/
  function balanceOf(address _user) external view returns (uint256);

  function redeem(uint256 _amount) external;
}

// File: contracts/rentft.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;















contract InterestCalculatorProxy is Initializable, OwnableUpgradeSafe {
  using  SafeERC20 for ERC20;
  event Initialized(address indexed thisAddress);
 
  // proxy admin would be the owner to prevent in fraud cases where the borrower
  // doesn't return the nft back
  function initialize(address _owner) public initializer {
    OwnableUpgradeSafe.__Ownable_init();
    OwnableUpgradeSafe.transferOwnership(_owner);
    emit Initialized(address(this));
  }
  
  function deposit(address _reserve, address _lendingPool, address _lendingPoolCore) public {
    uint reserveBalance = ERC20(_reserve).balanceOf(address(this));
    ERC20(_reserve).approve(_lendingPoolCore, reserveBalance);
    ILendingPool(_lendingPool).deposit(_reserve, reserveBalance, 0);
  }
  
  // allow rentft to withdraw from aave
  function withdraw(address _aToken) public returns(uint256) {
      require(msg.sender == rentft, "Not Rentft");
      
      uint256 daiBalance = getBalance(_aToken);
      
      // withdraw dai from aDai
      AToken(_aToken).redeem(daiBalance);
      
      ERC20(_aToken).safeTransfer(rentft, daiBalance);
      
      return daiBalance;
  }

  function getBalance(address _reserve) public view returns (uint256) {
    // All calculations to be done in the parent contract
    return AToken(_reserve).balanceOf(address(this));
  }
}

contract Rentft is
  ProxyFactory,
  ChainlinkClient,
  ReentrancyGuard
{
  // using SafeMath for uint256;
  using SafeERC20 for ERC20;

  struct Asset {
    address owner;
    address borrower;
    uint256 duration;    // should be unix again to avoid decimal issues
    uint256 borrowedAt;  // borrowed time to be verifed by returning
    uint256 nftPrice;
    uint256 collateral;  // for security
  }

  // proxy details
  // owner => borrower => proxy
  mapping(address => mapping(address => address)) public proxyInfo;
  address public proxyBaseAddress;

  // nft address => token id => asset info struct
  mapping(address => mapping(uint256 => Asset)) public assets;

  uint256 private nftPrice;
  address private oracle;
  bytes32 private jobId;
  uint256 private chainlinkFee;
  // this fee is added on top of the collateral for each hold day of the NFT.
  // This is used to cancel out any potential swings in the price of the NFT
  // denoted in bps (basis points). 1% is 100 bps. 0.1% is 10 bps and
  // equivalently 0.01% is 1 bps. The mechanism for computing the rent will
  // change in the future, to be more efficient and meaningful
  uint256 public collateralDailyFee = 100;
  address public daiAddress = 0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD;
  address public aDaiAddress = 0x58AD4cB396411B691A9AAb6F74545b2C5217FE6a;

  ILendingPoolAddressesProvider public lendingPoolAddressProvider;
  ILendingPool public lendingPool;
  ILendingPoolCore public lendingPoolCore;
  
  address tempNftAddress;
  uint256 tempNftId;

  /**
   * Network: Kovan
   * Oracle: Chainlink - 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e
   * Job ID: Chainlink - 29fa9aa13bf1468788b7cc4a500a45b8
   * Link: 0xa36085F69e2889c224210F603D836748e7dC0088
   * Fee: 0.1 LINK
   */
  // provide aave address provider for the network you are working on
  // get all aave related addresses through addressesProvider state var
  // get all aToken reserve addresses through the core state var
  constructor(address _proxyBaseAddress) public {
    setPublicChainlinkToken();
    oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
    jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
    chainlinkFee = 0.1 * 10**18; // 0.1 LINK
    proxyBaseAddress = _proxyBaseAddress;
    // do we need this at the moment  ?
    lendingPoolAddressProvider =ILendingPoolAddressesProvider(0x506B0B2CF20FAA8f38a4E2B524EE43e1f4458Cc5);
    lendingPool = ILendingPool(lendingPoolAddressProvider.getLendingPool());
    lendingPoolCore = ILendingPoolCore(lendingPoolAddressProvider.getLendingPoolCore());
  }

  // function to list the nft on the platform
  // url will be the api endpoint to fetch nft price
  function addProduct(
    address nftAddress,
    uint256 nftId,
    uint256 duration,
    string calldata _url
  ) external {
    require(nftAddress != address(0), "Invalid NFT Address");
    
    tempNftAddress = nftAddress;
    tempNftId = nftId;
    fetchNFTPrice(_url);

    // need to verify whether the nftPrice will have the latest value
    assets[nftAddress][nftId] = Asset(
      msg.sender,
      address(0),
      duration,
      0,
      0, // price not yet fetched
      0
    );
    
    // transfer nft to this contract
    ERC721(nftAddress).transferFrom(msg.sender, address(this), nftId);
  }

   /**
   * @dev calculates the total collateral price of the NFT. Imagine virtual museums that rent out
   * the NFTs of the artists for some time. Therefore, there is a potential for reputation
   * here. If the borrower has consistently good renting track-record, they will get more
   * favourable quotes
   * @param _duration number of days that the user wishes to rent out the NFT for. 1 means 1 day
   * @return the total collateral + fee the borrower has to put up
   **/
  function calculateCollateral(
    address _nft,
    uint256 _tokenId,
    uint256 _duration
  ) public view returns (uint256) {
    // ! TODO: need to ensure that this nftPrice is relevant, and is not old
    // can we invoke chainlink price update here before computing the rentPrice?
    // collateral = _nft_price * ((collateralDailyFee) ** _duration)
    // collateral (with our service fee) = rentPrice * ourFee
    // ! this must always be populated, otherwise an error will be thrown
    // * interest compounding
    uint256 basePrice = assets[_nft][_tokenId].nftPrice;
    uint256 collateral = ((basePrice).add(basePrice.mul(collateralDailyFee).div(10000))).mul(_duration);
    // this though returns price in ETH
    // we need an ability to convert it into whatever
    return collateral;
  }

  // to rent the contract:
  // 1. the borrower must have paid the indicated collateral
  // validations:
  // 1. the borrower can't be borrowing the borrowed nft
  // (this check also ensures that the borrower is not the
  // owner & that the borrower isn't borrowing what he already borrowed)
  function rent(
    address _borrower,
    uint256 _duration,
    address _nft,
    uint256 _tokenId,
    string calldata _url
  ) external nonReentrant {
    require(assets[_nft][_tokenId].duration > 0, "could not find an NFT");
    
    address owner = assets[_nft][_tokenId].owner;
    
    tempNftAddress = _nft;
    tempNftId = _tokenId;
    fetchNFTPrice(_url);

    // ! we only need DAI here to begin with
    // require(msg.value > 0, "you need to pay the collateral");
    // !! need to fix this calculation as the nft price value is older one here
    uint256 collateral = calculateCollateral(_nft, _tokenId, _duration);
    
    // create proxy
    createProxy(owner, _borrower);
    
    // ! will fail if the msg.sender hasn't approved us as the spender of their ERC20 tokens
    transferToProxy(
      daiAddress,
      msg.sender,
      collateral,
      proxyInfo[owner][_borrower]
    );
    // deposit to aave
    InterestCalculatorProxy(proxyInfo[owner][_borrower]).deposit(daiAddress, address(lendingPool), address(lendingPoolCore));
    
    // set asset vars
    assets[_nft][_tokenId].borrower = _borrower;
    assets[_nft][_tokenId].borrowedAt = now;
    assets[_nft][_tokenId].collateral = collateral;
    
    // transfer nft to borrower
    ERC721(_nft).transferFrom(address(this), _borrower, _tokenId);
  }
  
  // called by borrower
  // !! base url must be stored in contract, borrower might provide fake one here
  // user won't provide the usrl since it has dynamic parameters we wouuld be constructing it on the js end
  // NOTE -> there won't be a case where the borrower will recieve 0 as the amount it has to be collateral deposited - current price and interest calculations on top of that
  function returnNFT(
    address _nft,
    uint256 _tokenId,
    string calldata _url
  ) external {
      require(assets[_nft][_tokenId].duration > 0, "could not find an NFT");
      require(assets[_nft][_tokenId].borrower == msg.sender, "Not Borrower");
      // check (now-borrowedAt) <= duration in secs
      uint256 durationInDays = now.sub(assets[_nft][_tokenId].borrowedAt).div(86400);
      require(durationInDays <= assets[_nft][_tokenId].duration, "Duration exceeded");
      
      address owner = assets[_nft][_tokenId].owner;
      uint256 collateralAvailable = assets[_nft][_tokenId].collateral;
      
      // redeem aDai to Dai in Proxy
      uint256 daiReceived = InterestCalculatorProxy(proxyInfo[owner][msg.sender]).withdraw(aDaiAddress);
      // calculate aave interest
      uint256 interest = daiReceived.sub(collateralAvailable);
      // split interest to both users
      uint256 ownerPayout = interest.div(2);
      uint256 borrowerPayout = interest.div(2);
      
      // get current nft price
      fetchNFTPrice(_url);
      require(nftPrice != 0, "Invalid NFT Price");
      assets[_nft][_tokenId].nftPrice = nftPrice;
      // calculate latest collateral
      // note => the price here is the latest price removed the current price var due to stack deep error
      uint256 latestCollateralAmount = calculateCollateral(_nft, _tokenId, durationInDays);
      // rent calculation based on latest price
      uint256 calculatedRent = nftPrice.mul(collateralDailyFee).div(10000).mul(durationInDays);
      if (latestCollateralAmount > collateralAvailable) {
          uint256 extra = latestCollateralAmount.sub(collateralAvailable);
          borrowerPayout = (borrowerPayout.add((collateralAvailable.sub(nftPrice)).sub(calculatedRent))).sub(extra);
          ownerPayout = ownerPayout.add(extra);
      } else {
          uint256 extra = collateralAvailable.sub(latestCollateralAmount);
          borrowerPayout = (borrowerPayout.add((collateralAvailable.sub(nftPrice)).sub(calculatedRent))).add(extra);
          ownerPayout = ownerPayout.sub(extra);
      }

      // send nft to owner
      ERC721(_nft).transferFrom(msg.sender, owner, _tokenId);
      
      //send payout amounts to both
      ERC20(daiAddress).safeTransfer(owner, ownerPayout);
      ERC20(daiAddress).safeTransfer(msg.sender, borrowerPayout);
      

      // set assets params to null
      assets[_nft][_tokenId].duration = 0;
  }
  
  /**
   * @dev transfers an amount from a user to the destination proxy address where it
   * subsequently gets deposited into Aave
   * @param _reserve the address of the reserve where the amount is being transferred
   * @param _user the address of the user from where the transfer is happening
   * @param _amount the amount being transferred
   **/
  function transferToProxy(
    address _reserve,
    address payable _user,
    uint256 _amount,
    address _proxy
  ) private {
      require(
        msg.value == 0,
        "User is sending ETH along with the ERC20 transfer."
      );
      // ! our contract should be approved to move his ERC20 funds
      ERC20(_reserve).safeTransferFrom(_user, _proxy, _amount);
  }

  // create the proxy contract for managing interest when a borrower rents it out
  function createProxy(address _owner, address _borrower) internal {
    bytes memory _payload = abi.encodeWithSignature(
      "initialize(address)",
      _owner
    );
    // Deploy proxy
    // for testing the address of the proxy contract which will
    // be used to redirect interest will come here
    address _intermediate = deployMinimal(proxyBaseAddress, _payload);
    // user address is just recorded for tracking the proxy for the particular pair
    // TODO: need to test this for same owner but different user
    proxyInfo[_owner][_borrower] = _intermediate;
  }

  // check whether the proxy contract exists or not for a owner-borrower pair
  function getProxy(address _owner, address _borrower)
    internal
    view
    returns (address)
  {
    return proxyInfo[_owner][_borrower];
  }
  
  function fetchNFTPrice(string memory _url) internal {
      Chainlink.Request memory request = buildChainlinkRequest(
      jobId,
      address(this),
      this.fulfill.selector
    );

    // Set the URL to perform the GET request on
    request.add("get", _url);

    // Set the path to find the desired data in the API response, where the response format is:
    request.add("path", "last_sale.payment_token.usd_price");

    // Multiply the result by 10^18 to remove decimals
    request.addInt("times", 1000000000000000000);

    // Sends the request
    sendChainlinkRequestTo(oracle, request, chainlinkFee);
  }

  /**
   * Receive the price response in the form of uint256
   */
  function fulfill(bytes32 _requestId, uint256 _price)
    public
    recordChainlinkFulfillment(_requestId)
  {
    assets[tempNftAddress][tempNftId].nftPrice = _price;
  }
}
