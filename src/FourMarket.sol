// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./Market.sol";  // Import the Market contract
import "@openzeppelin/contracts/access/Ownable.sol";

contract FourMarket is Ownable {
    // State variables
    mapping(uint256 => Market) public markets; // Store markets by marketId
    uint256 public nextMarketId; // Incrementing market ID
    mapping(uint256 => mapping(address => uint256)) public userBets; // Track bets by market and user

    event MarketCreated(
        uint256 marketId,
        address marketAddress,
        string question,
        string details,
        uint256 deadline,
        uint256 resolutionTime,
        address resolver
    );

    IToken public token; // token contract instance

    constructor(address _token) Ownable(msg.sender) {
        token = IToken(_token);
        nextMarketId = 0; // Start marketId from 0
    }

    function createMarket(
        string memory _question,
        string memory _details,
        uint256 _deadline,
        uint256 _resolutionTime,
        address _resolver
    ) public onlyOwner {
        uint256 marketId = nextMarketId++;
        Market newMarket = new Market(
            marketId,
            _question,
            _details,
            _deadline,
            _resolutionTime,
            _resolver,
            address(token),  // An instance of the token contract
            address(token)   // Same token used for both Yes and No tokens
        );

        markets[marketId] = newMarket;
        emit MarketCreated(marketId, address(newMarket), _question, _details, _deadline, _resolutionTime, _resolver);
    }

    // Betting function to place a bet on a market
    function betOnMarket(uint256 marketId, Market.outcomeType _betOutcome) external payable {
        // Ensure the betAmount is greater than a threshold (e.g., 0.001 ETH = 1e15 Wei)
        require(msg.value >= 0.001 ether, "Bet amount is too low");

        // Retrieve the market instance
        Market market = markets[marketId];

        // Call the bet function on the Market contract
        market.bet(_betOutcome);

        // Mint tokens for the user based on their bet (ETH to token conversion)
        uint256 tokensToMint = MarketLib.getTokensForETH(msg.value);  // Assuming this is how you convert ETH to tokens

        if (_betOutcome == Market.outcomeType.Yes) {
            // Mint "Yes" tokens
            token.mint(msg.sender, tokensToMint);
        } else if (_betOutcome == Market.outcomeType.No) {
            // Mint "No" tokens
            token.mint(msg.sender, tokensToMint);
            }

        // Track the user's bet (store the ETH amount / minted tokens)
        userBets[marketId][msg.sender] += msg.value;

        // Emit the BetPlaced event to log the bet
        emit BetPlaced(msg.sender, msg.value, _betOutcome);
    
    }

    // Payout distribution after a market resolves
    function distributePayouts(uint256 marketId) external {
        Market market = markets[marketId];

        // Ensure the market is resolved
        require(market.s_state() == Market.MarketState.Resolved, "Market not resolved");

        Market.outcomeType winningOutcome = market.s_finalResolution();

        uint256 totalYesBets = market.totalBets(Market.outcomeType.Yes);
        uint256 totalNoBets = market.totalBets(Market.outcomeType.No);

        uint256 totalPool = totalYesBets + totalNoBets;

        // Calculate payout multiplier for winning outcome
        uint256 payoutMultiplier = (winningOutcome == Market.outcomeType.Yes)
            ? (totalPool * 1e18) / totalYesBets
            : (totalPool * 1e18) / totalNoBets;

        // Iterate over all users and distribute rewards
        for (uint256 i = 0; i < market.getUsersCount(); i++) {
            address userAddress = market.getUserByIndex(i);

            if (market.getUserOutcome(userAddress) == winningOutcome) {
                uint256 userBetAmount = userBets[marketId][userAddress];
                uint256 payoutAmount = (userBetAmount * payoutMultiplier) / 1e18;

                // Transfer payout to the user
                payable(userAddress).transfer(payoutAmount);
            }
        }
    }

        // Get all markets' details
        function getAllMarkets() external view returns (Market[] memory) {

            // Create an array to hold all the active markets
            Market[] memory activeMarkets = new Market[](nextMarketId);

            // Populate the array with all market instances
            for (uint256 i = 0; i < nextMarketId; i++) {
                activeMarkets[i] = markets[i];
                }

            // Return the array of all active markets
            return activeMarkets;
        
        }


    // Event to log the placement of a bet
    event BetPlaced(address indexed user, uint256 tokenAmount, Market.outcomeType betOutcome);
}
