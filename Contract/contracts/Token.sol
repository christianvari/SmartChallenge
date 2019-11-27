pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    uint private MAX_TOKEN = 100000;
    address public owner;

    modifier Owned(){
        assert(msg.sender == owner);
        _;
    }

    constructor() public{
        owner = msg.sender;
        _mint(address(this), MAX_TOKEN);
    }

    function BuyToken(address buyer, uint256 amount) public Owned{
        _transfer(address(this), buyer, amount);
    }

    function SellToken(address seller, uint256 amount) public {
        require(balanceOf(seller) >= amount, "You haven't token");
        _transfer(seller, address(this), amount);
    }

}