// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TweetFactChecker
 * @dev A smart contract for decentralized fact-checking of tweets on Twitter/X
 */
contract TweetFactChecker {
    // Structs
    struct FactCheck {
        string tweetUrl;         // Full URL of the tweet being fact-checked
        bool isTrue;             // Whether the tweet is true or false
        string justification;    // Justification for the fact-check decision
        address checker;         // Address of the person who performed the fact-check
        uint256 timestamp;       // When the fact-check was performed
        uint256 upvotes;         // Number of upvotes for this fact-check
        uint256 downvotes;       // Number of downvotes for this fact-check
    }

    // Mappings
    mapping(string => FactCheck[]) public factChecksByTweet; // Maps tweet URL to all its fact-checks
    mapping(address => FactCheck[]) public factChecksByUser; // Maps user addresses to their fact-checks

    // Events
    event FactCheckSubmitted(string tweetUrl, bool isTrue, address checker);
    event FactCheckVoted(string tweetUrl, uint256 factCheckIndex, bool isUpvote, address voter);

    /**
     * @dev Submit a new fact-check for a tweet
     * @param _tweetUrl The URL of the tweet being fact-checked
     * @param _isTrue Whether the tweet content is true or false
     * @param _justification Justification for the fact-checking decision
     */
    function submitFactCheck(
        string memory _tweetUrl,
        bool _isTrue,
        string memory _justification
    ) public {
        require(bytes(_tweetUrl).length > 0, "Tweet URL cannot be empty");
        require(bytes(_justification).length > 0, "Justification cannot be empty");

        // Create a new fact-check
        FactCheck memory newFactCheck = FactCheck({
            tweetUrl: _tweetUrl,
            isTrue: _isTrue,
            justification: _justification,
            checker: msg.sender,
            timestamp: block.timestamp,
            upvotes: 0,
            downvotes: 0
        });

        // Add to the mappings
        factChecksByTweet[_tweetUrl].push(newFactCheck);
        factChecksByUser[msg.sender].push(newFactCheck);

        // Emit event
        emit FactCheckSubmitted(_tweetUrl, _isTrue, msg.sender);
    }

    /**
     * @dev Get all fact-checks for a specific tweet
     * @param _tweetUrl The URL of the tweet
     * @return An array of fact-checks for the tweet
     */
    function getFactChecksForTweet(string memory _tweetUrl) public view returns (FactCheck[] memory) {
        return factChecksByTweet[_tweetUrl];
    }

    /**
     * @dev Get all fact-checks submitted by a specific user
     * @param _user The address of the user
     * @return An array of fact-checks submitted by the user
     */
    function getFactChecksByUser(address _user) public view returns (FactCheck[] memory) {
        return factChecksByUser[_user];
    }

    /**
     * @dev Vote on a fact-check (upvote or downvote)
     * @param _tweetUrl The URL of the tweet
     * @param _factCheckIndex The index of the fact-check in the array
     * @param _isUpvote True for upvote, false for downvote
     */
    function voteOnFactCheck(
        string memory _tweetUrl,
        uint256 _factCheckIndex,
        bool _isUpvote
    ) public {
        require(_factCheckIndex < factChecksByTweet[_tweetUrl].length, "Invalid fact-check index");

        if (_isUpvote) {
            factChecksByTweet[_tweetUrl][_factCheckIndex].upvotes += 1;
        } else {
            factChecksByTweet[_tweetUrl][_factCheckIndex].downvotes += 1;
        }

        emit FactCheckVoted(_tweetUrl, _factCheckIndex, _isUpvote, msg.sender);
    }
}
