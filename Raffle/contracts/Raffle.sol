// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721_ANVPausable.sol";

contract RaffleShop is Ownable {
    enum Status {
        ready,
        ongoing,
        completed,
        canceled
    }

    // fungibleToken => shop
    mapping(address => Shop) shop;

    struct Shop {
        Box[] boxes;
        mapping(address => bool) admin;
        uint256 currentBox;
        address productAddr;
        bool destroyed;
    }

    struct Box {
        uint256 startBlock;
        uint256 deadline;
        Status status;
        product[] products;
        address availableNFT;
        mapping(uint256 => bool) usedTicket;
    }

    struct product {
        uint256 tokenId;
        uint256 price;
        uint256[] entry;
        address winner;
        mapping(address => uint256) countForRefunding;
        mapping(uint256 => address) originOwner;
    }

    /**
     * @dev create a pool for a fungibleToken and admin was setted using setAdmin function
     * @param fungibleToken the fungibleToken address
     */

    function createShop(address fungibleToken, address productAddr)
        public
        onlyOwner
    {
        require(
            shop[fungibleToken].admin[msg.sender] == false,
            "Error : Already created shop"
        );
        shop[fungibleToken].admin[msg.sender] = true;
        shop[fungibleToken].productAddr = productAddr;
        shop[fungibleToken].destroyed = false;

        emit CreatedShop(fungibleToken, msg.sender, productAddr);
    }

    event CreatedShop(address fungibleToken, address admin, address productAddr);

    function getShop(address fungibleToken)
        public
        view
        returns (
            bool admin,
            address productAddr,
            uint256 currentBox
        )
    {
        return (
            shop[fungibleToken].admin[msg.sender],
            shop[fungibleToken].productAddr,
            shop[fungibleToken].currentBox
        );
    }

    function destroyShop(address fungibleToken) public onlyOwner {
        shop[fungibleToken].destroyed = true;

        emit DestroyedShop(fungibleToken);
    }

    event DestroyedShop(address fungibleToken);

    modifier onlyAdmin(address fungibleToken) {
        require(
            shop[fungibleToken].admin[msg.sender],
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
        shop[fungibleToken].admin[admin] = status;
        emit SettedAdmin(fungibleToken, admin, status);
    }

    event SettedAdmin(address fungibleToken, address admin, bool status);

    function checkAdmin(address fungibleToken, address target)
        public
        view
        returns (bool admin)
    {
        return shop[fungibleToken].admin[target];
    }

    /**
     * @dev make a raffle
     * @param fungibleToken the fungibleToken address
     * @param ticketAddr the NFT address
     * @param startBlock the start Block of raffle
     * @param endBlock the end Block of raffle
     */
    function createBox(
        address fungibleToken,
        address ticketAddr,
        uint256 startBlock,
        uint256 endBlock
    ) public onlyAdmin(fungibleToken) 
    {
        shop[fungibleToken].boxes.push();
        Box storage box = shop[fungibleToken].boxes[
            shop[fungibleToken].currentBox
        ];

        require(
            shop[fungibleToken].destroyed == false,
            "StatusError : shop was deleted"
        );

        box.availableNFT = ticketAddr;
        box.startBlock = startBlock;
        box.deadline = endBlock;
        box.status = Status.ready;

        shop[fungibleToken].currentBox++;

        emit createdBox(fungibleToken, ticketAddr, shop[fungibleToken].currentBox-1, startBlock, endBlock);
    }

    event createdBox(
        address fungibleToken,
        address ticketAddr,
        uint256 boxIdx,
        uint256 startBlock,
        uint256 endBlock
    );

    function viewBox(address fungibleToken, uint256 boxIdx)
        public
        view
        returns (
            uint256 startBlock,
            uint256 endBlock,
            Status status
        )
    {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        return (box.startBlock, box.deadline, box.status);
    }

    // function getRaffle(address fungibleToken, uint boxIdx) public view returns(uint, uint, Status, address[] memory, product[] memory){
    //     Box storage box = shop[fungibleToken].boxes[boxIdx];
    //     return (box.startBlock, box.deadline, box.status, box.availableNFTs, box.products);
    // }
    

    function getCurrentBox(address fungibleToken)
        public
        view
        returns (uint256 currentBox)
    {
        return shop[fungibleToken].currentBox;
    }


    /**
     * @dev add a available NFT to a raffle only admin
     * @param fungibleToken the fungibleToken address
     * @param ticketAddr the NFT address
     * @param boxIdx the boxIdx of raffle
     */
    // function addAvailableNFT(
    //     address fungibleToken,
    //     address ticketAddr,
    //     uint256 boxIdx
    // ) public onlyAdmin(fungibleToken) {
    //     Box storage box = shop[fungibleToken].boxes[boxIdx];

    //     require(
    //         box.status == Status.ready,
    //         "StatusError : Status is not ready"
    //     );
    //     box.availableNFT[ticketAddr] = true;

    //     emit AddedAvailableNFT(fungibleToken, ticketAddr, boxIdx);
    // }

    event AddedAvailableNFT(
        address fungibleToken,
        address ticketAddr,
        uint256 boxIdx
    );

    /**
     * @dev add a product to a raffle only admin
     * @param fungibleToken the fungibleToken address
     * @param boxIdx the boxIdx of raffle
     * @param price the price of NFT
     */

    function makeItem(
        address fungibleToken,
        uint256 boxIdx,
        uint256 price,
        string memory tokenURI,
        Box storage box
    ) internal {
        address productAddress = shop[fungibleToken].productAddr;

        uint256 len = box.products.length;
        box.products.push();
        box.products[len].tokenId = ANVRaffleNFT(productAddress).totalSupply();
        box.products[len].price = price;

        ANVRaffleNFT(productAddress).mintWithTokenURI(address(this), tokenURI);

        emit AddedItem(fungibleToken, boxIdx, box.products[len].tokenId, price);
    }

    function addItem(
        address fungibleToken,
        uint256 boxIdx,
        uint256 price,
        string memory tokenURI
    ) public onlyAdmin(fungibleToken) 
    {
        Box storage box = shop[fungibleToken].boxes[boxIdx];

        require(box.status == Status.ready, "StatusError: Status is not ready");

        makeItem(fungibleToken, boxIdx, price, tokenURI, box);
    }

    event AddedItem(
        address fungibleToken,
        uint256 boxIdx,
        uint256 NFTId,
        uint256 price
    );

    function batchAddItem(
        address fungibleToken,
        uint256 boxIdx,
        uint256[] memory price,
        string[] memory tokenURI
    ) public onlyAdmin(fungibleToken) {
        uint256 priceLength = price.length;
        Box storage box = shop[fungibleToken].boxes[boxIdx];

        require(box.status == Status.ready, "StatusError: Status is not ready");

        for (uint256 i = 0; i < priceLength; i++) {
            makeItem(fungibleToken, boxIdx, price[i], tokenURI[i], box);
        }
    }

    function getItem(
        address fungibleToken,
        uint256 boxIdx,
        uint256 itemIdx
    )
        public
        view
        returns (
            uint256 tokenIdOfProduct,
            uint256 price,
            uint256[] memory entry,
            address winner
        )
    {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        return (
            box.products[itemIdx].tokenId,
            box.products[itemIdx].price,
            box.products[itemIdx].entry,
            box.products[itemIdx].winner
        );
    }

    // function getItems(address fungibleToken, uint boxIdx) public view returns(product[] memory){
    //     Box storage box = shop[fungibleToken].boxes[boxIdx];
    //     return box.products;
    // }

    /**
     * @dev remove a product from a raffle only admin
     * @param fungibleToken the fungibleToken address
     * @param boxIdx the boxIdx of raffle
     * @param itemIdx the Index of the product at this boxIdx
     */

    function removeItem(
        address fungibleToken,
        uint256 boxIdx,
        uint256 itemIdx
    ) public onlyAdmin(fungibleToken) returns (bool) {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        require(
            box.status == Status.ready,
            "StatusError : Status is not ready"
        );
        uint256 NFTId = box.products[itemIdx].tokenId;
        delete box.products[NFTId];

        ANVRaffleNFT(shop[fungibleToken].productAddr).burn(NFTId);

        emit removedItem(fungibleToken, boxIdx, NFTId);

        return true;
    }

    event removedItem(address fungibleToken, uint256 boxIdx, uint256 NFTId);

    /**
     * @dev join to raffle
     * @param fungibleToken the fungibleToken address
     * @param boxIdx the boxIdx of raffle
     * @param selectedItem the selected product
     * @param addrOfNFT the NFT address
     * @param userNFT the NFT tokenId
     */

    function joinRaffle(
        address fungibleToken,
        uint256 boxIdx,
        uint256 selectedItem,
        address addrOfNFT,
        uint256 userNFT
    ) public {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        product storage selectedProduct = box.products[selectedItem];
        require(
            box.status == Status.ongoing,
            "StatusError : The status is not ongoing"
        );
        require(
            block.number > box.startBlock && block.number < box.deadline,
            "TimeError : The deadline is over"
        );
        require(
            box.availableNFT == addrOfNFT,
            "StatusError : This NFT isn't being used as a ticket"
        );
        require(
            IERC721(addrOfNFT).ownerOf(userNFT) == msg.sender,
            "OwnerError : You don't own this NFT"
        );
        require(
            box.usedTicket[userNFT] == false,
            "StatusError : This NFT has been used"
        );
        box.usedTicket[userNFT] = true;

        uint256 price = selectedProduct.price;
        require(
            IERC20(fungibleToken).balanceOf(msg.sender) >= price,
            "BalanceError : You don't have enough tokens for pay"
        );
        selectedProduct.entry.push(userNFT);
        // if mode == 0:
        IERC20(fungibleToken).transferFrom(msg.sender, address(this), price);
        selectedProduct.countForRefunding[msg.sender]++;
        selectedProduct.originOwner[userNFT] = msg.sender;

        // else:
            // if selectedProduct.countForRefunding[msg.sender] == 0:
                // IERC20(fungibleToken).transferFrom(msg.sender, address(this), price);
                // selectedProduct.countForRefunding[msg.sender]++;


        emit JoinedRaffle(
            msg.sender,
            fungibleToken,
            boxIdx,
            selectedItem,
            addrOfNFT,
            userNFT
        );
    }

    function viewRaffle(
        address fungibleToken,
        uint256 boxIdx,
        uint256 itemIndex
    ) public view returns (uint256 ticketAmount) {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        product storage selectedProduct = box.products[itemIndex];
        return selectedProduct.entry.length;
    }

    function usedTicket(
        address fungibleToken,
        uint256 boxIdx,
        uint256 tokenId
    ) public view returns (bool used) {
        return shop[fungibleToken].boxes[boxIdx].usedTicket[tokenId];
    }

    event JoinedRaffle(
        address joiner,
        address fungibleToken,
        uint256 boxIdx,
        uint256 selectedItem,
        address addrOfNFT,
        uint256 userNFT
    );

    /**
     * @dev end a raffle
     * @param fungibleToken the fungibleToken address
     * @param boxIdx the boxIdx of raffle
     */

    function endRaffle(address fungibleToken, uint256 boxIdx)
        public
        onlyAdmin(fungibleToken)
    {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        require(
            box.status == Status.ongoing,
            "StatusError : Status is not ongoing"
        );
        require(
            block.number >= box.deadline,
            "BlockError : shop is not completed"
        );
        box.status = Status.completed;

        emit CompletedRaffle(fungibleToken, boxIdx);
    }

    function forceEndRaffle(address fungibleToken, uint256 boxIdx)
        public
        onlyAdmin(fungibleToken)
    {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        require(
            box.status == Status.ongoing,
            "StatusError : Status is not ongoing"
        );
        box.status = Status.completed;

        emit CompletedRaffle(fungibleToken, boxIdx);
    }

    event CompletedRaffle(address fungibleToken, uint256 boxIdx);

    function cancelRaffle(address fungibleToken, uint256 boxIdx)
        public
        onlyAdmin(fungibleToken)
    {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        require(
            box.status == Status.ready || box.status == Status.ongoing,
            "StatusError : Status is not ready"
        );

        box.status = Status.canceled;

        emit CanceledRaffle(fungibleToken, boxIdx);
    }

    event CanceledRaffle(address fungibleToken, uint256 boxIdx);

    function startRaffle(address fungibleToken, uint256 boxIdx)
        public
        onlyAdmin(fungibleToken)
    {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        require(
            box.status == Status.ready,
            "StatusError : shop is not available"
        );
        box.status = Status.ongoing;
        require(block.number >= box.startBlock, "BlockError : shop is completed");

        emit StartedRaffle(fungibleToken, boxIdx);
    }

    event StartedRaffle(address fungibleToken, uint256 boxIdx);

    /**
     * @dev lucky draw
     * @param entryLength the length of entry
     */

    function luckyDraw(
        uint256 entryLength
    ) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.difficulty,
                        block.timestamp,
                        entryLength
                    )
                )
            ) % entryLength;
    }

    function draw(
        address fungibleToken,
        uint256 boxIdx,
        uint256 itemNumber
    )
        public
        onlyAdmin(fungibleToken)
    {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
        product storage _product = box.products[itemNumber];
        require(
            box.status == Status.completed,
            "StatusError : Status is not completed"
        );

        uint256 drawedNumber = luckyDraw(_product.entry.length);
        uint256 raffleTicket = _product.entry[drawedNumber];
        address _winner = IERC721(box.availableNFT).ownerOf(
            raffleTicket
        );

        require(
            _product.winner == address(0),
            "StatusError : Already drawed product"
        );
        _product.winner = _winner;
        _product.countForRefunding[_product.originOwner[raffleTicket]]--;


        ANVRaffleNFT item = ANVRaffleNFT(shop[fungibleToken].productAddr);
        item.transferFrom(  
            address(this),
            _winner,
            _product.tokenId
        );
        item.pause(
            _product.tokenId
        );

        emit LuckyDrawed(fungibleToken, boxIdx, itemNumber, _winner, raffleTicket);
    }

    event LuckyDrawed(
        address fungibleToken,
        uint256 boxIdx,
        uint256 itemNumber,
        address winner,
        uint256 raffleTicket
    );

    function discard(
        address fungibleToken,
        uint256 tokenId,
        uint256 price
    ) public onlyAdmin(fungibleToken) {
        ANVRaffleNFT productInstance = ANVRaffleNFT(
            shop[fungibleToken].productAddr
        );

        require(
            productInstance.isDiscarded(tokenId) == false,
            "Already Discarded"
        );
        productInstance.discard(tokenId);

        IERC20(fungibleToken).transfer(productInstance.ownerOf(tokenId), price);
    }

    function refund(
        address fungibleToken,
        uint256 boxIdx,
        uint256 itemNumber,
        address user
    ) public {
        Box storage box = shop[fungibleToken].boxes[boxIdx];
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
        uint256 boxIdx,
        uint256 itemNumber,
        address user
    ) public view returns (uint256 refundingAmount) {
        product storage _product = shop[fungibleToken].boxes[boxIdx].products[
            itemNumber
        ];
        return _product.countForRefunding[user] * _product.price;
    }
    function withdraw(address fungibleToken) public onlyAdmin(fungibleToken){
        uint256 amount = IERC20(fungibleToken).balanceOf(address(this));
        IERC20(fungibleToken).transfer(msg.sender, amount);
        
        emit Withdrawed(fungibleToken, amount);
    }

    event Withdrawed(address fungibleToken, uint256 amount);

    function batchRefund(
        address fungibleToken,
        uint256 boxIdx,
        uint256 itemNumber,
        address[] calldata user
    ) public {
        uint256 userLength = user.length;
        Box storage box = shop[fungibleToken].boxes[boxIdx];
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
