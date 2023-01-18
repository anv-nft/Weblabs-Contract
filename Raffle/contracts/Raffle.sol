// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./ERC721_ANVPausable.sol";



// return
contract Raffle is Ownable{
    enum status{ready, ongoing, completed, canceled}

    // FT => RafflePool
    mapping(address => RafflePool) Pool;


    struct RafflePool{
        Raffle[] round;
        mapping(address => bool) admin;
        uint currentRound;
        uint nftCount;
        address nftAddress;
    }

    struct Raffle{
        uint startTime;
        uint deadline;
        status _status;
        item[] items;
        address[] availableNFTs;

        mapping(address => uint) ticket; // NFT <-> 래플 참여 한 NFT 토큰 아이디 페어링

    }

    struct item{
        uint id;
        uint price;
        address[] entries;
        mapping(address => mapping(uint => bool)) usedToken;
        mapping(address => uint256) count;
        address winner;
    }    

    /**
     * @dev create a pool for a FT and admin was setted using setAdmin function
     * @param _FT the FT address
     */

    function createPool(address _FT, address raffleNFT) public onlyOwner{
        Pool[_FT].admin[msg.sender] = true;
        Pool[_FT].nftAddress = raffleNFT;
        Pool[_FT].currentRound = 0;
        Pool[_FT].nftCount = 0;

    }


    function getPool(address _FT) public view returns(bool, address, uint, uint){
        return (Pool[_FT].admin[msg.sender], Pool[_FT].nftAddress, Pool[_FT].currentRound, Pool[_FT].nftCount);
    }

    function destroyPool(address _FT) public onlyOwner{
        delete Pool[_FT];
    }


    modifier onlyAdmin(address _FT){
        require(Pool[_FT].admin[msg.sender], "You are not admin");
        _;
    }

    /**
     * @dev set admin for a pool
     * @param _FT the FT address
     * @param _admin the admin address
     * @param _status the status of admin
     */
    function setAdmin(address _FT, address _admin, bool _status) public onlyAdmin(_FT){
        Pool[_FT].admin[_admin] = _status;
        emit settedAdmin(_FT, _admin, _status);
    }

    event settedAdmin(address _FT, address _admin, bool _status);

    /**
     * @dev make a raffle
     * @param _FT the FT address
     * @param _NFT the NFT address
     * @param stratTime the start time of raffle
     * @param endTime the end time of raffle
     */
    function createRaffle(address _FT, address _NFT, uint stratTime, uint endTime) public onlyAdmin(_FT){
        Pool[_FT].round.push();
        Raffle storage _raffle = Pool[_FT].round[Pool[_FT].currentRound];

        _raffle.startTime = stratTime;
        _raffle.deadline = endTime;
        _raffle._status = status.ready;
        _raffle.availableNFTs.push(_NFT);

        Pool[_FT].currentRound++;
        emit raffleCreated(_FT, _NFT, 1, stratTime, endTime);
    }

    event raffleCreated(address _FT, address _NFT, uint round, uint stratTime, uint endTime);
    /** 
     * @dev add a available NFT to a raffle only admin
        * @param _FT the FT address
        * @param _NFT the NFT address
        * @param round the round of raffle
        */
    function addAvailableNFT(address _FT, address _NFT, uint round) public onlyAdmin(_FT){
        Raffle storage _raffle = Pool[_FT].round[round];

        require(_raffle._status == status.ready, "Raffle is not available");
        _raffle.availableNFTs.push(_NFT);

        emit addedAvailableNFT(_FT, _NFT, round);
    }

    event addedAvailableNFT(address _FT, address _NFT, uint round);

    /**
     * @dev add a item to a raffle only admin
     * @param _FT the FT address
     * @param round the round of raffle
     * @param _price the price of NFT
     */

    function addItem(address _FT, uint round, uint _price, string memory tokenURI) public onlyAdmin(_FT){

        RafflePool storage _pool = Pool[_FT];
        Raffle storage _raffle = Pool[_FT].round[round];

        require(_raffle._status == status.ready, "StatusError: Raffle is not available");
        
        ANVRaffleNFT(_pool.nftAddress).mintWithTokenURI(address(this), _pool.nftCount, tokenURI);
        //push the nftCount of _pool 
        uint256 len = _raffle.items.length;
        _raffle.items.push();
        _raffle.items[len].id = _pool.nftCount;
        _raffle.items[len].price = _price;

        emit addedItem(_FT, _pool.nftAddress, round,  _pool.nftCount, _price);
    }
    
    event addedItem(address _FT, address _NFT, uint round, uint _NFTId, uint _price);

    /**
     * @dev remove a item from a raffle only admin
     * @param _FT the FT address
     * @param _NFT the NFT address
     * @param round the round of raffle
     * @param _NFTId the NFT id
     */

    function removeItem(address _FT, address _NFT, uint round, uint _NFTId) public onlyAdmin(_FT) returns (bool){
        Raffle storage _raffle = Pool[_FT].round[round];
        require(_raffle._status == status.ready, "Raffle is not available");

        ANVRaffleNFT(Pool[_FT].nftAddress).burn(_NFTId);
        delete _raffle.items[_NFTId];

        emit removedItem(_FT, _NFT, round, _NFTId);

        return true;
    }

    event removedItem(address _FT, address _NFT, uint round, uint _NFTId);
  
    /**
     * @dev join to raffle
    * @param _FT the FT address
    * @param round the round of raffle
    * @param selectedItem the selected item
    * @param NFTAddress the NFT address
    * @param userNFT the NFT id
    */

    function joinRaffle(address _FT, uint round, uint selectedItem,address NFTAddress,uint userNFT) public {
        Raffle storage _raffle = Pool[_FT].round[round];
        require(_raffle._status == status.ongoing, "Raffle is not available");
        require(IERC20(_FT).balanceOf(msg.sender) >= _raffle.items[selectedItem].price, "You don't have enough FT");

        for (uint i = 0; i < _raffle.availableNFTs.length; i++){
            if (_raffle.availableNFTs[i] == NFTAddress){
                    require(IERC721(_raffle.availableNFTs[i]).ownerOf(userNFT) == msg.sender, "You don't have this NFT");
                break;
            }
        }
        require(_raffle.items[selectedItem].usedToken[NFTAddress][userNFT] == false, "This NFT is used");
                
        IERC20(_FT).transferFrom(
            msg.sender, 
            address(this), 
            _raffle.items[selectedItem].price);

        

        _raffle.items[selectedItem].entries.push(msg.sender);
        _raffle.items[selectedItem].usedToken[NFTAddress][userNFT] = true;
        _raffle.items[selectedItem].count[msg.sender]++;
        emit joinedRaffle(msg.sender, _FT, round, selectedItem, NFTAddress, userNFT);
    }

    event joinedRaffle(address joiner, address _FT, uint round, uint selectedItem, address NFTAddress, uint userNFT);

    /**
     * @dev end a raffle
     * @param _FT the FT address
     * @param round the round of raffle
     */

    function endRaffle(address _FT, uint round) public onlyAdmin(_FT){
        Raffle storage _raffle = Pool[_FT].round[round];
        require(_raffle._status == status.ongoing, "StatusError : Raffle is not available");
        require(block.number > _raffle.deadline, "TimeError : Raffle is not completed");
        _raffle._status = status.completed;

        emit completedRaffle(_FT, round);
    }

    event completedRaffle(address _FT, uint round);

    function cancelRaffle(address _FT, uint round) public onlyAdmin(_FT){
        Raffle storage _raffle = Pool[_FT].round[round];
        require(_raffle._status == status.ready, "StatusError : Raffle is not available");
        require(block.number < _raffle.deadline, "TimeError : Raffle is completed");
        _raffle._status = status.canceled;

        emit canceledRaffle(_FT, round);
    }

    event canceledRaffle(address _FT, uint round);

    function startRaffle(address _FT, uint round) public onlyAdmin(_FT){
        Raffle storage _raffle = Pool[_FT].round[round];
        require(_raffle._status == status.ready, "StatusError : Raffle is not available");
        require(block.number > _raffle.startTime, "TimeError : Raffle is completed");
        _raffle._status = status.ongoing;

        emit canceledRaffle(_FT, round);
    }

    event StartedRaffle(address _FT, uint round);

    /**
     * @dev lucky draw
     * @param _FT the FT address

     * @param round the round of raffle
     * @param itemNumber the item number
     */

    function luckyDraw(address _FT, uint round, uint itemNumber) public view returns(uint){
        Raffle storage _raffle = Pool[_FT].round[round];
        return uint(keccak256(abi.encodePacked(
            block.difficulty, 
            block.timestamp,
            _raffle.items[itemNumber].entries.length
            ))) % _raffle.items[itemNumber].entries.length;
    }

    function draw(address _FT, uint round, uint itemNumber) public onlyAdmin(_FT) returns(
        uint256 _luckyDraw,
        address _winner
    ){
        Raffle storage _raffle = Pool[_FT].round[round];

        require(_raffle._status == status.completed, "Raffle is not completed");
        require(_raffle.items[itemNumber].price > 0, "NFT is not available");

        uint drawedNumber = luckyDraw(_FT, round, itemNumber);

        address winner = _raffle.items[itemNumber].entries[drawedNumber];

        ANVRaffleNFT(Pool[_FT].nftAddress).transferFrom(
            address(this), 
            winner, 
            _raffle.items[itemNumber].id);

        _raffle.items[itemNumber].winner = winner;
        // _raffle.items[itemNumber].count[winner]--;

        emit luckyDrawed(_FT, round, itemNumber, winner);
        return (drawedNumber, winner);
    }

    event luckyDrawed(address _FT, uint round, uint itemNumber, address winner);

    // function discard(address _NFT, uint256 tokenId) public {
    //     IANV(_NFT).pause(tokenId);
    // }


}
