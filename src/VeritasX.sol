// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract VeritasX {

    struct Tweet {
        string tweetId;
        string contentHash;
        address reporter;
        uint256 reportTime;
        bool resolved;
        TweetStatus status;
        uint256 stakePool;
        mapping(address => Stake) stakes;
        address[] stakers;
    }

    enum TweetStatus {
        Pending,
        True,
        False,
        Misleading,
        Unverifiable
    }

    struct Stake {
        uint256 amount;
        TweetStatus vote;
        string justification; // Almacenado on-chain
        bool claimed;
    }

    struct TweetView {
        string tweetId;
        string contentHash;
        address reporter;
        uint256 reportTime;
        bool resolved;
        TweetStatus status;
        uint256 stakePool;
        uint256 totalStakers;
    }

    uint256 public minStakeAmount;
    uint256 public reporterRewardShare;
    uint256 public truthThreshold;
    uint256 public resolutionPeriod;

    mapping(string => Tweet) private tweets;
    string[] public activeTweets;

    uint256 public totalTweets;
    uint256 public totalResolved;

    address public admin;

    event TweetReported(string indexed tweetId, address indexed reporter, uint256 timestamp);
    event StakePlaced(string indexed tweetId, address indexed staker, TweetStatus vote, uint256 amount, string justification); // Incluye justificación
    event TweetResolved(string indexed tweetId, TweetStatus finalStatus);
    event RewardClaimed(string indexed tweetId, address indexed staker, uint256 amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "VeritasX: admin access required");
        _;
    }

    constructor() {
        admin = msg.sender;
        minStakeAmount = 0.01 ether;
        reporterRewardShare = 200;
        truthThreshold = 700;
        resolutionPeriod = 3 days;
    }

    function reportTweet(string calldata _tweetId, string calldata _contentHash) external payable {
        require(bytes(tweets[_tweetId].tweetId).length == 0, "VeritasX: already reported");
        require(msg.value >= minStakeAmount, "VeritasX: insufficient stake");

        Tweet storage newTweet = tweets[_tweetId];
        newTweet.tweetId = _tweetId;
        newTweet.contentHash = _contentHash;
        newTweet.reporter = msg.sender;
        newTweet.reportTime = block.timestamp;
        newTweet.resolved = false;
        newTweet.status = TweetStatus.Pending;
        newTweet.stakePool = msg.value;

        newTweet.stakes[msg.sender] = Stake({
            amount: msg.value,
            vote: TweetStatus.Pending,
            justification: "",
            claimed: false
        });
        newTweet.stakers.push(msg.sender);

        activeTweets.push(_tweetId);
        totalTweets++;

        emit TweetReported(_tweetId, msg.sender, block.timestamp);
    }

    function stakeAndVote(string calldata _tweetId, TweetStatus _vote, string calldata _justification) external payable {
        Tweet storage tweet = tweets[_tweetId];

        require(bytes(tweet.tweetId).length > 0, "VeritasX: tweet not found");
        require(!tweet.resolved, "VeritasX: already resolved");
        require(_vote != TweetStatus.Pending, "VeritasX: invalid vote");
        require(block.timestamp <= tweet.reportTime + resolutionPeriod, "VeritasX: period ended");
        require(msg.value >= minStakeAmount, "VeritasX: insufficient stake");

        if (tweet.stakes[msg.sender].amount > 0) {
            tweet.stakes[msg.sender].amount += msg.value;
            tweet.stakes[msg.sender].vote = _vote;
            tweet.stakes[msg.sender].justification = _justification; // Almacena justificación on-chain
        } else {
            tweet.stakes[msg.sender] = Stake({
                amount: msg.value,
                vote: _vote,
                justification: _justification, // Almacena justificación on-chain
                claimed: false
            });
            tweet.stakers.push(msg.sender);
        }

        tweet.stakePool += msg.value;

        emit StakePlaced(_tweetId, msg.sender, _vote, msg.value, _justification);

        checkForResolution(_tweetId);
    }

    function forceResolution(string calldata _tweetId) external {
        Tweet storage tweet = tweets[_tweetId];
        require(bytes(tweet.tweetId).length > 0, "VeritasX: tweet not found");
        require(!tweet.resolved, "VeritasX: already resolved");
        require(block.timestamp > tweet.reportTime + resolutionPeriod, "VeritasX: period active");
        checkForResolution(_tweetId);
        if (!tweet.resolved) {
            resolveTweet(_tweetId, TweetStatus.Unverifiable);
        }
    }

    function claimReward(string calldata _tweetId) external {
        Tweet storage tweet = tweets[_tweetId];
        require(tweet.resolved, "VeritasX: not resolved");
        require(tweet.stakes[msg.sender].amount > 0, "VeritasX: no stake found");
        require(!tweet.stakes[msg.sender].claimed, "VeritasX: already claimed");

        tweet.stakes[msg.sender].claimed = true;
        uint256 reward = calculateReward(_tweetId, msg.sender);

        if (reward > 0) {
            (bool success,) = payable(msg.sender).call{value: reward}("");
            require(success, "VeritasX: transfer failed");
            emit RewardClaimed(_tweetId, msg.sender, reward);
        }
    }

    function getTweetInfo(string calldata _tweetId) external view returns (TweetView memory) {
        Tweet storage tweet = tweets[_tweetId];
        require(bytes(tweet.tweetId).length > 0, "VeritasX: tweet not found for info");
        return TweetView({
            tweetId: tweet.tweetId,
            contentHash: tweet.contentHash,
            reporter: tweet.reporter,
            reportTime: tweet.reportTime,
            resolved: tweet.resolved,
            status: tweet.status,
            stakePool: tweet.stakePool,
            totalStakers: tweet.stakers.length
        });
    }

    function getUserStake(string calldata _tweetId, address _user) external view returns (
        uint256 amount,
        TweetStatus vote,
        string memory justification, // Devuelve justificación almacenada
        bool claimed
    ) {
        Stake storage userStake = tweets[_tweetId].stakes[_user];
        return (userStake.amount, userStake.vote, userStake.justification, userStake.claimed);
    }

    function getActiveTweets() external view returns (string[] memory) {
        uint256 activeCount = 0;
        for (uint i = 0; i < activeTweets.length; i++) {
            string memory currentId = activeTweets[i];
            if (bytes(currentId).length > 0 && tweets[currentId].reporter != address(0) && !tweets[currentId].resolved) {
                activeCount++;
            }
        }

        string[] memory result = new string[](activeCount);
        uint256 index = 0;
        for (uint i = 0; i < activeTweets.length; i++) {
             string memory currentId = activeTweets[i];
             if (bytes(currentId).length > 0 && tweets[currentId].reporter != address(0) && !tweets[currentId].resolved) {
                if (index < activeCount) {
                   result[index] = currentId;
                   index++;
                } else {
                   revert("VeritasX: activeCount mismatch");
                }
            }
        }
        return result;
    }

    function getPotentialReward(string calldata _tweetId, address _user) external view returns (uint256) {
        Tweet storage tweet = tweets[_tweetId];
        if (!tweet.resolved || tweet.stakes[_user].claimed) {
            return 0;
        }
        return calculateReward(_tweetId, _user);
    }

    function updateParams( uint256 _minStakeAmount, uint256 _reporterRewardShare, uint256 _truthThreshold, uint256 _resolutionPeriod) external onlyAdmin {
        require(_reporterRewardShare <= 500, "VeritasX: reporter share too high");
        require(_truthThreshold >= 500 && _truthThreshold <= 1000, "VeritasX: invalid threshold");
        minStakeAmount = _minStakeAmount;
        reporterRewardShare = _reporterRewardShare;
        truthThreshold = _truthThreshold;
        resolutionPeriod = _resolutionPeriod;
    }

    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "VeritasX: invalid address");
        admin = _newAdmin;
    }

    function emergencyWithdraw() external onlyAdmin {
        uint256 balance = address(this).balance;
        require(balance > 0, "VeritasX: no funds");
        (bool success,) = payable(admin).call{value: balance}("");
        require(success, "VeritasX: transfer failed");
    }

    function checkForResolution(string memory _tweetId) internal {
        Tweet storage tweet = tweets[_tweetId];
        if (tweet.resolved) return;
        uint256[5] memory voteWeight;
        uint256 totalVoteWeight = 0;
        uint256 totalVoters = 0;
        for (uint i = 0; i < tweet.stakers.length; i++) {
            address staker = tweet.stakers[i];
            Stake storage userStake = tweet.stakes[staker];
            if (userStake.vote != TweetStatus.Pending) {
                uint voteIndex = uint(userStake.vote);
                voteWeight[voteIndex] += userStake.amount;
                totalVoteWeight += userStake.amount;
                totalVoters++;
            }
        }
        if (totalVoters >= 3 && totalVoteWeight > 0) {
            uint256 maxWeight = 0;
            TweetStatus winningStatus = TweetStatus.Pending;
            for (uint i = 1; i < 5; i++) {
                if (voteWeight[i] > maxWeight) {
                    maxWeight = voteWeight[i];
                    winningStatus = TweetStatus(i);
                }
            }
            if (winningStatus != TweetStatus.Pending && (maxWeight * 1000 / totalVoteWeight >= truthThreshold)) {
                resolveTweet(_tweetId, winningStatus);
            }
        }
    }

    function resolveTweet(string memory _tweetId, TweetStatus _finalStatus) internal {
        Tweet storage tweet = tweets[_tweetId];
        tweet.resolved = true;
        tweet.status = _finalStatus;
        totalResolved++;
        emit TweetResolved(_tweetId, _finalStatus);
    }

     function calculateReward(string memory _tweetId, address _user) internal view returns (uint256) {
        Tweet storage tweet = tweets[_tweetId];
        Stake storage userStake = tweet.stakes[_user];
        uint256 reward = 0;
        uint256 reporterBaseReward = 0;

        if (!tweet.resolved || userStake.amount == 0) {
             return 0;
        }

        if (_user == tweet.reporter) {
            reporterBaseReward = tweet.stakePool * reporterRewardShare / 1000;
        }

        uint256 voterPool = tweet.stakePool > reporterBaseReward ? tweet.stakePool - reporterBaseReward : 0;

        uint256 correctVoteWeightTotal = 0;
        if (voterPool > 0) {
            for (uint i = 0; i < tweet.stakers.length; i++) {
                address staker = tweet.stakers[i];
                if (tweet.stakes[staker].vote == tweet.status) {
                     correctVoteWeightTotal += tweet.stakes[staker].amount;
                }
            }
        }

        uint256 voterReward = 0;
        if (userStake.vote == tweet.status && correctVoteWeightTotal > 0) {
             voterReward = voterPool * userStake.amount / correctVoteWeightTotal;
        } else if (userStake.vote != TweetStatus.Pending && userStake.vote != tweet.status) {
             voterReward = userStake.amount / 2;
        }
         reward = reporterBaseReward + voterReward;

        return reward;
    }
}
