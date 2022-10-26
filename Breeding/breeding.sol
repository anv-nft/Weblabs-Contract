pragma solidity ^0.8.7;

import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/KIP/token/KIP7/IKIP7.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/KIP/token/KIP17/extensions/IKIP17MetadataMintable.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/KIP/token/KIP17/IKIP17.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/klaytn/klaytn-contracts/blob/master/contracts/utils/Strings.sol";
import "./data.sol";

contract Breeder is Ownable{

    enum LarvaType{Red, Yellow, Brown, Black, Pink, Rainbow, Violet, Cocoa, Mayfly}
    enum legendaryType{Common, Legendary}
    struct info{
        string baseURI;
        address child;
        mapping (uint256 => uint256) coolTime; 
        uint256 baseCoolTime;
        address parentDataContract;
        address childDataContract;        
        address tokenAddress;
        uint256 breedingFee;
    }
    mapping(address => info) public parent;
    
    // 리빌 세팅 여부, 리빌 여부 알림
    event Setted (address beforeAddress, address afterAddress);
    event Breeded (address tokenOwner, uint256 tokenId, baby.legendaryType breedingType);

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
    
    function setBreedingFee(address _parent, uint256 _breedingFee) public onlyOwner{
        if (_breedingFee <= 10**18) {
            parent[_parent].breedingFee = _breedingFee * 10 ** 18;
        } else{
            parent[_parent].breedingFee = _breedingFee;

        }
    }

    function reddem(address _parent) public payable onlyOwner{
        IKIP7(parent[_parent].tokenAddress).transfer(msg.sender, IKIP7(parent[_parent].tokenAddress).balanceOf(address(this)));
    }

    function legendaryChacker(address _parent, uint256 parent1TokenId, uint256 parent2TokenId) private view returns (baby.legendaryType) {
        
        info storage parentInfo = parent[_parent];
        address parentDataContract = parentInfo.parentDataContract;
        LarvaType token1LarvaType = LarvaType(Parent(parentDataContract).getValue(parent1TokenId));
        LarvaType token2LarvaType = LarvaType(Parent(parentDataContract).getValue(parent2TokenId));

        if ((baby(parentInfo.childDataContract).getAmount(baby.legendaryType.Legendary) < 200) &&
            (token1LarvaType == LarvaType.Brown || token1LarvaType == LarvaType.Pink) &&
            (token2LarvaType == LarvaType.Brown || token2LarvaType == LarvaType.Pink)) {
                require((parentInfo.coolTime[parent1TokenId] <= block.number && parentInfo.coolTime[parent2TokenId] <= block.number), "Cooltime Error!");
                return baby.legendaryType.Legendary;
        } else {
            return baby.legendaryType.Common;
        }
    }

    function breeding(address _parent, uint256 parent1TokenId, uint256 parent2TokenId) 
    public
    payable
    sameTypeChecker(_parent, parent1TokenId, parent2TokenId) 
    tokenOwnerChecker(_parent, parent1TokenId, parent2TokenId)
    returns (address, uint256, baby.legendaryType) {
        info storage parentInfo = parent[_parent];
        require(IKIP7(parentInfo.tokenAddress).allowance(msg.sender, address(this)) >= parentInfo.breedingFee);
        require(baby(parentInfo.childDataContract).getTotalAmount() < 2000, "All Token was breeded");

        baby.legendaryType breedingType;
        breedingType = legendaryChacker(_parent, parent1TokenId, parent2TokenId);
        if (breedingType == baby.legendaryType.Legendary){
            parentInfo.coolTime[parent1TokenId] = block.number + parentInfo.baseCoolTime;
            parentInfo.coolTime[parent2TokenId] = block.number + parentInfo.baseCoolTime;
        }

        uint256 tokenId = baby(parentInfo.childDataContract).Breeding(breedingType);
        IKIP7(parentInfo.tokenAddress).transferFrom(msg.sender, address(this), parentInfo.breedingFee);
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

