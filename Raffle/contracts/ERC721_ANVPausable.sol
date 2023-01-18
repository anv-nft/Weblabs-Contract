// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
// import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "../anv_modules/ANV721Pausable.sol";


contract ANVRaffleNFT is ERC721URIStorage, Ownable, ERC721Burnable, ANV721Pausable {
    string baseURI;
    string URIWhenPaused;
    mapping(uint256 => bool) discarded;
    string URIWhenDiscarded;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    // inherited from ANV721Pausable
    function pauseAll() public onlyOwner {
        super._pauseAll();
    }

    function unpauseAll() public onlyOwner {
        super._unpauseAll();
    }

    function pause(uint256 tokenId) public onlyOwner {
        super._pause(tokenId);
    }

    function unpause(uint256 tokenId) public onlyOwner {
        super._unpause(tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        return !discarded[tokenId] ? super.tokenURI(tokenId) : URIWhenDiscarded;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function mintWithTokenURI(address to, uint256 tokenId, string memory _tokenURI) public {
        _mint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    function setWhenPausedURI(string memory _URIWhenPaused) public onlyOwner {
        URIWhenPaused = _URIWhenPaused;
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal virtual override(ERC721, ANV721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
}