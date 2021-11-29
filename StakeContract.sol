// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract StakeContract is ERC20 {

    uint256 _totalSupply = 1000000;
    address _owner;
    address _t1Contract;
    address _t2Contract;
	mapping (address => uint[]) stakeholders;
    mapping (address => uint) unrealised;
    
    constructor (string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(address(this), _totalSupply * (10 ** uint256(decimals())));
        _owner = msg.sender;
    }
    
    function setT1Contract(address _address) public {
        require(msg.sender == _owner, "You're not owner");
        _t1Contract = _address;
    }
    
    function setT2Contract(address _address) public {
        require(msg.sender == _owner, "You're not owner");
        _t2Contract = _address;
    }
    
    function stake(uint256 _amount, address _address) public {
        require(msg.sender == _t1Contract, "You're not t1Contract");
		
		if (stakeholders[_address].length == 0) {
            stakeholders[_address].push(_amount); 
            stakeholders[_address].push(block.number + 1);
        }
        
        else {
            uint _oldAmount = stakeholders[_address][0];
            uint _oldBlock = stakeholders[_address][1];
            
            uint _profit = calculate_profit(_oldAmount, _oldBlock);
            unrealised[_address] += _profit;
            
            delete stakeholders[_address];
            stakeholders[_address].push(_amount + _oldAmount); 
            stakeholders[_address].push(block.number);
            
        }
		
		_transfer(address(this), _address, _amount);
        
    }
    
    function unstake(uint256 _amount) public returns(bool result){
        
        if (stakeholders[msg.sender].length == 0) {
            return false;
        }
        
        else {
            _transfer(msg.sender, address(this), _amount);
            (bool callSuccess, ) = _t1Contract.call(abi.encodeWithSignature("unstake(uint256,address)", _amount, address(msg.sender)));
            require(callSuccess);
        
            uint _oldAmount = stakeholders[msg.sender][0];
            uint _oldBlock = stakeholders[msg.sender][1];
            
            uint _profit = calculate_profit(_oldAmount, _oldBlock);
            unrealised[msg.sender] += _profit;
            
            delete stakeholders[msg.sender];
            
            return true;
        }
    }
	
	function withdraw_profit() public returns(bool result){
        
        if (unrealised[msg.sender] == 0) {
            return false;
        }
        
        else {
            uint _amount = unrealised[msg.sender];
            
            (bool callSuccess, ) = _t2Contract.call(abi.encodeWithSignature("withdraw(uint256,address)", _amount, address(msg.sender)));
            require(callSuccess);
        
            unrealised[msg.sender] = 0;
            
            return true;
           
        }
    }
	
	
	
    function check_liquidity() public view virtual returns (uint) {
        return stakeholders[msg.sender][0];
    }
    

    function unrealised_profit() public view virtual returns (uint) {
        return unrealised[msg.sender];
    }
    
    function current_profit() public view virtual returns (uint) {
        return calculate_profit(stakeholders[msg.sender][0], stakeholders[msg.sender][1]);
    }
    
    
    
    
    
    function calculate_profit(uint _amount, uint _block) internal view returns (uint) {
        return _amount * 10 * (block.number - _block);
    }
}
