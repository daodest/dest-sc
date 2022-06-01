// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract RegularERC20Token is ERC20 {

    constructor (string memory name, string memory symbol) ERC20(name, symbol) {
    }

    function claim(uint allocation) public {
        _mint(msg.sender, allocation);
        _approve(msg.sender, msg.sender, allocation);
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }
    
}