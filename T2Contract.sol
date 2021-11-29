// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract T2Contract is ERC20 {

    uint256 _totalSupply = 10000000000000000000000000;
    uint _startBlock;
    uint _tokenPrice;
    address _owner;
    address _stakeContract;

    constructor (string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(address(this), _totalSupply * (10 ** uint256(decimals())));
        _owner = msg.sender;
        _startBlock = block.number;
    }

    receive() external payable {
        //receive money for buying T2
    }

    function setStakeContract(address _address) public {
        require(msg.sender == _owner, "You're not owner");
        _stakeContract = _address;
    }

    function withdraw(uint256 _amount, address _address) public {
        require(msg.sender == _stakeContract, "You're not stakeContract");
        _transfer(address(this), _address, _amount);

    }

    function sell(uint256 _amount) public {
        _transfer(msg.sender, address(this), _amount);
        _tokenPrice = block.number - _startBlock;
        payable(msg.sender).transfer((_amount * _tokenPrice) - tx.gasprice);
    }

    function get_price() public view virtual returns (uint){
        return block.number - _startBlock;
    }

}
