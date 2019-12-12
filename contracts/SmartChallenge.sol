pragma solidity ^0.5.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SmartChallenge is ERC20 {

    struct Challenges{
        Challenge[] endedChallenges;
        Challenge[] activeChallenges;
        uint[] replaceable;
    }
    struct Challenge{
        bytes32 questionHash;
        bytes32 answerHash;
        uint16 remainingBids;
        uint timestamp;
        uint jackpot;
        bool isEnded;
    }
    struct Answer{
        bytes32 hash;
        uint bid;
        Challenge challenge;
        bool isCorrect;
    }
    struct Players{
        mapping(address=>Player) registeredPlayers;
        mapping(address=>bool) isRegistered;
    }
    struct Player{
        string username;
        uint[] createdChallenges;
        mapping(uint => bool) activeChallenges;
        mapping(uint => Answer) createdAnswers;
        uint createdAnswersNumber;
    }
    string public name = "Nigma";
    uint private MAX_TOKEN = 1000000000; //1 000 000 000
    uint32 private TEN_DAY_MS = 8640000;
    uint8 private NEW_CHALLENGE_FEE = 1;
    address public owner;
    Challenges challenges;
    Players players;

    modifier registered(){
        require(isPlayerRegistered(), "Player is not registered");
        _;
    }

    constructor() public{
        owner = msg.sender;
        _mint(address(this), MAX_TOKEN);
    }

    function finishChallenge(uint index) internal{
        challenges.activeChallenges[index].isEnded = true;
        challenges.endedChallenges.push(challenges.activeChallenges[index]);
        challenges.replaceable.push(index);
    }

    function getChallengeTuple(Challenge storage c) internal view returns (bytes32, bytes32, uint16, uint, uint, bool){
        return(c.questionHash,
            c.answerHash,
            c.remainingBids,
            c.timestamp,
            c.jackpot,
            c.isEnded);
    }

    // TODO: Use allowance after Paypal event
    function buyNigmas(address buyer, uint256 amount) public{
        assert(msg.sender == owner);
        _transfer(address(this), buyer, amount);
    }

    function sellNigmas(uint256 amount) public registered{
        require(balanceOf(msg.sender) >= amount, "You haven't token");
        require(totalSupply() >= amount, "Not enough tokens");
        _transfer(msg.sender, address(this), amount);
    }

    function isPlayerRegistered() public view returns (bool) {
        return players.isRegistered[msg.sender];
    }

    function getPlayerUsername() public registered view returns (string memory){
        return players.registeredPlayers[msg.sender].username;
    }

    function  getChallenge(bool active, uint index) public view registered returns (bytes32, bytes32, uint16, uint, uint, bool){
        assert(challenges.activeChallenges.length >= index);

        if (active)
            return getChallengeTuple(challenges.activeChallenges[index]);
        else
            return getChallengeTuple(challenges.endedChallenges[index]);
    }

    function getPlayerCreatedChallenge(uint index) public registered view returns (bytes32, bytes32, uint16, uint, uint, bool){
        require(players.registeredPlayers[msg.sender].createdChallenges.length > index, "Index out of bound");

        uint internalIndex = players.registeredPlayers[msg.sender].createdChallenges[index];

        return getChallenge(players.registeredPlayers[msg.sender].activeChallenges[index], internalIndex);

    }

    function getPlayerCreatedChallengeNumber() public registered view returns (uint){
        return players.registeredPlayers[msg.sender].createdChallenges.length;
    }

    function getPlayerCreatedAnswer(uint index) public registered view returns (bytes32, uint, bool, bytes32, bytes32, uint16, uint, uint, bool){
        require(players.registeredPlayers[msg.sender].createdAnswersNumber >= index);

        Answer storage a = players.registeredPlayers[msg.sender].createdAnswers[index];

        return(a.hash,
            a.bid,
            a.isCorrect,
            a.challenge.questionHash,
            a.challenge.answerHash,
            a.challenge.remainingBids,
            a.challenge.timestamp,
            a.challenge.jackpot,
            a.challenge.isEnded);
    }

    function getPlayerCreatedAnswerNumber() public registered view returns (uint){
        return players.registeredPlayers[msg.sender].createdAnswersNumber;
    }

    function createPlayer(string memory username) public{
        require(! isPlayerRegistered(), "Player altredy registered");
        assert(bytes(username).length <= 21);
        Player memory player;
        player.username = username;

        players.registeredPlayers[msg.sender] = player;
        players.isRegistered[msg.sender] = true;

    }

    function createChallenge(bytes32 questionHash, bytes32 answerHash, uint16 maximumBids, uint256 bid) public registered{
        require(balanceOf(msg.sender) >= bid, "You haven't enough token to place your bid.");
        _transfer(msg.sender, address(this), bid);
        Challenge memory challenge = Challenge({
            questionHash: questionHash,
            answerHash: answerHash,
            remainingBids: maximumBids,
            timestamp: block.timestamp,
            jackpot: bid,
            isEnded: false
        });

        Player storage player = players.registeredPlayers[msg.sender];

        uint index;

        if(challenges.replaceable.length > 0){
            index = challenges.replaceable[challenges.replaceable.length--];
            challenges.activeChallenges[index] = challenge;
            challenges.replaceable.pop();
        }
        else{
            challenges.activeChallenges.push(challenge);
            index = (challenges.activeChallenges.length) - 1;
        }

        uint length = player.createdChallenges.push(index);
        player.activeChallenges[length-1] = true;
    }

    function answerChallenge(bytes32 answerHash, bytes32 answerHashIPFS, uint index, uint256 bid) public registered{
        require(balanceOf(msg.sender) >= bid, "You haven't enough token to place your bid.");

        Challenge storage challenge = challenges.activeChallenges[index];

        assert(! challenge.isEnded);
        Answer memory answer = Answer({
            hash: answerHashIPFS,
            bid: bid,
            challenge: challenge,
            isCorrect: false
        });

        if(answerHash == challenge.answerHash){
            challenge.answerHash = answerHashIPFS;
            finishChallenge(index);
            answer.isCorrect = true;
            _transfer(address(this), msg.sender, challenge.jackpot);
        }
        else{
            challenge.jackpot += bid;
            _transfer(msg.sender, address(this), bid);
        }

        challenge.remainingBids -= 1;

        Player storage player = players.registeredPlayers[msg.sender];
        player.createdAnswers[player.createdAnswersNumber] = answer;
    }

    function getReward(uint index, bytes32 answerHash, bytes32 answerHashIPFS) public{

        Player storage player = players.registeredPlayers[msg.sender];
        assert(player.createdChallenges.length > index);
        require(player.activeChallenges[index], "The Challenge isn't ended yet");

        uint internalIndex = player.createdChallenges[index];
        Challenge storage challenge = challenges.endedChallenges[internalIndex];


        if(challenge.answerHash == answerHash){
            challenge.answerHash = answerHashIPFS;
            _transfer(address(this), msg.sender, challenge.jackpot);
        }
    }

}