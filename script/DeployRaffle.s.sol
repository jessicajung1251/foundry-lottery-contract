// SPDX-License-Identifier: MIT

// run function creates a new instance of the `HelperConfig` contract and calls the `activeNetworkConfig` function to get the network configuration. The `activeNetworkConfig` function returns a tuple of values, which are then deconstructed into individual variables. The `Raffle` contract is then deployed with the deconstructed values as arguments. The `run` function returns the deployed `Raffle` contract.

// If we don't have a subscription ID, then we create one and fund it. Then we launch a raffle, and since it's a brand new raffle, we need to add the raffle as a consumer to the subscription.
// 

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

pragma solidity ^0.8.18;

// Refactor this so that the script can get the subscriptionId
contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // Deconstructing `NetworkConfig config = helperConfig.activeNetworkConfig();`
        (uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit, 
        address link,
        uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if(subscriptionId == 0) {
            // We need to create a subscription
            CreateSubscription createSubscription = new CreateSubscription(); 
            subscriptionId = createSubscription.createSubscription(vrfCoordinator, deployerKey);
            // Fund it!
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinator, subscriptionId, link, deployerKey);

        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee, 
            interval, 
            vrfCoordinator, 
            gasLane,
            subscriptionId, 
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), vrfCoordinator, subscriptionId, deployerKey);  
        return (raffle, helperConfig);
    }

    // add subscription id logic here 

}