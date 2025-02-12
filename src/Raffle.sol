// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol"; 
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol"; 

/** 
* @title A sample Raffle Contract
* @notice Live Free
* @dev implements Chainlink VRFv2.5
*/
contract Raffle is VRFConsumerBaseV2Plus {
        /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle_upkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /* type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**State variables */
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint16 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // duration of the lottery in seconds
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_gasLimit;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    // 1. Make migrations easier 
    // 2. Make frontend "indexing" easier
    // 3. Cannot be accesed form the smart contract (for this are soo much cheaper)
    // 4. You can "listen" this events from frontend  
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee, 
        uint256 interval, 
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 gasLimit
        ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;  
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_gasLimit = gasLimit;
        s_raffleState = RaffleState.OPEN;
    }
    
    function enterRaffle() external payable {
        if(msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        if(s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function checkUpKeep(bytes memory /* checkData*/) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, hex"");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded,) = checkUpKeep("");
        if(!upkeepNeeded) {
            revert Raffle_upkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        // request random number
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash, 
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: i_gasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({ nativePayment:false })
                )
            })
        );
        emit RequestedRaffleWinner(requestId);
    }

//// REPLACED WITH ABOVE FUNCTION 
    // function pickWinner() external {
    //     if((block.timestamp - s_lastTimeStamp) > i_interval) {
    //         revert();
    //     }
    //     s_raffleState = RaffleState.CALCULATING;
    //     // subscription 10154160353244790444373568111387600442262141096541236854108976934512836517657
    //     // request random number
    //     uint256 requestId = s_vrfCoordinator.requestRandomWords(
    //         VRFV2PlusClient.RandomWordsRequest({
    //             keyHash: i_keyHash, 
    //             subId: i_subscriptionId,
    //             requestConfirmations: REQUEST_CONFIRMATION,
    //             callbackGasLimit: i_gasLimit,
    //             numWords: NUM_WORDS,
    //             extraArgs: VRFV2PlusClient._argsToBytes(
    //                 VRFV2PlusClient.ExtraArgsV1({ nativePayment:false })
    //             )
    //         })
    //     );
    // }

    function fulfillRandomWords(uint256 /*requestId*/, uint256[] calldata randomWords) internal virtual override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        (bool success, ) = recentWinner.call{value:address(this).balance}("");
        if(!success) {
            revert Raffle__TransferFailed();
        }
    }

    /** Getter functions */
    function getEntranceFee() external view returns(uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns(RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns(address){
        return s_players[indexOfPlayer];
    } 

}
