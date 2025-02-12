// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mock/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run () public {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinator;
        (uint256 subId,) = createSubscription(vrfCoordinator);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256, address) {
        console.log("creating subscription on chain Id:", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("subscription Id is ", subId);
        console.log("Update the subscription Id on your Helper.config.s.sol");
        return (subId, vrfCoordinator);
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether;

    function run () public {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinator;
        uint256 subcriptionId = config.subscriptionId;
        address linkToken = config.link;
        fundSubscription(vrfCoordinator, subcriptionId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subcriptionId,address linkToken) public {
        console.log("funding subscription", subcriptionId);
        console.log("using vrf coordinator", vrfCoordinator);
        console.log("on chainId: ", block.chainid);

        if(block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subcriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subcriptionId));
            vm.stopBroadcast();
        }

    }
}

contract AddConsumer is Script {
    function run () external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        uint256 subId = config.subscriptionId;
        address vrf_coordinator = config.vrfCoordinator;
        addConsumer(mostRecentlyDeployed, vrf_coordinator, subId);
    }   

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId) public {
        console.log("adding consumer contract: ", contractToAddToVrf);
        console.log("to vrfCoordinator: ", vrfCoordinator);
        console.log("on chain id", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }   

}