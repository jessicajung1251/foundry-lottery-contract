// SPDX-License-Identifier: MIT

// For the random number generation process ->
// We make a request to the chainlink node to generate a random number
// It'll generate the number and call the vrf coordinator contract on chain where only the chain node can respond to it
// That contract call rawFulfillRandomWords function, which we are going to define by overriding it

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

/**
* @title A Sample Raffle Contract
* @author Pattrick Collins
* @notice This contract is for creating a sample raffle
* @dev implements Chainlink VRFv2 
 */

contract Raffle is VRFConsumerBaseV2 {

    /** Type Declarations */
    enum RaffleState {
        OPEN,
        CLOSED
    }   

    // Error -> 1. Revert with error (more gas efficient) 2. Require with error 
    error Raffle_NotEnoughEthToEnterRaffle();
    error Raffle_TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance, uint256 numPlayers, uint256 raffleState
    );

    /** State Variables */
    // private visibility -> more control over access and additional logic 
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee; 
    // @dev Duration of the lottery in seconds 
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    // we can use a dynamic array to keep track of all the players of the raffle
    // we are going to make this array payable so that we can pay players when they win 
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    bool public s_upkeepNeeded;

    // Events 
    // 1. Makes migration easier
    // 2. Makes front end "indexing" easier 
    // Events are allowed up to 3 indexed parameters, aka "topics"
    // Indexed parameters are searchable 
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint64 subscriptionId, uint32 callbackGasLimit) VRFConsumerBaseV2(vrfCoordinator) { 
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;        
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /**
    * @dev This is the function that the Chainlink Automation nodes call to see if it's time to perform an upkeep
    * The following should be true for this to return true:
    * 1. The time interval has passed between raffle runs
    * 2. The raffle is in the OPEN state
    * 3. The contract has ETH (aka, players)
    * 4. (Implicit) The subscription  is funded with LINK 
     */
    // If upkeepNeeded returns true, then it's going to perform performUpKeep 
    function checkUpKeep(bytes memory /** checkData */) public view  returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval; 
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0; 
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return(upkeepNeeded, "0x0"); 
    }

    // 1. Get a random number
    // 2. Use the random number to pick a player 
    // 3. Be automatically called 
    function performUpKeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded,) = checkUpKeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // Check to see if enough time has passed 
        // Chainlink VRF: when you make a request to oracle network -> oracle network generates random numbers -> you need to do something with the returned random number
        // If you don't do anything with the random number as soon as you get them back, they're stored and becomes public -> not rlly random 
        // Block confirmations -> lower the number, the faster the return but less secure. higher the number, the slower the return but more secure

        // 1. Request the RNG -> requesting the winner
        // 2. Get the random number -> picking the winner 

        // if (block.timestamp - s_lastTimeStamp <= i_interval) {
        //     revert (); 
        // }

        // Default raffle state is open (defined in constructor) but when we're in the process of picking a winner, we change the state to closed
        s_raffleState = RaffleState.CLOSED;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, 
            REQUEST_CONFIRMATIONS, // block confirmations
            i_callbackGasLimit, // makes sure we don't overspend 
            NUM_WORDS // number of random numbers 
        );
        // this is redundant, but we are emitting this event to make testing easier -> what if i need to test using the output of an event?
        // events are not accessible by our smart contracts, but they are accessible by our tests
        emit RequestedRaffleWinner(requestId);

    }

    // CEI: checks, effects, interactions
    // Avoids re-entrancy attacks
    function fulfillRandomWords(uint256 /*requestId*/, uint256[] memory randomWords) internal override {
        // Checks 
        // Effects (our own contract)

        // s_players = 10
        // rng = 12
        // 12 % 10 = 2 -> index 2 is the winner 
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        // Once a winner is chosen, we change back the raffle state to open
        s_raffleState = RaffleState.OPEN;

        // Reset the raffle after winner is chosen and start the clock again 
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        // Interactions (other contracts)
        (bool s, ) = s_recentWinner.call{value: address(this).balance}("");
        if (!s) {
            revert Raffle_TransferFailed();
        }   
    }

    /** Getter Functions */
    // State variables of a contract are not directly accessible from outside the contract - if we want to allow other contracts/accounts to read the state of this contract, we need to provide getter functions 

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
       function getLengthOfPlayers() public view returns (uint256) {
        return s_players.length;
    } 
    
}



