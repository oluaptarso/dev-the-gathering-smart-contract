//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract MockVRFCoordinator {
    uint256 internal counter = 0;
    
    uint256[] private values = [
        66757808040114753260289394369978679672431295293376222342226363195409172495692,
        39345326631805286996944482823445410352006586014452828503724444634365101779366,
        18895622433729888736732327075094827721887022362232708047342911311575928424552
    ];

    function requestRandomWords(
        bytes32,
        uint64,
        uint16,
        uint32,
        uint32
    ) external returns (uint256) {
        VRFConsumerBaseV2 consumer = VRFConsumerBaseV2(msg.sender);
        uint256 requestId = counter;
        consumer.rawFulfillRandomWords(requestId, values);
        counter += 1;

        return requestId;
    }
}