# Proveably Random Raffle Contracts

## About
This code is to create a proveably random smart contract lottery

## What we want it to do?

1. Users can enter by paying for a ticket
   1. The ticket fees are going to go to the winner during the draw
2. After X period of time, the lottery will automatically  draw a winner
   1. And this will be done programmatically 
3. Using Chainlink VRF & Chainlink Automation 
   1. Chainlink VRF -> Randomness
   2. Chainlink Automation -> Time based trigger

## Tests!

1. Write some deploy scripts
2. Write our tests
   1. Work on a local chain
   2. Forked Testnet
   3. Forked Mainnet 

# ----------- Contract Docs --------------

## Raffle.sol Contract
1. This contract is a raffle game that uses Chainlink's VRF to pick a winner
2. Constructor: sets the entrace fee, interval between raffles, and teh details for the Chainlink VRF
3. Users can enter the raffle by calling the `enterRaffle` function and sending enough ETH to cover the entrance fee
4. The `checkUpKeep` function checks if it's time to pick a winner. It returns true if the interval has passed, the raffle is open, the contract has a balance (there are players), and the Chainlink subscription is funded
5. If `checkUpKeep` returns true, the `performUpKeep` function is called. This function requests a random number from Chainlink's VRF and sets the raffle state to closed
6. When Chainlink's VRF returns a random number, the `fulfillRandomWords` function is called and this function picks a winner based on the random number, resets the raffle, and sends all the ETH in the contract to the winner

## DeployRaffle.s.sol contract
1. This contract is a script that deploys a new Raffle contract and sets it up with the necessary confifgurations
2. Create HelperConfig: creates a new instance of the HelperConfig contract and this contract is used to get the network configuration
3. Get Network Configuration: it calls the `activeNetworkConfig` function of the HelperConfig contract to get the network configuration. The configuration is returned as a tuple, which is then deconstrcuted into individual variables
4. Check Subscription Id: If the subscription ID is 0 (doesn't exist), it creates a new subscription using the CreateSubscription contract and funds it using the FundSubscription contract 
5. Deploy Raffle Contract: it deploys a new Raffle contract using the network configuration variables as arguments
6. Add Raffle as Consumer: since this is a new raffle, it needs to be added as a consumer to the subscription. This is done using the AddConsumer contract 
7. Return Deployed Contracts: it returns the deployed Raffle contract and the HelperConfig contract

## HelperConfig.s.sol
1. This contract is used to manage the deployment and network configuation for the Raffle contract. It provides a structure NetworkConfig that holds all the necessary configuration parameters for the Raffle contract
2. In the constructor, it checks the chain id of the current network. If the chain id is 11155111, it sets the `activeNetworkConfig` to the Sepolia Ethereum network configuration by called the `getSepoliaEthConfig`. Otherwise, it sets the `activeNetworkConfig` to the Anvil Ethereum network configuration by called `getOrCreateAnvilEthConfig` 
3. Get Sepolia ETH Configuration: the `getSepoliaEthConfig` function returns a hardcoded configuration for the Sepolia Ethereum network
4. Get or Create Anvil Ethereum Configuration: the `getOrCreateAnvilEthConfig` function checks if the `vrfCoordinator` of the `activeNetworkConfig`. Otherwise, it creates a new `VRFCoordinatorV2Mock` and `LinkToken` contracts and returns a configuration that uses these contracts 

## Interactions.s.sol
1. This contract contains 3 contracts: `CreateSubscription`, `FundSubscription`, and `AddConsumer`. These contracts are used to interact with the `VRFCoordinatorV2Mock` contract and the `LinkToken` contract
2. CreateSubscription: used to create a new subscription on the `VRFCoordinatorV2Mock` contract. It has a `createSubscription` function that takes a `vrfCoordinator` address as an argument and creates a new subscription. The `createSubscriptionUsingConfig` function gets the `vrfCoordinator` from the `HelperConfig` contract and calls the `createSubscription` function
3. FundSubscription: this contract is used to fund a subscription on the `VRFCoordinatorV2Mock` contract or the `LinkToken` contract. It has a `fundSubscription` function that takes a `vrfCoordinator`, `subscriptionId`, and `link` address as arguments and funds the subscription. The `fundSubscriptionUsingConfig` function gets the `vrfCoordinator`, and `link` from the `HelperConfig` contract and calls the `fundSubscription` function. 


