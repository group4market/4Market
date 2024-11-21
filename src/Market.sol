// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./IToken.sol";
import "./MarketLib.sol";

contract Market {
    enum outcomeType {
        Neither,
        Yes,
        No
    }

    enum MarketState {
        Open,
        Resolved,
        Cancelled
    }

    // Immutable variables
    IToken public immutable i_yesToken;
    IToken public immutable i_noToken;
    uint256 public immutable i_deadline;
    uint256 public immutable i_resolutionTime;
    address public immutable i_resolver;
    address public immutable i_router;


    // State variables
    MarketState public s_state = MarketState.Open;
    uint256 public s_balance;
    string public s_question;
    string public s_details;
    uint256 public s_resolvedDate;
    outcomeType public s_finalResolution;
    uint256 public s_totalYesBets;
    uint256 public s_totalNoBets;
    address[] private users;
    mapping(address => bool) private hasBet;
    mapping(address => outcomeType) private userOutcomes;



    // Errors
    error Market__BettingClosed();
    error Market__InvalidBetOutcome();
    error Market__OnlyResolverCanResolve();
    error Market__ResolveTooEarly();
    error Market__ResolveTooLate();
    error Market__NotResolved();
    error Market__NoTokensToClaim();
    error Market__InactivityPeriodNotReached();

    // Events
    event BetPlaced(address indexed user, outcomeType betOutcome, uint256 amount);
    event MarketResolved(outcomeType finalOutcome, uint256 resolutionDate);
    event RewardsDistributed(address indexed user, uint256 reward);
    event MarketCancelled(uint256 cancellationDate);

    constructor(
        uint256 _marketId,
        string memory _question,
        string memory _details,
        uint256 _deadline,
        uint256 _resolutionTime,
        address _resolver,
        address yesTokenAddress,
        address noTokenAddress
    ) {
        _marketId = uint256(keccak256(abi.encodePacked(block.timestamp, address(this))));
        i_yesToken = IToken(yesTokenAddress);
        i_noToken = IToken(noTokenAddress);
        i_deadline = _deadline;
        i_resolutionTime = _resolutionTime;
        i_resolver = _resolver;
        i_router = msg.sender; // Assign deployer as router
        s_question = _question;
        s_details = _details;
    }

    function bet(outcomeType _betOutcome) public payable {
        require(s_state == MarketState.Open, "Market is not open for betting");
        require(block.timestamp < i_deadline, "Betting is closed");
        require(_betOutcome != outcomeType.Neither, "Invalid outcome selected");

        s_balance += msg.value;

        uint256 tokensToMint = MarketLib.getTokensForETH(msg.value);

        if (_betOutcome == outcomeType.Yes) {
            i_yesToken.mint(msg.sender, tokensToMint);
            } else if (_betOutcome == outcomeType.No) {
                i_noToken.mint(msg.sender, tokensToMint);
                }
                
        if (!hasBet[msg.sender]) {
            hasBet[msg.sender] = true;
            users.push(msg.sender);
            }

        // Record the user's bet outcome
        userOutcomes[msg.sender] = _betOutcome;

        emit BetPlaced(msg.sender, _betOutcome, msg.value);
    }



    function resolve(outcomeType _finalResolution) external {
        require(msg.sender == i_resolver, "Only resolver can resolve");
        require(block.timestamp >= i_deadline, "Resolution too early");
        require(block.timestamp <= i_deadline + i_resolutionTime, "Resolution too late");
        require(s_state == MarketState.Open, "Market already resolved");

        s_finalResolution = _finalResolution;
        s_resolvedDate = block.timestamp;
        s_state = MarketState.Resolved;

        emit MarketResolved(_finalResolution, s_resolvedDate);
    }

    function distribute() external {
        require(s_state == MarketState.Resolved, "Market not resolved");
        uint256 rewardAmount;

        if (s_finalResolution == outcomeType.Yes) {
            uint256 userBalance = i_yesToken.balanceOf(msg.sender);
            require(userBalance > 0, "No tokens to claim");

            rewardAmount = MarketLib.calculateReward(userBalance, i_yesToken.totalSupply(), s_balance);

            i_yesToken.burnFrom(msg.sender, userBalance);
        } else if (s_finalResolution == outcomeType.No) {
            uint256 userBalance = i_noToken.balanceOf(msg.sender);
            require(userBalance > 0, "No tokens to claim");

            rewardAmount = MarketLib.calculateReward(userBalance, i_noToken.totalSupply(), s_balance);

            i_noToken.burnFrom(msg.sender, userBalance);
            } else if (s_finalResolution == outcomeType.Neither) {
                uint256 yesUserBalance = i_yesToken.balanceOf(msg.sender);
                uint256 noUserBalance = i_noToken.balanceOf(msg.sender);
                require(yesUserBalance + noUserBalance > 0, "No tokens to claim");
                
                rewardAmount = MarketLib.calculateReward(
                    yesUserBalance + noUserBalance,
                    i_yesToken.totalSupply() + i_noToken.totalSupply(),
                    s_balance
                );
                
                if (yesUserBalance > 0) i_yesToken.burnFrom(msg.sender, yesUserBalance);
                if (noUserBalance > 0) i_noToken.burnFrom(msg.sender, noUserBalance);
                }
                
                s_balance -= rewardAmount;
                payable(msg.sender).transfer(rewardAmount);
                emit RewardsDistributed(msg.sender, rewardAmount);
    }

    function getUsersCount() external view returns (uint256) {
        return users.length;
    }

    function getUserByIndex(uint256 index) external view returns (address) {
        return users[index];
    }

    function getUserOutcome(address user) external view returns (outcomeType) {
        return userOutcomes[user];
    }

    function totalBets(outcomeType _outcome) external view returns (uint256) {
        if (_outcome == outcomeType.Yes) return s_totalYesBets;
        if (_outcome == outcomeType.No) return s_totalNoBets;
        return 0;
    }



    fallback() external {
        revert();
    }
}
