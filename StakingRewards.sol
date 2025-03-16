// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/Math.sol";

contract StakingRewards is Ownable {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardsToken;

    uint256 public duration;
    uint256 public finishAt;
    uint256 public updatedAt;
    uint256 public rewardRate;
    uint256 public lastRewardPerToken;

    mapping(address => uint256) public rewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balanceOf;

    uint256 public totalSupply;

    constructor(address _stakingToken, address _rewardsToken)
        Ownable(msg.sender)
    {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration is not finished");
        duration = _duration;
    }

    function setRewardsAmount(uint256 amount) external onlyOwner {
        if (block.timestamp > finishAt) {
            rewardRate = amount / duration;
        } else {
            uint256 leftOvers = rewardRate * (finishAt - block.timestamp);
            rewardRate = (leftOvers + amount) / duration;
        }

        require(rewardRate > 0);
        require(rewardRate * duration <= rewardsToken.balanceOf(address(this)));

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        stakingToken.transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender] += amount;
        totalSupply += amount;
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        stakingToken.transfer(msg.sender, amount);
    }

    function earned(address account) public view returns (uint256) {
        uint256 perToken = rewardPerToken() - rewardPerTokenPaid[account];
        return ((balanceOf[account] * perToken) / 1e18) + rewards[account];
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return lastRewardPerToken;
        }

        return
            lastRewardPerToken +
            (rewardRate * (lastApplicableTime() - updatedAt) * 1e18) /
            totalSupply;
    }

    function lastApplicableTime() public view returns (uint256) {
        return Math.min(block.timestamp, finishAt);
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        rewardsToken.transfer(msg.sender, reward);
    }

    modifier updateReward(address account) {
        lastRewardPerToken = rewardPerToken();
        updatedAt = lastApplicableTime();

        if (account != address(0)) {
            rewards[account] = earned(account);
            rewardPerTokenPaid[account] = lastRewardPerToken;
        }

        _;
    }
}
