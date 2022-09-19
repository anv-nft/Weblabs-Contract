pragma solidity 0.5.6;
import "https://github.com/klaytn/klaytn-contracts-old/blob/e9a9b03be3543749db1d759c17462d9c8ace4c3b/contracts/token/KIP17/KIP17Token.sol";
import "https://github.com/klaytn/klaytn-contracts-old/blob/e9a9b03be3543749db1d759c17462d9c8ace4c3b/contracts/token/KIP17/IKIP17.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract tokenPausable is PauserRole, KIP17Metadata{
        /**
     * @dev Emitted when the pause is triggered by a pauser (`account`).
     */
    event Paused(address account, uint256 tokenId);

    /**
     * @dev Emitted when the pause is lifted by a pauser (`account`).
     */
    event Unpaused(address account, uint256 tokenId);

    mapping (uint256 => bool) _paused;
    mapping (uint256 => string) URIBeforePaused;

    /**
     * @dev Initializes the contract in unpaused state. Assigns the Pauser role
     * to the deployer.
     */
    constructor() internal {
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused(uint256 tokenId) public view returns (bool) {
        return _paused[tokenId];
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused(uint256 tokenId) {
        require(!_paused[tokenId], "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     */
    modifier whenPaused(uint256 tokenId) {
        require(_paused[tokenId], "Pausable: not paused");
        _;
    }

    /**
     * @dev Called by a pauser to pause, triggers stopped state.
     */
    function pause(uint256 tokenId) public onlyPauser whenNotPaused(tokenId) {

        // require(tokenURIs[tokenId] == "Paused");
        _paused[tokenId] = true;
        emit Paused(msg.sender, tokenId);
    }

    /**
     * @dev Called by a pauser to unpause, returns to normal state.
     */
    function unpause(uint256 tokenId) public onlyPauser whenPaused(tokenId) {
        _paused[tokenId] = false;
        emit Unpaused(msg.sender, tokenId);
    }
}


contract KIP17TokenPasuable is KIP13, KIP17, tokenPausable {
    /*
     *     bytes4(keccak256('paused()')) == 0x5c975abb
     *     bytes4(keccak256('pause()')) == 0x8456cb59
     *     bytes4(keccak256('unpause()')) == 0x3f4ba83a
     *     bytes4(keccak256('isPauser(address)')) == 0x46fbf68e
     *     bytes4(keccak256('addPauser(address)')) == 0x82dc1ec4
     *     bytes4(keccak256('renouncePauser()')) == 0x6ef8d66d
     *
     *     => 0x5c975abb ^ 0x8456cb59 ^ 0x3f4ba83a ^ 0x46fbf68e ^ 0x82dc1ec4 ^ 0x6ef8d66d == 0x4d5507ff
     */

    /**
     * @dev Constructor function.
     */
    constructor() public {
    }

    function approve(address to, uint256 tokenId) public whenNotPaused(tokenId) {
        super.approve(to, tokenId);
    }


    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public whenNotPaused(tokenId) {
        super.transferFrom(from, to, tokenId);
    }
}


contract MyKIP17Token is KIP17Full, KIP17Mintable, KIP17MetadataMintable, KIP17Burnable, KIP17TokenPasuable {
    constructor (string memory name, string memory symbol) public KIP17Full(name, symbol) {
    }
}
