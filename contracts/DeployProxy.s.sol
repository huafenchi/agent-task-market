// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployProxy {
    function deploy(address implementation, address admin, bytes memory data) external returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, data);
        return address(proxy);
    }
}
