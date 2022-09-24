// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title DevTheGathering
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract DevTheGathering is Ownable, VRFConsumerBaseV2 {
    /*
        VRFConsumerBaseV2 configurations:
    */

    VRFCoordinatorV2Interface internal COORDINATOR;
    LinkTokenInterface internal LINKTOKEN;

    // Your VRF subscription ID.
    uint64 vrfSubscriptionId;
    address vrfLink;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash = 0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 500000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords = 3;

    /*
        DevTheGathering configurations:
    */

    /**
     * @dev the starter price of a booster package.
     */
    uint256 public boosterPrice = .45 ether;

    /**
     * @dev enum with the possibles developer status.
     */
    enum DeveloperStatus {
        IDLE,
        OPENING_BOOSTER_PACK
    }

    /**
     * @dev Struct for developer data
     *
     * @custom:property {Cards} Its the cards owned by the developer.
     * @custom:property {status} Its a enum that holds the players status
     */
    struct Developer {
        uint256[] Cards;
        DeveloperStatus status;
    }

    /**
     * @dev Mapping of developer address to developer data
     */
    mapping(address => Developer) public developers;

    /**
     * @dev Mapping of Chainlink request Id to developer address
     */
    mapping(uint256 => address) private requestToDeveloper;

    event BoosterOpened(uint256 id, address from, uint256[3] cards);

    constructor(
        address vrfCoordinator,
        address link,
        uint64 _vrfSubscriptionId
    ) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        vrfSubscriptionId = _vrfSubscriptionId;
        vrfLink = link;
    }

    // Assumes the subscription is funded sufficiently.
    function openBoosterPack() external payable {
        require(msg.value > boosterPrice, "Not enough balance.");
        require(
            developers[_msgSender()].status == DeveloperStatus.IDLE,
            "A booster pack is currently being opened."
        );
        //require(LINKTOKEN.balanceOf(address(this)) > 1 ether, "Not enough LINK - fill contract with faucet");
        developers[_msgSender()].status = DeveloperStatus.OPENING_BOOSTER_PACK;
        // Will revert if subscription is not set and funded.
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            vrfSubscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        requestToDeveloper[requestId] = _msgSender();
    }

    // function test()
    //     public
    //     onlyOwner
    //     view
    //     returns  (uint)
    // {
    //     LinkTokenInterface link = LinkTokenInterface(vrfLink);
    //     return link.balanceOf(address(this));
    // }

    function updateBoosterPrice(uint256 newBoosterPrice)
        public
        onlyOwner
        returns (uint256)
    {
        boosterPrice = newBoosterPrice;
        return boosterPrice;
    }

    function withdraw() public onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Transfer failed!");
    }

    function getMyCards() public view returns (uint256[] memory) {
        return developers[_msgSender()].Cards;
    }

    function getDeveloperCards(address developerAddress) public view returns (uint256[] memory) {
        return developers[developerAddress].Cards;
    }

    function getMyDeveloperStatus() public view returns (DeveloperStatus) {
        return developers[_msgSender()].status;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomData)
        internal
        override
    {
        developers[requestToDeveloper[requestId]].Cards.push(randomData[0]);
        developers[requestToDeveloper[requestId]].Cards.push(randomData[1]);
        developers[requestToDeveloper[requestId]].Cards.push(randomData[2]);
        developers[requestToDeveloper[requestId]].status = DeveloperStatus.IDLE;

        emit BoosterOpened(
            requestId,
            requestToDeveloper[requestId],
            [randomData[0], randomData[1], randomData[2]]
        );
    }

    // modifier costs(uint price) {
    //     require(msg.value >= price);
    //     _;
    // }

    // fallback() external payable { revert(); }
    // receive() external payable { }
}
