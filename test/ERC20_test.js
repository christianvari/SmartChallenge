const Token = artifacts.require("Token");
const IPFS = require('ipfs-http-client');
const bs58 = require('bs58');
const sha = require('sha256');
const ipfs = new IPFS({ host: 'ipfs.infura.io', port: 5001, protocol: 'https' });

// I use sha256 encoded in hex and withount the fixed part 0x1220

const loadOnIPFS = async (string_data) => {
    let enigma_hash = await ipfs.add(string_data);
    assert.equal(string_data, await ipfs.cat(enigma_hash[0].hash), "not saving enigma");
    const bytes = bs58.decode(enigma_hash[0].hash);
    return bytes.slice(2, bytes.length);
};

const getFromIPFS = async (buffer) => {
    let string ='1220' + buffer.slice(2, buffer.length)
    let ipfs_hash = bs58.encode(new Buffer(string, 'hex'));
    return (await ipfs.cat(ipfs_hash)).toString();
};

const sha256 = (string_data) => {
    const bytes = sha(string_data, {asBytes:true});
    return bytes;
};

contract("Token Test", async accounts => {



    it("should be full at the beginning", async () => {
        //get the deployed contract instance
        let instance = await Token.deployed();
        let balance = await instance.totalSupply();
        assert.equal(balance, 1000000000, "The contract generated token");
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

    it("Create Enigma", async () => {

        let instance = await Token.deployed();

        await instance.BuyToken(accounts[1], 100,{from:accounts[0]});
        const tx = await instance.createEnigma(await loadOnIPFS('indovina indovinello'),
                                    sha256('risposta'),
                                    100, 20, {from:accounts[1]});
        assert.ok((await instance.getEnigmas({from:accounts[1]}))[0]);
    })

    it("Answer a question", async () => {

        let instance = await Token.deployed();

        await instance.BuyToken(accounts[0], 100,{from:accounts[0]});
        const tx = await instance.answerEnigma(sha256('risposta'),
                                                    accounts[1],
                                                    0,
                                                    1,
                                                    {from:accounts[0]});
        
        balance = await instance.balanceOf(accounts[0]);
        assert.equal(balance.valueOf(), 120);
    })
});