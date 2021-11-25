pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract SmartysToken777 is ERC777 {

    constructor() public ERC777("SMARTYS", "SMARTYS", new address[](0)) {
        _mint(msg.sender, msg.sender, 21000000000000 * 10 ** 18, "", "");
    }
}