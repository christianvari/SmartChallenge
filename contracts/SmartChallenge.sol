pragma solidity ^0.5.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SmartChallenge is ERC20 {

    string public name = "Nigma";
    uint private constant MAX_TOKEN = 1000000000; //1 000 000 000
    uint32 private constant DAY_MS = 86400000;
    uint8 private constant NEW_CHALLENGE_FEE = 1;
    address public owner;
    Challenges challenges;
    Players players;

    enum State {Active, Confirming, Finished, Invalid }

    struct Challenges{
        Challenge[] endedChallenges;
        Challenge[] activeChallenges;
        uint[] replaceable;
    }
    struct Challenge{
        address creator;
        uint creatorChallengeNumber;
        bytes32 questionHash;
        bytes32 answerHash;
        uint16 remainingBids;
        uint timestamp;
        uint jackpot;
        State state;
    }
    struct Answer{
        bytes32 hash;
        uint bid;
        address challengeCreator;
        uint creatorChallengeNumber;
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

    modifier registered(){
        require(isPlayerRegistered(), "Player is not registered");
        _;
    }

    constructor() public{
        owner = msg.sender;
        _mint(address(this), MAX_TOKEN);
    }

    function finishChallenge(uint index) internal{

        Challenge storage challenge = challenges.activeChallenges[index];
        uint length = challenges.endedChallenges.push(challenge);

        players.registeredPlayers[challenge.creator].createdChallenges[challenge.creatorChallengeNumber] = length - 1;
        players.registeredPlayers[challenge.creator].activeChallenges[challenge.creatorChallengeNumber] = false;
        challenges.replaceable.push(index);
    }

    function getChallengeTuple(Challenge storage c) internal view returns (address, bytes32, bytes32, uint16, uint, uint, State){
        return(c.creator,
            c.questionHash,
            c.answerHash,
            c.remainingBids,
            c.timestamp,
            c.jackpot,
            c.state);
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

    function  getChallenge(bool active, uint index) public view registered returns (address , bytes32, bytes32, uint16, uint, uint, State){
        assert(challenges.activeChallenges.length >= index);

        if (active)
            return getChallengeTuple(challenges.activeChallenges[index]);
        else
            return getChallengeTuple(challenges.endedChallenges[index]);
    }

    function getPlayerCreatedChallenge(uint index) public registered view returns (address, bytes32, bytes32, uint16, uint, uint, State){
        require(players.registeredPlayers[msg.sender].createdChallenges.length > index, "Index out of bound");

        uint internalIndex = players.registeredPlayers[msg.sender].createdChallenges[index];

        return getChallenge(players.registeredPlayers[msg.sender].activeChallenges[index], internalIndex);

    }

    function getPlayerCreatedChallengeNumber() public registered view returns (uint){
        return players.registeredPlayers[msg.sender].createdChallenges.length;
    }

    function getPlayerCreatedAnswer(uint index) public registered view returns (bytes32, uint, bool, address , uint){
        require(players.registeredPlayers[msg.sender].createdAnswersNumber >= index);

        Answer storage a = players.registeredPlayers[msg.sender].createdAnswers[index];

        return(a.hash,
            a.bid,
            a.isCorrect,
            a.challengeCreator,
            a.creatorChallengeNumber);
    }

    function getPlayerCreatedAnswersNumber() public registered view returns (uint){
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

        Player storage player = players.registeredPlayers[msg.sender];

        Challenge memory challenge = Challenge({
            creator: msg.sender,
            creatorChallengeNumber: player.createdChallenges.length,
            questionHash: questionHash,
            answerHash: answerHash,
            remainingBids: maximumBids,
            timestamp: block.timestamp,
            jackpot: bid,
            state: State.Active
        });

        uint index;

        if(challenges.replaceable.length > 0){
            index = challenges.replaceable[challenges.replaceable.length-1];
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

        require(challenge.state == State.Active, "The challenge isn't active");
        require(challenge.remainingBids > 0, "The challenge is ended");

        Answer memory answer = Answer({
            hash: answerHashIPFS,
            bid: bid,
            challengeCreator: challenge.creator,
            creatorChallengeNumber: challenge.creatorChallengeNumber,
            isCorrect: false
        });

        challenge.remainingBids -= 1;
        if(answerHash == challenge.answerHash){
            challenge.answerHash = answerHashIPFS;
            challenge.state = State.Finished;
            finishChallenge(index);
            answer.isCorrect = true;
            _transfer(address(this), msg.sender, challenge.jackpot);
        }
        else{
            challenge.jackpot += bid;
            _transfer(msg.sender, address(this), bid);
        }

        Player storage player = players.registeredPlayers[msg.sender];
        player.createdAnswers[player.createdAnswersNumber] = answer;
        player.createdAnswersNumber++;
    }

    function confirmChallenge(uint index, bytes32 answerHash, bytes32 answerHashIPFS) public{

        Player storage player = players.registeredPlayers[msg.sender];
        assert(player.createdChallenges.length > index);
        require(player.activeChallenges[index], "Challenge isn't active");

        uint internalIndex = player.createdChallenges[index];
        Challenge storage challenge = challenges.activeChallenges[internalIndex];

        require(challenge.state == State.Active, "The challenge isn't Active");

        require(block.timestamp - (DAY_MS*10) > challenge.timestamp || challenge.remainingBids == 0);

        challenge.timestamp = block.timestamp;

        if(challenge.answerHash == answerHash){
            challenge.state = State.Confirming;
            challenge.answerHash = answerHashIPFS;
            _transfer(address(this), msg.sender, challenge.jackpot);
        }
        else{
            challenge.state = State.Invalid;
        }
        finishChallenge(internalIndex);
    }

    function redeemJackpot(uint index) public {
        Player storage player = players.registeredPlayers[msg.sender];
        assert(player.createdChallenges.length > index);
        require(!player.activeChallenges[index], "Challenge is active");

        uint internalIndex = player.createdChallenges[index];
        Challenge storage challenge = challenges.endedChallenges[internalIndex];

        require(challenge.state == State.Confirming, "The challenge isn't in Confirming state");

        if(block.timestamp - (DAY_MS) > challenge.timestamp ){

            challenge.state = State.Finished;
            _transfer(address(this), msg.sender, challenge.jackpot);
        }
    }

}