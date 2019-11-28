pragma solidity ^0.5.0;

contract SmartChallenge {

    struct Enigma{
        bytes32 hash_enigma;
        bytes32 hash_right_answer;
        bytes32[3] hash_hints;
        uint16 max_bids;
        uint timestamp;

    }
    struct Answer{
        bytes32 hash_answer;
        Enigma e;
    }
    mapping(address => Enigma) creators;
    mapping(address => Answer) answers;

}