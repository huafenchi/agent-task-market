// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployProxyV2Script is Script {
    function run() external {
        address implementation = 0xF47F31118C978A264faaA929e9b68315573E179d;
        address admin = 0xC639bBbe01DCE7DC352120c315e82E49C71B62A2;
        address token = 0xa1F72459dfA10BAD200Ac160eCd78C6b77a747be;
        address feeRecipient = 0xC639bBbe01DCE7DC352120c315e82E49C71B62A2;
        uint256 feeRate = 200; // 2%
        
        vm.startBroadcast();
        
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,uint256)", 
            token, feeRecipient, feeRate
        );
        
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            implementation,
            admin,
            initData
        );
        
        vm.stopBroadcast();
    }
}
