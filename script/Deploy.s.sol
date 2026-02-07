// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { AgentTaskMarketV3 } from "../contracts/AgentTaskMarketV3.sol";

/// @title Deploy AgentTaskMarket V3 to Base Mainnet
/// @notice Uses $CLAWNCH as payment token
contract DeployScript is Script {
    // Base Mainnet Addresses
    address constant CLAWNCH_TOKEN = 0xa1F72459dfA10BAD200Ac160eCd78C6b77A747be;
    address constant FEE_RECIPIENT = 0xC639bBbe01DCE7DC352120C315E82E49C71B62A2;
    uint256 constant FEE_RATE = 200; // 2%
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy Implementation
        AgentTaskMarketV3 implementation = new AgentTaskMarketV3();
        console.log("Implementation deployed:", address(implementation));
        
        // 2. Prepare initialization data
        address[] memory council = new address[](1);
        council[0] = deployer;
        
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,uint256,address[])",
            CLAWNCH_TOKEN,
            FEE_RECIPIENT,
            FEE_RATE,
            council
        );
        
        // 3. Deploy Proxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            deployer,
            initData
        );
        
        console.log("Proxy deployed:", address(proxy));
        console.log("CLAWNCH Token:", CLAWNCH_TOKEN);
        console.log("Fee Rate:", FEE_RATE, "bps");
        
        vm.stopBroadcast();
    }
}
