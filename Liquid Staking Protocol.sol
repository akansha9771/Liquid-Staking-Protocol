// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title LiquidStaking
 * @dev A simplified liquid staking protocol for Ethereum
 * Users can stake ETH and receive stETH tokens that represent their staked position
 * The stETH tokens can be freely transferred, used in DeFi, etc.
 */
contract LiquidStaking {
    string public name = "Liquid Staking ETH";
    string public symbol = "stETH";
    uint8 public decimals = 18;
    
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // Protocol variables
    uint256 public totalStaked;
    uint256 public rewardRate = 500; // 5% annual rate (in basis points)
    uint256 public lastUpdateTime;
    uint256 public rewardsPerToken;
    
    // Events
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    /**
     * @notice Stakes ETH and mints stETH tokens at 1:1 ratio
     */
    function stake() external payable {
        require(msg.value > 0, "Cannot stake 0 ETH");
        
        // Update rewards before modifying user's balance
        updateRewards();
        
        // Mint stETH tokens to the user at 1:1 ratio with ETH
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        totalStaked += msg.value;
        
        emit Stake(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }
    
    /**
     * @notice Unstakes ETH by burning stETH tokens
     * @param amount The amount of stETH to unstake
     */
    function unstake(uint256 amount) external {
        require(amount > 0, "Cannot unstake 0 ETH");
        require(balanceOf[msg.sender] >= amount, "Insufficient stETH balance");
        
        // Update rewards before modifying user's balance
        updateRewards();
        
        // Burn stETH tokens from the user
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        totalStaked -= amount;
        
        // Transfer ETH back to the user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
        
        emit Unstake(msg.sender, amount);
        emit Transfer(msg.sender, address(0), amount);
    }
    
    /**
     * @notice Updates the protocol rewards based on time elapsed
     */
    function updateRewards() internal {
        if (lastUpdateTime == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }
        
        if (totalStaked == 0) {
            lastUpdateTime = block.timestamp;
            return;
        }
        
        // Calculate time elapsed since last update
        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        
        // Calculate rewards: annual_rate * time_elapsed / year_in_seconds
        uint256 rewards = (totalStaked * rewardRate * timeElapsed) / (10000 * 365 days);
        
        // Update total supply to reflect rewards (rebasing mechanism)
        if (rewards > 0) {
            totalSupply += rewards;
            
            // Update rewardsPerToken for proper distribution
            rewardsPerToken += (rewards * 1e18) / totalStaked;
        }
        
        // Update lastUpdateTime
        lastUpdateTime = block.timestamp;
    }
    
    // Standard ERC20 functions to make stETH transferable
    function transfer(address to, uint256 value) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        
        emit Transfer(from, to, value);
        return true;
    }
    
    // Function to receive ETH rewards from validators/other sources
    receive() external payable {}
}
