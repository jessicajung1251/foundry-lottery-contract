// SPDX-License-Identifier: MIT

// to test the coverage on these files you can run the following command: `forge coverage --report debug > coverage.txt`

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {

    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle public raffle; 
    HelperConfig public helperConfig;        
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    address public PLAYER = makeAddr("player"); 
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (entranceFee,
        interval,
        vrfCoordinator,
        gasLane,
        subscriptionId,
        callbackGasLimit,
        link,
        ) = helperConfig.activeNetworkConfig();
        
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // Enter Raffle 

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        // Every public function has a selector which is a bytes4 value derived from the function's signature (name and argument types)
        // this is used to identify the function in the EVM

        vm.expectRevert(Raffle.Raffle_NotEnoughEthToEnterRaffle.selector);
        // Assert 
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRecorded = raffle.getPlayers(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    // function testEmitsPickedWinnerEvent() public {
    //     // Arrange
    //     vm.prank(PLAYER);
    //     raffle.enterRaffle{value: entranceFee}();
    //     // Act
    //     vm.expectEmit(false, false, true, false, address(raffle));
    //     raffle.pickWinner();
    // }

    // `block.number` is a global variable that returns the number of the current block in the blockchain; used in smart contracts to verify the order of the transactions or to create functions that can only be called after a certain number of blocks have been mined
    // `block.timestamp` is a global variable that provides the current block timestamp as seconds since the unix epoch; used to determine the time period during which a transaction occurred, implement functionality that should happen after a certain time period, create time locks or deadlines in smart contracts 

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // the +1 ensures that you're testing the contract's behavior just after the time-dependent condition becomes true, not at the exact moment it becomes true        
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // test for if (s_raffleState != RaffleState.OPEN) { revert Raffle__RaffleNotOpen();
    function testCantEnterWhenRaffleIsClosed() public raffleEnteredAndTimePassed {
        raffle.performUpKeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();    
    }

    /////////////////////////
    // checkUpkeep         //
    /////////////////////////


    function testCheckUpKeepReturnsFalseIfNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        // Assert
        assert(!upkeepNeeded);

    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public raffleEnteredAndTimePassed {
        // Arrange
        raffle.performUpKeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number - 1);
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    // testCheckUpKeepReturnsTrueWhenParametersAreMet

    function testCheckUpKeepReturnsTrueWhenParametersAreMet() public raffleEnteredAndTimePassed {
        // Arrange

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        // Assert
        assert(upkeepNeeded == true);
    }

    /////////////////////////
    // performUpkeep       //
    /////////////////////////

    function testPerformUpKeepCanOnlyRunIfCheckUpkeepReturnsTrue() public raffleEnteredAndTimePassed {
        // Arrange

        // Act / Assert
        // foundry does not have `expect not revert` so if this transaction doesn't revert we consider the test to be passed
        raffle.performUpKeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpKeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        // Act / Assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState));
        // we expect the following to revert with the custom error message
        raffle.performUpKeep("");

    }

    function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed {
        // Arrange

        // Act
        vm.recordLogs();
        raffle.performUpKeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // all logs are recorded as bytes32 in foundry
        // index 0 is `RandomWordsRequested` in the mock and index 1 is the `RequestedRaffleId` from our contract
        // topics[0] refers to the entire event and topics[1] refers to the first topic, requestId
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Assert
        // checks to see if requestId was actually generated
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    /////////////////////////
    // fulfillRandomWords //
    ////////////////////////

    // skipFork modifier is used to skip the test when we are doing forking
    // allows it to run only on anvil   
    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // fuzzy test
    // provides invalid, unexpected, or random data as inputs to a computer program
    // used to discover coding errors and security loopholes in software, operating systems, or networks by inputting massive amounts of ranom data, called fuzz, to teh system in an attempt to make it crash
    // randomRequestId is a random input
    // test will only run on anvil and not when we are doing forking
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId) public raffleEnteredAndTimePassed skipFork {
        // Arrange
        // test is expecting a revert with the message "nonexistent request" because performUpkeep has not been called yet, so there shouldn't be any existing request for fulfillRandomWords to fulfill
        vm.expectRevert("nonexistent request");
        // this is trying to call fulfillRandomWords with a randomRequestId and the address of the raffle contract 
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    // full test
    // Arrange: simulates multiple entrants entering the raffle. creates a number of additional entrants, each represented by an address, and entrants enters the raffle with an entrance fee  
    // Prize calculation: calculates the total prize money, which is the entrance fee multiplied by the total number of entrants
    // Act: calls the performUpKeep function, which is expected to initiate the raffle draw and emit a RequestedRaffleWinner event with a requestId. Records the logs to capture this requestId 
    // Winner Selection: pretends to be Chainlink VRF Coordinator to get a random number and pick a winner. This is done by calling the fulfillRandomWords function with the requestId and the address of the raffle contract 
    // Assertions: checks several conditions to ensure the raffle system is working correctly:
    // 1. The raffle state is set to 0, indicating that the raffle is closed
    // 2. The recent winner is not the zero address, indicating that a winner has been picked
    // 3. The length of players is 0, indicating that the list of players has been reset
    // 4. The last timestamp has been updated, indicating the raffle draw occurred
    // 5. The recent winner's balance is equal to their starting balance plus the prize money minus the entrance fee, indicating the prize money was transferred correctly 
    function testFulfillRandomWordsPickAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed skipFork {
        address expectedWinner = address(1);
        // Raffle entry: simulates multiple entrants entering the raffle 
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++ ) {
            address player = address(uint160(i)); // generates an address based on the number i
            hoax(player, STARTING_USER_BALANCE);  
            raffle.enterRaffle{value: entranceFee}();
        }
        
        uint256 prize = entranceFee * (additionalEntrants + 1);


        // Calls the performUpKeep function which is expected to initiate the raffle draw
        // this is expected to emit a RequestedRaffleWinner event with a requestId
        // this requestId is expected to be a non-zero value, indicating that a new request for random words has been made

        // Act
        vm.recordLogs();
        raffle.performUpKeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();
        // pretend to be the Chainlink VRF Coordinator to get random number and pick a winner
        // we cast this as a uint256 because the requestId is a bytes32 value
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        assert(uint256(raffle.getRaffleState()) == 0);  
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - entranceFee);

    }


}    

// TODO: write a test for event PickedWinner 

