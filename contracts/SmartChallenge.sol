pragma solidity ^0.5.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SmartChallenge is ERC20 {

    struct Challenges{
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
        mapping(uint => Challenge) createdChallenges;
        uint createdChallengesNumber;
        mapping(uint => Answer) createdAnswers;
        uint createdAnswersNumber;
    }
    string public name = "Nigma";
    uint private MAX_TOKEN = 1000000000; //1 000 000 000
    uint32 private TEN_DAY_MS = 8640000;
    address public owner;
    Challenges challenges;
    Players players;

    modifier Registered(){
        require(isPlayerRegistered(), "Player is not registered");
        _;
    }

    function insertChallenge(Challenge storage c) internal{
        if(challenges.replaceable.length > 0){
            uint index = challenges.replaceable[challenges.replaceable.length--];
            challenges.activeChallenges[index] = c;
            challenges.replaceable.pop();
        }
        else{
            challenges.activeChallenges.push(c);
        }
    }

    function finishChallenge(uint index) internal{
        challenges.activeChallenges[index].isEnded = true;
        challenges.replaceable.push(index);
    }

    constructor() public{
        owner = msg.sender;
        _mint(address(this), MAX_TOKEN);
    }

    function BuyNigma(address buyer, uint256 amount) public Registered{
        assert(msg.sender == owner);
        _transfer(address(this), buyer, amount);
    }

    function SellNigma(uint256 amount) public Registered{
        require(balanceOf(msg.sender) >= amount, "You haven't token");
        require(totalSupply() >= amount, "Not enough tokens");
        _transfer(msg.sender, address(this), amount);
    }

    function isPlayerRegistered() public view returns (bool) {
        return players.isRegistered[msg.sender];
    }

    function getPlayerUsername() public Registered view returns (string memory){
        return players.registeredPlayers[msg.sender].username;
    }

    function getPlayerCreatedChallenge(uint index) public Registered view returns (bytes32, bytes32, uint16, uint, uint, bool){
        require(players.registeredPlayers[msg.sender].createdChallengesNumber >= index);

        Challenge storage c = players.registeredPlayers[msg.sender].createdChallenges[index];

        return(c.questionHash,
            c.answerHash,
            c.remainingBids,
            c.timestamp,
            c.jackpot,
            c.isEnded);
    }

    function getPlayerCreatedChallengeNumber() public Registered view returns (uint){
        return players.registeredPlayers[msg.sender].createdChallengesNumber;
    }

    function getPlayerCreatedAnswer(uint index) public Registered view returns (bytes32, uint, bool, bytes32, bytes32, uint16, uint, uint, bool){
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

    function getPlayerCreatedAnswerNumber() public Registered view returns (uint){
        return players.registeredPlayers[msg.sender].createdChallengesNumber;
    }

    function CreatePlayer(string memory username) public{
        require(! isPlayerRegistered(), "Player altredy registered");

        Player memory player;
        player.username = username;

        players.registeredPlayers[msg.sender] = player;
        players.isRegistered[msg.sender] = true;

    }

    function CreateChallenge(bytes32 questionHash, bytes32 answerHash, uint16 maximumBids, uint256 bid) public Registered{
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

        player.createdChallenges[player.createdChallengesNumber] = challenge;

        Challenge storage storedChallenge = player.createdChallenges[player.createdChallengesNumber];
        insertChallenge(storedChallenge);
    }

    function answerEnigma(bytes32 answerHash, uint index, uint256 bid) public Registered{
        require(balanceOf(msg.sender) >= bid, "You haven't enough token to place your bid.");

        Challenge storage challenge = challenges.activeChallenges[index];

        assert(! challenge.isEnded);
        Answer memory answer = Answer({
            hash: answerHash,
            bid: bid,
            challenge: challenge,
            isCorrect: false
        });

        if(answerHash == challenge.answerHash){
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

        assert(index <= player.createdChallengesNumber);

        Challenge storage challenge = player.createdChallenges[index];
        require(challenge.isEnded, "The Challenge isn't ended yet");

        if(challenge.answerHash == answerHash){
            challenge.answerHash = answerHashIPFS;
            _transfer(address(this), msg.sender, challenge.jackpot);
        }
    }

}