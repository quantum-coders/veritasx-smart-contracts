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
        string justification;
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

    uint256 public totalTweetsReported;
    uint256 public totalTweetsResolved;

    address public admin;

    event TweetReported(bytes32 indexed tweetIdHash, address indexed reporter, uint256 timestamp, string tweetId);
    event StakePlaced(bytes32 indexed tweetIdHash, address indexed staker, TweetStatus vote, uint256 amount, string justification, string tweetId);
    event TweetResolved(bytes32 indexed tweetIdHash, TweetStatus finalStatus, string tweetId);
    event RewardClaimed(bytes32 indexed tweetIdHash, address indexed staker, uint256 amount, string tweetId);

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
        require(bytes(_tweetId).length > 0, "VeritasX: tweetId cannot be empty");
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

        totalTweetsReported++;

        bytes32 _tweetIdHash = keccak256(abi.encodePacked(_tweetId));
        emit TweetReported(_tweetIdHash, msg.sender, block.timestamp, _tweetId);
    }

    function stakeAndVote(string calldata _tweetId, TweetStatus _vote, string calldata _justification) external payable {
        require(bytes(_tweetId).length > 0, "VeritasX: tweetId cannot be empty");
        Tweet storage tweet = tweets[_tweetId];

        require(bytes(tweet.tweetId).length > 0, "VeritasX: tweet not found");
        require(!tweet.resolved, "VeritasX: already resolved");
        require(_vote != TweetStatus.Pending, "VeritasX: invalid vote");
        require(block.timestamp <= tweet.reportTime + resolutionPeriod, "VeritasX: period ended");
        require(msg.value >= minStakeAmount, "VeritasX: insufficient stake");
        require(bytes(_justification).length > 0, "VeritasX: justification required");

        if (tweet.stakes[msg.sender].amount > 0) {
            tweet.stakes[msg.sender].amount += msg.value;
            tweet.stakes[msg.sender].vote = _vote;
            tweet.stakes[msg.sender].justification = _justification;
        } else {
            tweet.stakes[msg.sender] = Stake({
                amount: msg.value,
                vote: _vote,
                justification: _justification,
                claimed: false
            });
            tweet.stakers.push(msg.sender);
        }

        tweet.stakePool += msg.value;

        bytes32 _tweetIdHash = keccak256(abi.encodePacked(_tweetId));
        emit StakePlaced(_tweetIdHash, msg.sender, _vote, msg.value, _justification, _tweetId);

        checkForResolution(_tweetId);
    }

    function forceResolution(string calldata _tweetId) external {
        require(bytes(_tweetId).length > 0, "VeritasX: tweetId cannot be empty");
        Tweet storage tweet = tweets[_tweetId];
        require(bytes(tweet.tweetId).length > 0, "VeritasX: tweet not found");
        require(!tweet.resolved, "VeritasX: already resolved");
        require(block.timestamp > tweet.reportTime + resolutionPeriod, "VeritasX: period not ended");

        checkForResolution(_tweetId);

        if (!tweet.resolved) {
             resolveTweet(_tweetId, TweetStatus.Unverifiable);
        }
    }

    function claimReward(string calldata _tweetId) external {
        require(bytes(_tweetId).length > 0, "VeritasX: tweetId cannot be empty");
        Tweet storage tweet = tweets[_tweetId];
        require(bytes(tweet.tweetId).length > 0, "VeritasX: tweet not found for claim");
        require(tweet.resolved, "VeritasX: not resolved");
        require(tweet.stakes[msg.sender].amount > 0, "VeritasX: no stake found");
        require(!tweet.stakes[msg.sender].claimed, "VeritasX: already claimed");

        uint256 reward = calculateReward(_tweetId, msg.sender);
        tweet.stakes[msg.sender].claimed = true;

        bytes32 _tweetIdHash = keccak256(abi.encodePacked(_tweetId));
        if (reward > 0) {
            (bool success,) = payable(msg.sender).call{value: reward}("");
            require(success, "VeritasX: transfer failed");
            emit RewardClaimed(_tweetIdHash, msg.sender, reward, _tweetId);
        } else {
             emit RewardClaimed(_tweetIdHash, msg.sender, 0, _tweetId);
        }
    }

    function getTweetInfo(string calldata _tweetId) external view returns (TweetView memory) {
        require(bytes(_tweetId).length > 0, "VeritasX: tweetId cannot be empty");
        Tweet storage tweet = tweets[_tweetId];
        uint256 stakerCount = 0;
        if(tweet.stakers.length > 0 || tweet.reporter != address(0)) {
             stakerCount = tweet.stakers.length;
        }

        return TweetView({
            tweetId: tweet.tweetId,
            contentHash: tweet.contentHash,
            reporter: tweet.reporter,
            reportTime: tweet.reportTime,
            resolved: tweet.resolved,
            status: tweet.status,
            stakePool: tweet.stakePool,
            totalStakers: stakerCount
        });
    }

    function getUserStake(string calldata _tweetId, address _user) external view returns (
        uint256 amount,
        TweetStatus vote,
        string memory justification,
        bool claimed
    ) {
        require(bytes(_tweetId).length > 0, "VeritasX: tweetId cannot be empty");
        require(bytes(tweets[_tweetId].tweetId).length > 0, "VeritasX: tweet not found for user stake");
        Stake storage userStake = tweets[_tweetId].stakes[_user];
        return (userStake.amount, userStake.vote, userStake.justification, userStake.claimed);
    }

    function getPotentialReward(string calldata _tweetId, address _user) external view returns (uint256) {
        require(bytes(_tweetId).length > 0, "VeritasX: tweetId cannot be empty");
        Tweet storage tweet = tweets[_tweetId];
        require(bytes(tweet.tweetId).length > 0, "VeritasX: tweet not found for reward");

        if (!tweet.resolved) {
            return 0;
        }

        Stake storage userStake = tweet.stakes[_user];

        if (userStake.amount == 0 || userStake.claimed) {
            return 0;
        }

        return calculateReward(_tweetId, _user);
    }

    function updateParams(uint256 _minStakeAmount, uint256 _reporterRewardShare, uint256 _truthThreshold, uint256 _resolutionPeriod) external onlyAdmin {
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
        if (tweet.resolved || block.timestamp <= tweet.reportTime + resolutionPeriod) {
             return;
        }

        uint256[5] memory voteWeight;
        uint256 totalVoteWeight = 0;
        uint256 totalVotersWithValidVote = 0;

        for (uint i = 0; i < tweet.stakers.length; i++) {
            address staker = tweet.stakers[i];
            require(staker != address(0), "VeritasX: Invalid staker address found");
            Stake storage userStake = tweet.stakes[staker];

            if (userStake.vote != TweetStatus.Pending) {
                 require(uint(userStake.vote) < 5, "VeritasX: Invalid vote status found");
                uint voteIndex = uint(userStake.vote);
                voteWeight[voteIndex] += userStake.amount;
                totalVoteWeight += userStake.amount;
                totalVotersWithValidVote++;
            }
        }

        if (totalVotersWithValidVote >= 3 && totalVoteWeight > 0) {
            uint256 maxWeight = 0;
            TweetStatus winningStatus = TweetStatus.Pending;

            for (uint i = 1; i < 5; i++) {
                if (voteWeight[i] > maxWeight) {
                    maxWeight = voteWeight[i];
                    winningStatus = TweetStatus(i);
                }
                 else if (voteWeight[i] == maxWeight && maxWeight > 0) {
                     winningStatus = TweetStatus.Pending;
                     break;
                 }
            }

            if (winningStatus != TweetStatus.Pending && (maxWeight * 1000 / totalVoteWeight >= truthThreshold)) {
                resolveTweet(_tweetId, winningStatus);
            }
             else if (block.timestamp > tweet.reportTime + resolutionPeriod) {
                 resolveTweet(_tweetId, TweetStatus.Unverifiable);
             }
        }
        else if (block.timestamp > tweet.reportTime + resolutionPeriod) {
             resolveTweet(_tweetId, TweetStatus.Unverifiable);
        }
    }

    function resolveTweet(string memory _tweetId, TweetStatus _finalStatus) internal {
        Tweet storage tweet = tweets[_tweetId];
        if (tweet.resolved) { return; }
        require(bytes(tweet.tweetId).length > 0, "VeritasX: Internal: trying to resolve non-existent tweet");

        tweet.resolved = true;
        tweet.status = _finalStatus;

        totalTweetsResolved++;

        bytes32 _tweetIdHash = keccak256(abi.encodePacked(_tweetId));
        emit TweetResolved(_tweetIdHash, _finalStatus, _tweetId);
    }

    function calculateReward(string memory _tweetId, address _user) internal view returns (uint256) {
        Tweet storage tweet = tweets[_tweetId];
        Stake storage userStake = tweet.stakes[_user];

        if (!tweet.resolved || userStake.amount == 0 || userStake.claimed) {
            return 0;
        }

        uint256 reporterBaseReward = 0;
        if (_user == tweet.reporter) {
             if (tweet.stakePool >= minStakeAmount) {
                 reporterBaseReward = tweet.stakePool * reporterRewardShare / 1000;
             }
        }

        uint256 voterPool = tweet.stakePool > reporterBaseReward ? tweet.stakePool - reporterBaseReward : 0;

        uint256 correctVoteWeightTotal = 0;
        if (voterPool > 0) {
            for (uint i = 0; i < tweet.stakers.length; i++) {
                address staker = tweet.stakers[i];
                require(staker != address(0), "VeritasX: Invalid staker address in reward calc");
                if (tweet.stakes[staker].vote == tweet.status) {
                    correctVoteWeightTotal += tweet.stakes[staker].amount;
                }
            }
        }

        uint256 voterRewardShare = 0;
        if (userStake.vote == tweet.status && correctVoteWeightTotal > 0) {
            voterRewardShare = voterPool * userStake.amount / correctVoteWeightTotal;
        }

        uint256 finalReward = 0;
        if (userStake.vote == tweet.status) {
            finalReward += userStake.amount;
            finalReward += voterRewardShare;
        }

        if (_user == tweet.reporter) {
             finalReward += reporterBaseReward;
        }

        return finalReward;
    }
}
