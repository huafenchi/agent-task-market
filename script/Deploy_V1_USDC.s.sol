// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/AgentTaskMarket.sol";

contract DeployScript is Script {
    // Base Sepolia addresses
    address constant USDC_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    
    function run() public {
        // Get deployment private key from environment
        // Can be with or without 0x prefix
        string memory pk = vm.envString("PRIVATE_KEY");
        uint256 deployerPrivateKey;
        
        // Check if it has 0x prefix
        bytes memory pkBytes = bytes(pk);
        if (pkBytes.length >= 2 && pkBytes[0] == "0" && pkBytes[1] == "x") {
            // Remove 0x prefix and parse as hex
            bytes memory pkWithoutPrefix = new bytes(pkBytes.length - 2);
            for (uint i = 0; i < pkWithoutPrefix.length; i++) {
                pkWithoutPrefix[i] = pkBytes[i + 2];
            }
            deployerPrivateKey = uint256(bytes32(pkWithoutPrefix));
        } else {
            deployerPrivateKey = uint256(bytes32(pkBytes));
        }
        
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        console.log("USDC Token address:", USDC_TOKEN);
        console.log("");
        
        // Start broadcasting
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy contract
        AgentTaskMarket taskMarket = new AgentTaskMarket(USDC_TOKEN);
        
        vm.stopBroadcast();
        
        console.log("======================================");
        console.log("AgentTaskMarket deployed successfully!");
        console.log("======================================");
        console.log("");
        console.log("Contract Address:", address(taskMarket));
        console.log("Network: Base Sepolia Testnet");
        console.log("");
        console.log("Next steps:");
        console.log("1. Verify contract on Basescan");
        console.log("2. Fund the contract with USDC for testing");
        console.log("3. Start creating tasks!");
    }
}
