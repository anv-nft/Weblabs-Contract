pragma solidity ^0.8.7;

import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/KIP/token/KIP7/IKIP7.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/KIP/token/KIP17/extensions/IKIP17MetadataMintable.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/KIP/token/KIP17/IKIP17.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/utils/Strings.sol";
import "./data.sol";

contract Breeder is Ownable{

    enum LarvaType{Red, Yellow, Brown, Black, Pink, Rainbow, Violet, Cocoa, Mayfly}
    enum legendaryType{Normal, Legendary}
    struct info{
        string baseURI;
        address child;
        mapping (uint256 => uint256) coolTime; 
        uint256 baseCoolTime;
        address parentDataContract;
        address childDataContract;        
        address tokenAddress;
    }
    mapping(address => info) public parent;
    
    // 리빌 세팅 여부, 리빌 여부 알림
    event Setted (address beforeAddress, address afterAddress);
    event Breeded (address tokenOwner, uint256 tokenId, legendaryType breedingType);

    modifier sameTypeChecker(address _parent, uint256 parent1TokenId, uint256 parent2TokenId){
        require(Parent(parent[_parent].parentDataContract).getValue(parent1TokenId) != Parent(parent[_parent].parentDataContract).getValue(parent2TokenId), "Can not breed with those same types");
        _;
    }

    modifier tokenOwnerChecker(address _parent, uint256 parent1, uint256 parent2){
        require(IKIP17(_parent).ownerOf(parent1) == msg.sender && IKIP17(_parent).ownerOf(parent2) == msg.sender, "This token is not yours");
        _;
    }
    function setDataContract(address _parent, address _parentDataContract, address _childDataContract) public onlyOwner{
        info storage parentInfo = parent[_parent];

        parentInfo.parentDataContract = _parentDataContract;
        parentInfo.childDataContract = _childDataContract;
    }

    function settingAll(address _parent, address _parentDataContract, address _childDataContract, address _child, address _tokenAddress, string memory _baseURI) public payable onlyOwner{
        setTargetAddress(_parent, _child);
        setBaseURI(_parent, _baseURI);
        setDataContract(_parent, _parentDataContract, _childDataContract);
        setTokenAddress(_parent, _tokenAddress);

        emit Setted(_parent, _child);
    }
    function setTargetAddress(address _parent, address child) public onlyOwner{
        require(_parent != address(0));
        require(child != address(0));
        require(_parent != child);
        parent[_parent].child = child;   
    }

    function setBaseURI(address _parent, string memory _baseURI) public onlyOwner {
        parent[_parent].baseURI = _baseURI; 
    }

    function setTokenAddress(address _parent,address tokenAddress) public onlyOwner {
        parent[_parent].tokenAddress = tokenAddress; 
    }

    function setBaseCoolTime(address _parent, uint256 _cooltime) public onlyOwner{
        parent[_parent].baseCoolTime = _cooltime;
    }
    
    function legendaryChacker(address _parent, uint256 parent1TokenId, uint256 parent2TokenId, uint256 _specialCount) private view returns (legendaryType) {
        
        info storage parentInfo = parent[_parent];
        address parentDataContract = parentInfo.parentDataContract;
        LarvaType token1LarvaType = LarvaType(Parent(parentDataContract).getValue(parent1TokenId));
        LarvaType token2LarvaType = LarvaType(Parent(parentDataContract).getValue(parent2TokenId));

        if (
            (_specialCount < 200) &&
            (token1LarvaType == LarvaType.Brown || token1LarvaType == LarvaType.Pink) &&
            (token2LarvaType == LarvaType.Brown || token2LarvaType == LarvaType.Pink) &&
            (parentInfo.coolTime[parent1TokenId] <= block.number && parentInfo.coolTime[parent2TokenId] <= block.number)) {
                return legendaryType.Legendary;
        } else {
            return legendaryType.Normal;
        }
    }

    function breeding(address _parent, uint256 parent1TokenId, uint256 parent2TokenId) 
    public
    payable
    sameTypeChecker(_parent, parent1TokenId, parent2TokenId) 
    tokenOwnerChecker(_parent, parent1TokenId, parent2TokenId)
    returns (address, uint256, legendaryType) {
        info storage parentInfo = parent[_parent];
        require(IKIP7(parentInfo.tokenAddress).allowance(msg.sender, address(this)) >= 2000*10**18);
        require(baby(parentInfo.childDataContract).getTotalAmount() < 2000, "All Token was breeded");

        legendaryType breedingType;
        breedingType = legendaryChacker(_parent, parent1TokenId, parent2TokenId, baby(parentInfo.childDataContract).getAmount(1));
        if (breedingType == legendaryType.Legendary){
            parentInfo.coolTime[parent1TokenId] = block.number + parentInfo.baseCoolTime;
            parentInfo.coolTime[parent2TokenId] = block.number + parentInfo.baseCoolTime;
        }

        uint256 tokenId = baby(parentInfo.childDataContract).Breeding(uint8(breedingType));
        IKIP7(parentInfo.tokenAddress).transferFrom(msg.sender, address(this), 2000 * 10 ** 18);
        IKIP17MetadataMintable(parentInfo.child).mintWithTokenURI(msg.sender, tokenId, string(abi.encodePacked(parentInfo.baseURI, Strings.toString(tokenId), ".json")));
        emit Breeded(msg.sender, tokenId, breedingType);
        return (msg.sender, tokenId, breedingType);
    }

    function getCoolTime(address _parent, uint256 tokenId) public view returns(uint256) {
        if (parent[_parent].coolTime[tokenId] >= block.number) {
            return (parent[_parent].coolTime[tokenId] - block.number);
        }
    }
}

