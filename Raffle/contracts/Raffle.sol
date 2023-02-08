// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721_ANVPausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract RaffleShop is Ownable {
    enum Status {
        ready,
        ongoing,
        completed,
        canceled
    }

    // fungibleToken => Shop
    mapping(address => Shop) Raffle;

    struct Shop {
        Box[] boxes;
        mapping(address => bool) admin;
        uint256 currentRound;
        address productAddr;
        bool destroyed;
    }

    struct Box {
        uint256 startTime;
        uint256 deadline;
        Status status;
        product[] products;
        mapping(address => bool) availableNFT;
        mapping(address => mapping(uint256 => bool)) usedTicket;
    }

    struct product {
        uint256 tokenId;
        uint256 price;
        address[] entry;
        address winner;
        mapping(address => uint256) countForRefunding;
    }

    /**
     * @dev create a pool for a fungibleToken and admin was setted using setAdmin function
     * @param fungibleToken the fungibleToken address
     */

    function createPool(address fungibleToken, address productAddr)
        public
        onlyOwner
    {
        require(
            Raffle[fungibleToken].admin[msg.sender] == false,
            "Error : Already created Raffle"
        );
        Raffle[fungibleToken].admin[msg.sender] = true;
        Raffle[fungibleToken].productAddr = productAddr;
        Raffle[fungibleToken].destroyed = false;
    }

    function getPool(address fungibleToken)
        public
        view
        returns (
            bool,
            address,
            uint256
        )
    {
        return (
            Raffle[fungibleToken].admin[msg.sender],
            Raffle[fungibleToken].productAddr,
            Raffle[fungibleToken].currentRound
        );
    }

    function destroyPool(address fungibleToken) public onlyOwner {
        Raffle[fungibleToken].destroyed = true;
    }

    modifier onlyAdmin(address fungibleToken) {
        require(
            Raffle[fungibleToken].admin[msg.sender],
            "OwnershipError : You are not admin"
        );
        _;
    }

    /**
     * @dev set admin for a pool
     * @param fungibleToken the fungibleToken address
     * @param admin the admin address
     * @param status the Status of admin
     */
    function setAdmin(
        address fungibleToken,
        address admin,
        bool status
    ) public onlyAdmin(fungibleToken) {
        Raffle[fungibleToken].admin[admin] = status;
        emit SettedAdmin(fungibleToken, admin, status);
    }

    event SettedAdmin(address fungibleToken, address admin, bool status);

    /**
     * @dev make a raffle
     * @param fungibleToken the fungibleToken address
     * @param ticketAddr the NFT address
     * @param stratTime the start time of raffle
     * @param endTime the end time of raffle
     */
    function createRound(
        address fungibleToken,
        address ticketAddr,
        uint256 stratTime,
        uint256 endTime
    ) public onlyAdmin(fungibleToken) {
        Raffle[fungibleToken].boxes.push();
        Box storage box = Raffle[fungibleToken].boxes[
            Raffle[fungibleToken].currentRound
        ];

        require(
            Raffle[fungibleToken].destroyed == false,
            "StatusError : Raffle was deleted"
        );

        box.availableNFT[ticketAddr] = true;
        box.startTime = stratTime;
        box.deadline = endTime;
        box.status = Status.ready;

        Raffle[fungibleToken].currentRound++;
        emit roundCreated(fungibleToken, ticketAddr, 1, stratTime, endTime);
    }

    // function getRound(address fungibleToken, uint round) public view returns(uint, uint, Status, address[] memory, product[] memory){
    //     Box storage box = Raffle[fungibleToken].boxes[round];
    //     return (box.startTime, box.deadline, box.status, box.availableNFTs, box.products);
    // }

    function getCurrentRound(address fungibleToken)
        public
        view
        returns (uint256)
    {
        return Raffle[fungibleToken].currentRound;
    }

    event roundCreated(
        address fungibleToken,
        address ticketAddr,
        uint256 round,
        uint256 stratTime,
        uint256 endTime
    );

    /**
     * @dev add a available NFT to a raffle only admin
     * @param fungibleToken the fungibleToken address
     * @param ticketAddr the NFT address
     * @param round the round of raffle
     */
    function addAvailableNFT(
        address fungibleToken,
        address ticketAddr,
        uint256 round
    ) public onlyAdmin(fungibleToken) {
        Box storage box = Raffle[fungibleToken].boxes[round];

        require(
            box.status == Status.ready,
            "StatusError : Status is not ready"
        );
        box.availableNFT[ticketAddr] = true;

        emit AddedAvailableNFT(fungibleToken, ticketAddr, round);
    }

    event AddedAvailableNFT(
        address fungibleToken,
        address ticketAddr,
        uint256 round
    );

    /**
     * @dev add a product to a raffle only admin
     * @param fungibleToken the fungibleToken address
     * @param round the round of raffle
     * @param price the price of NFT
     */

    function addItem(
        address fungibleToken,
        uint256 round,
        uint256 price,
        string memory tokenURI
    ) public onlyAdmin(fungibleToken) {
        ANVRaffleNFT productInstance = ANVRaffleNFT(Raffle[fungibleToken].productAddr);
        Box storage box = Raffle[fungibleToken].boxes[round];

        require(box.status == Status.ready, "StatusError: Status is not ready");

        uint256 len = box.products.length;
        box.products.push();
        box.products[len].tokenId = productInstance.getTokenAmount();
        box.products[len].price = price;

        productInstance.mintWithTokenURI(address(this), tokenURI);

        emit AddedItem(fungibleToken, round, box.products[len].tokenId, price);
    }

    event AddedItem(
        address fungibleToken,
        uint256 round,
        uint256 NFTId,
        uint256 price
    );

    function batchAddItem(
        address fungibleToken,
        uint256 round,
        uint256[] memory price,
        string[] memory tokenURI
    ) public onlyAdmin(fungibleToken) {
        uint256 priceLength = price.length;
        ANVRaffleNFT productInstance = ANVRaffleNFT(Raffle[fungibleToken].productAddr);
        Box storage box = Raffle[fungibleToken].boxes[round];

        require(box.status == Status.ready, "StatusError: Status is not ready");

        for (uint256 i = 0; i < priceLength; i++) {

            uint256 len = box.products.length;
            box.products.push();
            box.products[len].tokenId = productInstance.getTokenAmount();
            box.products[len].price = price[i];

            productInstance.mintWithTokenURI(address(this), tokenURI[i]);

            emit AddedItem(fungibleToken, round, box.products[len].tokenId, price[i]);
        }
    }


    function getItem(
        address fungibleToken,
        uint256 round,
        uint256 itemIdx
    )
        public
        view
        returns (
            uint256,
            uint256,
            address[] memory,
            address
        )
    {
        Box storage box = Raffle[fungibleToken].boxes[round];
        return (
            box.products[itemIdx].tokenId,
            box.products[itemIdx].price,
            box.products[itemIdx].entry,
            box.products[itemIdx].winner
        );
    }

    // function getItems(address fungibleToken, uint round) public view returns(product[] memory){
    //     Box storage box = Raffle[fungibleToken].boxes[round];
    //     return box.products;
    // }

    /**
     * @dev remove a product from a raffle only admin
     * @param fungibleToken the fungibleToken address
     * @param round the round of raffle
     * @param itemIdx the Index of the product at this round
     */

    function removeItem(
        address fungibleToken,
        uint256 round,
        uint256 itemIdx
    ) public onlyAdmin(fungibleToken) returns (bool) {
        Box storage box = Raffle[fungibleToken].boxes[round];
        require(
            box.status == Status.ready,
            "StatusError : Status is not ready"
        );
        uint256 NFTId = box.products[itemIdx].tokenId;
        delete box.products[NFTId];

        ANVRaffleNFT(Raffle[fungibleToken].productAddr).burn(NFTId);

        emit removedItem(fungibleToken, round, NFTId);

        return true;
    }

    event removedItem(address fungibleToken, uint256 round, uint256 NFTId);

    /**
     * @dev join to raffle
     * @param fungibleToken the fungibleToken address
     * @param round the round of raffle
     * @param selectedItem the selected product
     * @param addrOfNFT the NFT address
     * @param userNFT the NFT tokenId
     */

    function joinRound(
        address fungibleToken,
        uint256 round,
        uint256 selectedItem,
        address addrOfNFT,
        uint256 userNFT
    ) public {
        Box storage box = Raffle[fungibleToken].boxes[round];
        product storage selectedProduct = box.products[selectedItem];
        require(
            box.status == Status.ongoing,
            "StatusError : Status is not ongoing"
        );

        require(
            box.availableNFT[addrOfNFT] == true,
            "StatusError : This NFT isn't ticket"
        );
        require(
            IERC721(addrOfNFT).ownerOf(userNFT) == msg.sender,
            "OwnerError : You don't have this NFT"
        );
        require(
            box.usedTicket[addrOfNFT][userNFT] == false,
            "StatusError : This NFT was used"
        );
        box.usedTicket[addrOfNFT][userNFT] = true;

        uint256 price = selectedProduct.price;
        require(
            IERC20(fungibleToken).balanceOf(msg.sender) >=
                price,
            "BalanceError : You don't have enough token for pay"
        );
        IERC20(fungibleToken).transferFrom(
            msg.sender,
            address(this),
            price
        );

        selectedProduct.entry.push(msg.sender);
        selectedProduct.countForRefunding[msg.sender]++;

        emit JoinedRound(
            msg.sender,
            fungibleToken,
            round,
            selectedItem,
            addrOfNFT,
            userNFT
        );
    }

    function usedTicket(
        address fungibleToken,
        uint256 round,
        address addrOfNFT,
        uint256 tokenId
    ) public view returns (bool) {
        return
            Raffle[fungibleToken].boxes[round].usedTicket[addrOfNFT][tokenId];
    }

    event JoinedRound(
        address joiner,
        address fungibleToken,
        uint256 round,
        uint256 selectedItem,
        address addrOfNFT,
        uint256 userNFT
    );

    /**
     * @dev end a raffle
     * @param fungibleToken the fungibleToken address
     * @param round the round of raffle
     */

    function endRound(address fungibleToken, uint256 round)
        public
        onlyAdmin(fungibleToken)
    {
        Box storage box = Raffle[fungibleToken].boxes[round];
        require(
            box.status == Status.ongoing,
            "StatusError : Status is not ongoing"
        );
        require(
            block.number >= box.deadline,
            "TimeError : Shop is not completed"
        );
        box.status = Status.completed;

        emit CompletedRound(fungibleToken, round);
    }

    function forceEndRound(address fungibleToken, uint256 round)
        public
        onlyAdmin(fungibleToken)
    {
        Box storage box = Raffle[fungibleToken].boxes[round];
        require(
            box.status == Status.ongoing,
            "StatusError : Status is not ongoing"
        );
        box.status = Status.completed;

        emit CompletedRound(fungibleToken, round);
    }

    event CompletedRound(address fungibleToken, uint256 round);

    function cancelRound(address fungibleToken, uint256 round)
        public
        onlyAdmin(fungibleToken)
    {
        Box storage box = Raffle[fungibleToken].boxes[round];
        require(
            box.status == Status.ready,
            "StatusError : Status is not ready"
        );

        box.status = Status.canceled;

        emit CanceledRound(fungibleToken, round);
    }

    event CanceledRound(address fungibleToken, uint256 round);

    function startRound(address fungibleToken, uint256 round)
        public
        onlyAdmin(fungibleToken)
    {
        Box storage box = Raffle[fungibleToken].boxes[round];
        require(
            box.status == Status.ready,
            "StatusError : Shop is not available"
        );
        box.status = Status.ongoing;
        require(
            block.number >= box.startTime,
            "TimeError : Shop is completed"
        );

        emit StartedRound(fungibleToken, round);
    }

    event StartedRound(address fungibleToken, uint256 round);

    /**
     * @dev lucky draw
     * @param fungibleToken the fungibleToken address

     * @param round the round of raffle
     * @param itemNumber the product number
     */

    function luckyDraw(
        address fungibleToken,
        uint256 round,
        uint256 itemNumber
    ) internal view returns (uint256) {
        Box storage box = Raffle[fungibleToken].boxes[round];
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        box.products[itemNumber].entry.length
                    )
                )
            ) % box.products[itemNumber].entry.length;
    }

    function draw(
        address fungibleToken,
        uint256 round,
        uint256 itemNumber
    )
        public
        onlyAdmin(fungibleToken)
        returns (uint256 luckyDrawedNumber, address winner)
    {
        Box storage box = Raffle[fungibleToken].boxes[round];
        product storage _product = box.products[itemNumber];
        require(
            box.status == Status.completed,
            "StatusError : Status is not completed"
        );

        uint256 drawedNumber = luckyDraw(fungibleToken, round, itemNumber);
        address _winner = _product.entry[drawedNumber];

        require(
            _product.winner == address(0),
            "StatusError : Already drawed product"
        );
        _product.winner = _winner;
        _product.countForRefunding[_winner]--;

        ANVRaffleNFT(Raffle[fungibleToken].productAddr).transferFrom(
            address(this),
            _winner,
            _product.tokenId
        );

        emit LuckyDrawed(fungibleToken, round, itemNumber, winner);
        return (drawedNumber, winner);
    }

    event LuckyDrawed(
        address fungibleToken,
        uint256 round,
        uint256 itemNumber,
        address winner
    );

    function discard(
        address fungibleToken,
        uint256 tokenId,
        uint256 price
    ) public onlyAdmin(fungibleToken) {
        ANVRaffleNFT productInstance = ANVRaffleNFT(Raffle[fungibleToken].productAddr);

        require(
            productInstance.isDiscarded(tokenId) == false,
            "Already Discarded"
        );
        productInstance.discard(tokenId);

        IERC20(fungibleToken).transfer(
            productInstance.ownerOf(tokenId),
            price
        );
    }

    function refund(
        address fungibleToken,
        uint256 round,
        uint256 itemNumber,
        address user
    ) public {
        Box storage box = Raffle[fungibleToken].boxes[round];
        product storage _product = box.products[itemNumber];
        require(
            box.status == Status.completed || box.status == Status.canceled,
            "StatusError : Status is not for refunding"
        );

        uint256 countForRefunding = _product.countForRefunding[user];
        _product.countForRefunding[user] = 0;

        IERC20(fungibleToken).transfer(
            user,
            _product.price * countForRefunding
        );
        
    }

    function getRefundingAmount(
        address fungibleToken,
        uint256 round,
        uint256 itemNumber,
        address user
    ) public view returns (uint256) {
        product storage _product = Raffle[fungibleToken].boxes[round].products[
            itemNumber
        ];
        return _product.countForRefunding[user] * _product.price;
    }

    function batchRefund(
        address fungibleToken,
        uint256 round,
        uint256 itemNumber,
        address[] calldata user
    ) public {
        uint256 userLength = user.length;
        Box storage box = Raffle[fungibleToken].boxes[round];
        product storage _product = box.products[itemNumber];
        require(
            box.status == Status.completed || box.status == Status.canceled,
            "StatusError : Status is not for refunding"
        );
        
        for (uint256 i = 0; i < userLength; i++) {

            uint256 countForRefunding = _product.countForRefunding[user[i]];
            _product.countForRefunding[user[i]] = 0;

            IERC20(fungibleToken).transfer(
                user[i],
                _product.price * countForRefunding
            );
        }
    }
}
