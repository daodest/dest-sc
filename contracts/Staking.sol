// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ILPContract {
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
}

interface IExchangeContract {
    function idsPrice() external returns (uint);
}

interface IERC20Token {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function increaseAllowance(address spender, uint addedValue) external returns (bool);
    function balanceOf(address account) external returns (uint256);
}

contract Staking is Ownable, Pausable, ReentrancyGuard {
    struct Staking {
        uint startDate;
        uint lastClaimDate;
        uint LPAmount;
        uint initialIDSAmount;
        uint initialBUSDAmount;
    }
    
    uint growthRate;
    uint decimal;
    uint period;

    address LPAddress;
    address IDSAddress;
    address ExchangeAddress;
    address feeRecipient;
    
    mapping(address => Staking) public stakings;
    mapping(address => address) public referrals;
    mapping(address => uint) public referralProfits;

    event Stake(address wallet, uint amount);
    event Unstake(address wallet, uint amount);
    event Restake(address wallet, uint oldAmount, uint newAmount);
    event ProfitWithdrawal(address wallet, uint amount);
    
    constructor (address lp, address ids, address exchange, address fees) {
        /* growthRate is 0.2083333% per hour */
        growthRate = 2083333;
        decimal = 10 ** 9; 
        period = 60 * 60;

        LPAddress = lp;
        IDSAddress = ids;
        ExchangeAddress = exchange;
        feeRecipient = fees;
    }


    /* Setters */

    function setFeesAddress(address wallet) external onlyOwner {
        feeRecipient = wallet;
    }


    /* Internal Functions */

    function transferIDS(address from, address to, uint amount) internal nonReentrant {
        bool sent = IERC20Token(IDSAddress).transferFrom(from, to, amount);
        require(sent, "Failed to send IDS.");
    }

    function transferLP(address from, address to, uint amount) internal nonReentrant {
        uint fee = amount / 100;
        uint payback = amount - fee;

        bool feeSent = ILPContract(LPAddress).transferFrom(from, feeRecipient, fee);
        require(feeSent, "Failed to send LP token, check your balance and allowance.");

        bool paybackSent = ILPContract(LPAddress).transferFrom(from, to, payback);
        require(paybackSent, "Failed to send LP token, check your balance and allowance.");
    }

    function LPtoIDS(uint LPTokensAmount) public returns (uint) {
        (, uint BUSDReserve, ) = ILPContract(LPAddress).getReserves();

        uint totalSupply = ILPContract(LPAddress).totalSupply();
        uint stakedBUSD = BUSDReserve * LPTokensAmount / totalSupply;
        uint price = IExchangeContract(ExchangeAddress).idsPrice() * (10 ** 10); // converting to BUSD decimals
        
        return stakedBUSD * 2 / price;
    }

    function LPtoBUSD(uint LPTokensAmount) public view returns (uint) {
        (, uint BUSDReserve, ) = ILPContract(LPAddress).getReserves();

        uint totalSupply = ILPContract(LPAddress).totalSupply();

        return ((BUSDReserve * 2) * LPTokensAmount) / totalSupply;
    }

    /* Getters */

    function calculateProfit(address wallet) public view returns (uint) {
        Staking storage stakingData = stakings[wallet];

        uint timedelta = block.timestamp - stakingData.lastClaimDate;
        uint periodsNumber = timedelta / period;

        return stakingData.initialIDSAmount * growthRate * periodsNumber / decimal;
    }

    /* Business Logic */

    function stake(uint amount, address referrer) public {
        if (referrals[msg.sender] == address(0)) {
            referrals[msg.sender] = referrer;
        }

        transferLP(msg.sender, address(this), amount);
        
        Staking storage stakingData = stakings[msg.sender];

        if (stakings[msg.sender].startDate != 0) {
            withdrawProfit();

            emit Restake(msg.sender, stakingData.LPAmount, stakingData.LPAmount + amount);
        } else {
            emit Stake(msg.sender, amount);
        }

        stakingData.startDate = block.timestamp;
        stakingData.lastClaimDate = block.timestamp;
        stakingData.LPAmount += amount;
        stakingData.initialIDSAmount = LPtoIDS(stakingData.LPAmount);
        stakingData.initialBUSDAmount = LPtoBUSD(stakingData.LPAmount);
    }

    function unstake() public {
        withdrawProfit();

        Staking storage stakingData = stakings[msg.sender];
        uint LPAmount = stakingData.LPAmount;

        delete stakings[msg.sender];

        transferLP(address(this), msg.sender, LPAmount);

        emit Unstake(msg.sender, LPAmount);
    }

    function withdrawProfit() public {
        uint profit = calculateProfit(msg.sender);

        Staking storage stakingData = stakings[msg.sender];
        stakingData.lastClaimDate = block.timestamp;

        transferIDS(address(this), msg.sender, profit);
        
        Staking storage referrerStakingData = stakings[referrals[msg.sender]];
        if (referrerStakingData.initialBUSDAmount >= 100) {
            referralProfits[referrals[msg.sender]] += profit * 3 / 100;
        }
        
        emit ProfitWithdrawal(msg.sender, profit);
    }

    function withdrawReferralProfit() public {
        uint profit = referralProfits[msg.sender];
        referralProfits[msg.sender] = 0;

        transferIDS(address(this), msg.sender, profit);

        emit ProfitWithdrawal(msg.sender, profit);
    }


    /* Admin Functions */

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