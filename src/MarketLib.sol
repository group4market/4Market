// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library MarketLib {
    // Conversion rate: how many tokens for 1 ETH
    uint256 public constant ETH_TO_TOKEN_RATE = 1000; // 1 ETH = 1000 tokens

    // Function to calculate how many tokens a user will get for a given amount of ETH
    function getTokensForETH(uint256 ethAmount) public pure returns (uint256) {
        require(ethAmount >= 0.001 ether, "ETH amount must be at least 0.001 ETH");
        return ethAmount * ETH_TO_TOKEN_RATE;
    }

    // Function to calculate rewards based on user balance, total supply, and market balance
    function calculateReward(
        uint256 userBalance,
        uint256 totalSupply,
        uint256 marketBalance
    ) internal pure returns (uint256) {
        return (marketBalance * userBalance) / totalSupply;
    }
}
