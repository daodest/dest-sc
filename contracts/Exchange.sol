// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface ILPContract {
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
}

interface IERC20Token {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function increaseAllowance(address spender, uint addedValue) external returns (bool);
    function balanceOf(address account) external returns (uint256);
    function burnFrom(address from, uint amount) external;
}


contract Exchange is Ownable, Pausable, ReentrancyGuard {
    event Exchange(address from, uint IDSAmount, uint DESTAmount);
    event DESTTransfer(address from, address to, uint amount);
    event IDSTransfer(address from, address to, uint amount);
    event IDSBurn(address from, uint amount);

    uint decimals;
    uint startDate;
    uint startPrice;
    uint growthRate;
    
    address LPAddress;
    address IDSAddress;
    address DESTAddress;
    address feeRecipient;

    constructor (address lp, address ids, address dest, address fees) {
        startDate = block.timestamp;
        startPrice = 30;
        growthRate = 4831; // 1 + 0.004831
        decimals = 10 ** 6;
        
        LPAddress = lp;
        IDSAddress = ids;
        DESTAddress = dest;
        feeRecipient = fees;
    }


    /* Setters */

    function setFeesAddress(address wallet) external onlyOwner {
        feeRecipient = wallet;
    }


    /* Internal Functions */

    function calculateGrowth(uint rate, uint periods) internal view returns (uint) {
        uint result = decimals;

        for (uint i = 0; i < periods; i++) {
            result *= (decimals + rate);
            result /= decimals;
        }

        return result;
    }

    function transferDEST(address from, address to, uint amount) internal nonReentrant {
        bool increased = IERC20Token(DESTAddress).increaseAllowance(from, amount);
        require(increased, "Failed to increase DEST allowance.");

        bool sent = IERC20Token(DESTAddress).transferFrom(from, to, amount);
        require(sent, "Failed to send DEST.");

        emit DESTTransfer(from, to, amount);
    }

    function transferIDS(address from, address to, uint amount) internal nonReentrant {
        bool sent = IERC20Token(IDSAddress).transferFrom(from, to, amount);
        require(sent, "Failed to send IDS, check your allowance.");

        emit IDSTransfer(from, to, amount);
    }

    function burnIDS(address from, uint amount) internal nonReentrant {
        IERC20Token(IDSAddress).burnFrom(from, amount);

        emit IDSBurn(from, amount);
    }


    /* Getters */

    function idsPrice() public view returns (uint) {
        uint periods = (block.timestamp - startDate) / 60 * 60 * 24;

        return startPrice * calculateGrowth(growthRate, periods); // price in cents * decimals
    }

    function destPrice() public view returns (uint) {
        (uint DESTReserve, uint BUSDReserve, ) = ILPContract(LPAddress).getReserves();

        return DESTReserve * decimals / BUSDReserve * 100; // price in cents * decimals
    }
    
    function exchangeRate() public view returns (uint) {
        return (idsPrice() * 10 ** 3) / destPrice(); // price * 10^3
    }


    /* Business Logic */

    function exchange(uint amount) public nonReentrant whenNotPaused {
        uint rate = exchangeRate();
        uint fee = amount / 100 * 97;
        require(fee > 0, "You're trying to exchange too little of IDS.");

        amount -= fee;

        uint pay = (amount * rate) / (10 ** 3);
        require(pay > 0, "You're trying to exchange too little of IDS.");
        
        require(IERC20Token(IDSAddress).balanceOf(msg.sender) >= amount + fee, "You're exceeding your IDS balance.");
        require(IERC20Token(DESTAddress).balanceOf(address(this)) >= pay, "IDS Exchange contract has not enough DEST liquidity.");
        
        burnIDS(msg.sender, amount);
        transferIDS(msg.sender, feeRecipient, fee);

        transferDEST(address(this), msg.sender, pay);

        emit Exchange(msg.sender, amount + fee, pay);
    }


    /* Admin Functions */

    function releaseDEST(address recipient, uint amount) external onlyOwner {
        transferDEST(address(this), recipient, amount);
    }

    function releaseIDS(address recipient, uint amount) external onlyOwner {
        bool increased = IERC20Token(IDSAddress).increaseAllowance(address(this), amount);
        require(increased, "Failed to increase IDS allowance.");

        transferIDS(address(this), recipient, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}