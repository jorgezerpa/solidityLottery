// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/** 
* @title A sample Raffle Contract
* @notice Live Free
* @dev implements Chainlink VRFv2.5
*/
contract Raffle {
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    /* Errors */
    error Raffle__SendMoreToEnterRaffle();

    /* Events */
    // 1. Make migrations easier 
    // 2. Make frontend "indexing" easier
    // 3. Cannot be accesed form the smart contract (for this are soo much cheaper)
    // 4. You can "listen" this events from frontend  
    event RaffleEntered(address indexed player);



    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }
    
    function enterRaffle() public payable {
        if(msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }
    function pickWinner() public {}

    /** Getter functions */
    function getEntranceFee() external view returns(uint256) {
        return i_entranceFee;
    }
}
