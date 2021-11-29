// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract T1Contract is ERC20 {
    
    uint256 _tokenPrice = 10000;
    uint256 _totalSupply = 1000000;
    address _owner;
    address _stakeContract;
    
    constructor (string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(address(this), _totalSupply * (10 ** uint256(decimals())));
        _transfer(address(this), msg.sender, _totalSupply * (10 ** uint256(decimals())) / 100);
        _owner = msg.sender;
    }
    
    function setStakeContract(address _address) public {
        require(msg.sender == _owner, "You're not owner");
        _stakeContract = _address;
    }
    
    receive() external payable {
        uint256 _amount = msg.value * _tokenPrice / 1 ether;
        _transfer(address(this), msg.sender, _amount);
    }
    
    function sell(uint256 _amount) public {
        _transfer(msg.sender, address(this), _amount);
        payable(msg.sender).transfer((_amount * 1 ether / _tokenPrice) - tx.gasprice);
    }
    
    function stake(uint256 _amount) public returns(bool result){
        _transfer(msg.sender, address(this), _amount);
        (bool callSuccess, ) = _stakeContract.call(abi.encodeWithSignature("stake(uint256,address)", _amount, address(msg.sender)));
        require(callSuccess);
        return true;  
    }
    
    function unstake(uint256 _amount, address _address) public {
        require(msg.sender == _stakeContract, "You're not stakeContract");
        _transfer(address(this), _address, _amount);
        
    }

        
}
