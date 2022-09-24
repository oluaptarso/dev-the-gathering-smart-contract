// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title DevTheGathering
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract DevTheGatheringV2 is Ownable, VRFConsumerBaseV2 {
    
    using Counters for Counters.Counter;
    
    /*
        VRFConsumerBaseV2:
    */

    VRFCoordinatorV2Interface internal COORDINATOR;
    LinkTokenInterface internal LINKTOKEN;

    // Your VRF subscription ID.
    uint64 vrfSubscriptionId;
    address vrfLink;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 vrfKeyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 800000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 randomNumbersNeeded = 3;

    /*
        DevTheGathering:
    */

    /**
     * @dev Constants that help divide a random 77 digits in 3 blocks of 25.
     */
    uint private constant _firstCut = 100;
    // 100000000000000000000000000000000000000000000000000
    uint256 private constant _lastBlockCut = 10**50;
    // 10000000000000000000000000
    uint256 private constant _lastPartCut = 10**25;    

    /**
     * @dev the starter price of a booster package.
     */
    uint256 public boosterPrice = .025 ether;

    /**
     * @dev enum with the possibles developer status.
     */
    enum DeveloperStatus {
        IDLE,
        OPENING_BOOSTER_PACK
    }

    /**
     * @dev enum with the possibles card rarity.
     */
    enum CardRarity {
        COMMON,
        UNCOMMON,
        RARE,
        EPIC,
        LEGENDARY
    }

    /**
     * @dev Mapping of the quantity of cards of each rarity, it should be updated by the owner if new cards are added.
     */    
    mapping(CardRarity => uint) public cardQuantitiesByRarity;    

    /**
     * @dev Struct for developer data:
     *     
     * @custom:property {status} Enum that indicates the players status.
     * @custom:property {cardsIdsPointer} Mapping of the hash (address + card.externalId) to the cards id owned by the developer.
     * @custom:property {created} Boolean that indicates if the developer data is already created.
     * @custom:property {createdAt} Timestamp of the developer creator.
     * @custom:property {updatedAt} Timestamp of the developer last update.
     */
    struct Developer {
        DeveloperStatus status;
        mapping(bytes32 => uint) cardsIdsPointer;
        bool created;
        uint createdAt;
        uint updatedAt;
    }

    /**
     * @dev Mapping of developers addresses to developers data.
     */
    mapping(address => Developer) public developers;
    
    /**
     * @dev Counter that helps control the ids of developers cards.
     */
    Counters.Counter private _developerCardsIds;

    /**
     * @dev Struct for card data:
     *     
     * @custom:property {externalId} The id of the card in the WebDApp.
     * @custom:property {owner} The address of the card owner.
     * @custom:property {rarity} Enum that indicates the rarity of the card.
     * @custom:property {foil} Boolean that indicates if the card is a foil.
     * @custom:property {quantity} uInt that indicates how many copies of the card the owner has.
     * @custom:property {level} uInt that indicates the card level.
     * @custom:property {created} Boolean that indicates if the developer data is already created.
     * @custom:property {createdAt} Timestamp of the developer creator.
     * @custom:property {updatedAt} Timestamp of the developer last update.
     */
    struct Card {
        uint externalId;
        address owner;
        CardRarity rarity;
        bool foil;
        uint quantity;
        uint level;
        bool created;
        uint createdAt;
        uint updatedAt;
    }

    /**
     * @dev Mapping of cards ids to cards data.
     */
    mapping(uint => Card) public cards;

    /**
     * @dev Mapping of Chainlink requests Ids to developers addresses.
     */
    mapping(uint256 => address) private requestToDeveloper;

    /**
     * @dev Event triggered when a card is created.
     */
    event CardCreated(
        uint externalId,
        address owner,
        CardRarity rarity,
        bool foil,
        uint quantity,
        uint level,
        bool created,
        uint createdAt,
        uint updatedAt
    );

    /**
     * @dev Event triggered when a card is updated.
     */
    event CardUpdated(
        uint externalId,
        address owner,
        CardRarity rarity,
        bool foil,
        uint quantity,
        uint level,
        bool created,
        uint createdAt,
        uint updatedAt
    );


    /**
     * @dev Smart contract constructor, is responsible for link the contract at the oracle service for random numbers 
     *      and initialize the quantities of the cards by rarity.
     */
    constructor(
        address vrfCoordinator,
        address link,
        bytes32 keyHash,
        uint64 _vrfSubscriptionId
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        vrfSubscriptionId = _vrfSubscriptionId;
        vrfLink = link;
        vrfKeyHash = keyHash;

        cardQuantitiesByRarity[CardRarity.COMMON] = 9;
        cardQuantitiesByRarity[CardRarity.UNCOMMON] = 6;
        cardQuantitiesByRarity[CardRarity.RARE] = 4;
        cardQuantitiesByRarity[CardRarity.EPIC] = 2;
        cardQuantitiesByRarity[CardRarity.LEGENDARY] = 1;
    }

    /**
     * @dev Method that developers use to buy and open a booster pack that holds 3 random cards that will be generated.
     */
    function openBoosterPack() external payable {
        require(msg.value >= boosterPrice, "Not enough balance.");
        require(
            developers[_msgSender()].status == DeveloperStatus.IDLE,
            "A booster pack is currently being opened."
        );
        
        // Will revert if subscription is not set and funded.
        uint256 requestId = COORDINATOR.requestRandomWords(
            vrfKeyHash,
            vrfSubscriptionId,
            requestConfirmations,
            callbackGasLimit,
            randomNumbersNeeded
        );

        if (!developers[_msgSender()].created) {
            developers[_msgSender()].created = true;
            developers[_msgSender()].createdAt = block.timestamp;
            developers[_msgSender()].updatedAt = developers[_msgSender()].createdAt;
        }
        else{
            developers[_msgSender()].updatedAt = block.timestamp;
        }

        developers[_msgSender()].status = DeveloperStatus.OPENING_BOOSTER_PACK;

        requestToDeveloper[requestId] = _msgSender();
    }

    /**
     * @dev Callback method that the oracle calls to give the smart contract the random data requested that is 
     *      necessary to generate the developer cards.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomData)
        internal
        override
    {
        //Developer memory memoryDev = developers[requestToDeveloper[requestId]];
        developers[requestToDeveloper[requestId]].status = DeveloperStatus.IDLE;

        for (uint i = 0; i < randomNumbersNeeded; i++) {
            
            (uint n1, uint n2, uint n3) = splitRandomInThreeParts(randomData[i]);
            
            Card memory card = revealCard([n1, n2, n3]);
            
            bytes32 composedId = keccak256(
                    abi.encodePacked(card.externalId, requestToDeveloper[requestId])
            );
            
            /**
             * @dev if the developer has already that card.
             */
            if (cards[developers[requestToDeveloper[requestId]].cardsIdsPointer[composedId]].created) {

                uint findedCardId = developers[requestToDeveloper[requestId]].cardsIdsPointer[composedId];
                /**
                 * @dev if the new card its a foil one transform the old to foil.
                 */
                if (card.foil && !cards[findedCardId].foil) {
                    cards[findedCardId].foil = true;
                }

                cards[findedCardId].quantity++;

                /**
                 * @dev if the card has the requirements to evolve, level up and resets the quantity.
                 */
                if (cards[findedCardId].quantity == (cards[findedCardId].level) * 2) {
                    cards[findedCardId].quantity = 0;
                    cards[findedCardId].level++;
                }

                cards[findedCardId].updatedAt = block.timestamp;

                emit CardUpdated(
                    cards[findedCardId].externalId, 
                    cards[findedCardId].owner, 
                    cards[findedCardId].rarity, 
                    cards[findedCardId].foil, 
                    cards[findedCardId].quantity,
                    cards[findedCardId].level, 
                    cards[findedCardId].created, 
                    cards[findedCardId].createdAt, 
                    cards[findedCardId].updatedAt
                );

            } else {
                _developerCardsIds.increment();
                uint cardId = _developerCardsIds.current();

                card.created = true;
                card.owner = requestToDeveloper[requestId];
                card.quantity = 0;
                card.level = 1;
                card.createdAt = block.timestamp;
                card.updatedAt = card.createdAt;

                cards[cardId] = card;
                developers[requestToDeveloper[requestId]].cardsIdsPointer[composedId] = cardId;

                emit CardCreated(card.externalId, card.owner, card.rarity, card.foil, card.quantity, card.level, card.created, card.createdAt, card.updatedAt);
            }
        }
    }

    /**
     * @dev Method that the owner of coontract can use to update the booster pack price.
     */
    function updateBoosterPrice(uint256 newBoosterPrice)
        public
        onlyOwner
        returns (uint256)
    {
        boosterPrice = newBoosterPrice;
        return boosterPrice;
    }

    /**
     * @dev Method that the owner of coontract can use to update the cards quantity.
     */
    function updateCardsQuantity(CardRarity rarity, uint newQuantity)
        public
        onlyOwner
    {
        cardQuantitiesByRarity[rarity] = newQuantity;
    }

    /**
     * @dev Method that the owner of coontract can use to withdraw the contract balance.
     */
    function withdraw() public onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Transfer failed!");
    }    

    /**
     * @dev Method that the developer can use to get his current status.
     */
    function getMyDeveloperStatus() public view returns (DeveloperStatus) {
        return developers[_msgSender()].status;
    }

    /**
     * @dev Method that breaks a 77 digits uInt number into three 25 digits uInt numbers.
     */
    function splitRandomInThreeParts(uint value)
        internal
        pure
        returns (
            uint256 n1,
            uint256 n2,
            uint256 n3
        )
    {
        uint message = value / _firstCut;
        uint lastPart = message % _lastBlockCut;
        n1 = message / _lastBlockCut;
        n2 = lastPart / _lastPartCut;
        n3 = lastPart % _lastPartCut;
    }

    /**
     * @dev Method that reveals the card given the 3 random numbers.
     */
    function revealCard(uint[3] memory randoms)
        internal
        view
        returns (Card memory)
    {
        uint rarityChance = (randoms[0] % 100) + 1;
        bool foil = ((randoms[2] % 100) + 1) <= 5;
        Card memory card;
        card.foil = foil;

        if (rarityChance >= 50) {
            card.rarity = CardRarity.COMMON;
            card.externalId = (randoms[1] % cardQuantitiesByRarity[CardRarity.COMMON]) + 1;
        } else if (rarityChance >= 30 && rarityChance <= 49) {
            card.rarity = CardRarity.UNCOMMON;
            card.externalId = ((randoms[1] % cardQuantitiesByRarity[CardRarity.UNCOMMON]) + 1) + 1000;
        } else if (rarityChance >= 13 && rarityChance <= 29) {
            card.rarity = CardRarity.RARE;
            card.externalId = ((randoms[1] % cardQuantitiesByRarity[CardRarity.RARE]) + 1) + 2000;
        } else if (rarityChance >= 5 && rarityChance <= 12) {
            card.rarity = CardRarity.EPIC;
            card.externalId = ((randoms[1] % cardQuantitiesByRarity[CardRarity.EPIC]) + 1) + 3000;
        } else {
            card.rarity = CardRarity.LEGENDARY;
            card.externalId = ((randoms[1] % cardQuantitiesByRarity[CardRarity.LEGENDARY]) + 1) + 4000;
        }

        return card;
    }
}
