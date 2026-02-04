// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/AgentTaskMarket.sol";

contract DeployScript is Script {
    // Base Sepolia addresses
    address constant USDC_TOKEN = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    
    function run() public {
        // Get deployment private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
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
