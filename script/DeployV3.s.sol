import { Script } from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployV3Script is Script {
    function run() external {
        address impl = 0xcc98DF0Bae08C5abC01d6255893eA863B979E93F;
        address admin = 0xC639bBbe01DCE7DC352120c315e82E49C71B62A2;
        address token = 0xa1F72459dfA10BAD200Ac160eCd78C6b77a747be;
        address feeRecipient = admin;
        uint256 feeRate = 200;
        
        vm.startBroadcast();
        address[] memory council = new address[](1);
        council[0] = admin;
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,uint256,address[])", token, feeRecipient, feeRate, council);
        new TransparentUpgradeableProxy(impl, admin, initData);
        vm.stopBroadcast();
    }
}
