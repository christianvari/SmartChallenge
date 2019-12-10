pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    uint private MAX_TOKEN = 1000000000; //1 000 000 000
    uint32 private TEN_DAY_MS = 8640000;
    address public owner;

    struct Enigma{
        bytes32 hash_enigma;
        bytes32 hash_right_answer;
        bytes32[3] hash_hints;
        uint16 bids;
        uint timestamp;
        uint jackpot;
        uint index;
        bool ended;

    }
    struct Answer{
        bytes32 hash_answer;
        address enigma_creator;
        uint enigma_index;
        bool right;
    }

    mapping(address => Enigma[]) private creators;
    mapping(address => Answer[]) private players;

    constructor() public{
        owner = msg.sender;
        _mint(address(this), MAX_TOKEN);
    }

    function BuyToken(address buyer, uint256 amount) public{
        assert(msg.sender == owner);
        _transfer(address(this), buyer, amount);
    }

    function SellToken(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "You haven't token");
        require(totalSupply() >= amount, "Not enough tokens");
        _transfer(msg.sender, address(this), amount);
    }

    function createEnigma(bytes32 hash_e, bytes32 hash_r_a, /*bytes32[3] memory hash_h,*/ uint16 m_b, uint256 bid) public{
        require(balanceOf(msg.sender) >= bid, "You haven't enough token to place your bid.");
        _transfer(msg.sender, address(this), bid);
        Enigma memory e;

        e.hash_enigma = hash_e;
        e.hash_right_answer = hash_r_a;
        //e.hash_hints = hash_h;
        e.bids = m_b;
        e.timestamp = block.timestamp;
        e.jackpot = bid;
        e.ended = false;
        creators[msg.sender].push(e);

        e.index = (creators[msg.sender].length)-1;
    }

    function answerEnigma(bytes32 hash_a, address enigma_creator, uint index, uint256 bid) public{
        require(balanceOf(msg.sender) >= bid, "You haven't enough token to place your bid.");
        Enigma memory e = creators[enigma_creator][index];
        assert(! e.ended);
        Answer memory a;

        a.hash_answer = hash_a;
        a.enigma_creator = enigma_creator;
        a.enigma_index = index;

        if(hash_a == e.hash_right_answer){
            e.ended = true;
            _transfer(address(this), msg.sender, e.jackpot);
        }
        else{
            e.jackpot += bid;
            _transfer(msg.sender, address(this), bid);
        }
        e.bids -= 1;
        players[msg.sender].push(a);
    }

    function getEnigmas() public view returns(Enigma[] memory){
        return creators[msg.sender];
    }
    function getAnswers() public view returns(Answer[] memory){
        return players[msg.sender];
    }

    function isEnded(address creator, uint index) public view returns(bool){

        Enigma memory e = creators[creator][index];

        if(! e.ended){
            if((block.timestamp + e.timestamp >= TEN_DAY_MS) || (e.bids == 0)){
                e.ended = true;
            }
        }

        return e.ended;
    }

    function getReward(uint index, bytes32 hash_answer) public{
        assert(index <= creators[msg.sender].length);
        Enigma memory e = creators[msg.sender][index];
        require(e.ended, "The Enigma isn't ended yet");

        if(e.hash_right_answer == hash_answer){
            _transfer(address(this), msg.sender, e.jackpot);
        }
    }

}