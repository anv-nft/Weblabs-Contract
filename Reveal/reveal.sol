pragma solidity ^0.8.7;

import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/KIP/token/KIP17/extensions/IKIP17Burnable.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/KIP/token/KIP17/extensions/IKIP17MetadataMintable.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/KIP/token/KIP17/IKIP17.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/utils/Strings.sol";


contract reveal is Ownable{
    mapping (address => string) baseURI;
    mapping (address => address) targetToken; // 등록되지 않은 경우 Null address (address(0)) 반환

    // 리빌 세팅 여부, 리빌 여부 알림
    event Setted (address beforeAddress, address afterAddress);
    event Revealed (address tokenOwner, address beforeAddress, address afterAddress, uint256 tokenId);

    function setRevealAddress(address beforeAddress, address afterAddress) public onlyOwner{
        require(afterAddress != address(0));
        require(beforeAddress != address(0));
        targetToken[beforeAddress] = afterAddress;
        
        emit Setted(beforeAddress, targetToken[beforeAddress]);
    }

    function setBaseURI(address beforeAddress, string memory _baseURI) public onlyOwner {
        baseURI[beforeAddress] = _baseURI; 
    }
    
    function revealToken(address beforeAddress, uint256 tokenId) public {
        require(msg.sender == IKIP17(beforeAddress).ownerOf(tokenId)); // 토큰 소유자만 실행
        require(targetToken[beforeAddress] != address(0), "Not Registered Address");
        IKIP17Burnable(beforeAddress).burn(tokenId); // 이전 토큰 소각
        IKIP17MetadataMintable(targetToken[beforeAddress]).mintWithTokenURI(msg.sender, tokenId, string(abi.encodePacked(baseURI[targetToken[beforeAddress]], Strings.toString(tokenId), ".json")));
        
        emit Revealed(msg.sender, beforeAddress, targetToken[beforeAddress], tokenId);
    }

    // 셋팅 된 정보 조회
    function checkSetting(address beforeAddress) public view returns(address, string memory) {
        return (targetToken[beforeAddress], baseURI[beforeAddress]);
    }
}