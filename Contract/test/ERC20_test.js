const Token = artifacts.require("Token");

contract("Token simple Test", async accounts => {



    it("should be full at the beginning", async () => {
        //get the deployed contract instance
        let instance = await Token.deployed();
        let balance = await instance.totalSupply();
        assert.equal(balance, 100000, "The contract generated token");
    });

    it("should be possible to buy tokens", async () => {
        let instance = await Token.deployed();
        let txResult = await instance.BuyToken(accounts[1], 10,{from:accounts[0]});
        let balance = await instance.balanceOf(accounts[1]);
        assert.equal(balance.valueOf(), 10, "The balance should be 10 Token");
    });

    it("only the owner can allow buy", async () => {
        let instance = await Token.deployed();
        try{
            await instance.BuyToken(accounts[1], 10,{from:accounts[1]});
            assert(false);
        }
        catch(err){
            assert.ok(err);
        }
    });

    it("Sell token", async () => {
        let instance = await Token.deployed();
        await instance.SellToken(10,{from:accounts[1]});
        balance = await instance.balanceOf(accounts[1]);
        assert.equal(balance.valueOf(), 0, "The balance should be 0 Token");
    }); 

    it("Buy token and sell token", async () => {
        let instance = await Token.deployed();
        await instance.BuyToken(accounts[1], 10,{from:accounts[0]});
        let balance = await instance.balanceOf(accounts[1]);
        assert.equal(balance.valueOf(), 10, "The balance should be 10 Token");
        await instance.SellToken(10,{from:accounts[1]});
        balance = await instance.balanceOf(accounts[1]);
        assert.equal(balance.valueOf(), 0, "The balance should be 0 Token");
    }); 
});