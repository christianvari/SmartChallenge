const SmartChallenge = artifacts.require("SmartChallenge");

// I use sha256 encoded in hex and withount the fixed part 0x1220
const bs58 = require("bs58");
const sha = require("sha256");
const IPFS = require("ipfs-http-client");
const ipfs = new IPFS({
    host: "ipfs.infura.io",
    port: 5001,
    protocol: "https"
});

const loadOnIPFS = async string_data => {
    let enigma_hash = await ipfs.add(string_data);
    assert.equal(
        string_data,
        await ipfs.cat(enigma_hash[0].hash),
        "not saving enigma"
    );
    const bytes = bs58.decode(enigma_hash[0].hash);
    return bytes.slice(2, bytes.length);
};

const getFromIPFS = async buffer => {
    let string = "1220" + buffer.slice(2, buffer.length);
    let ipfs_hash = bs58.encode(new Buffer(string, "hex"));
    return (await ipfs.cat(ipfs_hash)).toString();
};

const sha256 = string_data => {
    const bytes = sha(string_data, { asBytes: true });
    return bytes;
};

contract("Nigma Test", async accounts => {
    it("should be full at the beginning", async () => {
        //get the deployed contract instance
        let instance = await SmartChallenge.deployed();
        let balance = await instance.totalSupply();
        assert.equal(balance, 1000000000, "The contract generated token");
    });

    it("need registration", async () => {
        let instance = await SmartChallenge.deployed();
        try {
            await instance.buyNigmas(accounts[0], 10, { from: accounts[1] });
            assert(false);
        } catch (err) {
            assert.ok(err);
        }
    });

    it("registration", async () => {
        let instance = await SmartChallenge.deployed();

        await instance.createPlayer("Christian", { from: accounts[1] });

        assert(await instance.isPlayerRegistered({ from: accounts[1] }));
    });

    it("should be possible to buy nigmas", async () => {
        let instance = await SmartChallenge.deployed();
        let txResult = await instance.buyNigmas(accounts[1], 10, {
            from: accounts[0]
        });
        let balance = await instance.balanceOf(accounts[1]);
        assert.equal(balance.valueOf(), 10, "The balance should be 10 Token");
    });

    it("only the owner can allow buy", async () => {
        let instance = await SmartChallenge.deployed();
        try {
            await instance.buyNigmas(accounts[1], 10, { from: accounts[1] });
            assert(false);
        } catch (err) {
            assert.ok(err);
        }
    });

    it("Sell nigmas", async () => {
        let instance = await SmartChallenge.deployed();
        await instance.sellNigmas(10, { from: accounts[1] });
        balance = await instance.balanceOf(accounts[1]);
        assert.equal(balance.valueOf(), 0, "The balance should be 0 Token");
    });

    it("Buy token and sell token", async () => {
        let instance = await SmartChallenge.deployed();
        await instance.buyNigmas(accounts[1], 10, { from: accounts[0] });
        let balance = await instance.balanceOf(accounts[1]);
        assert.equal(balance.valueOf(), 10, "The balance should be 10 Token");
        await instance.sellNigmas(10, { from: accounts[1] });
        balance = await instance.balanceOf(accounts[1]);
        assert.equal(balance.valueOf(), 0, "The balance should be 0 Token");
    });
});

contract("SmartChallenge Test", async accounts => {
    it("registration", async () => {
        let instance = await SmartChallenge.deployed();

        await instance.createPlayer("Player1", { from: accounts[1] });
        await instance.createPlayer("Player2", { from: accounts[2] });

        assert(await instance.isPlayerRegistered({ from: accounts[1] }));
        assert(await instance.isPlayerRegistered({ from: accounts[2] }));
    });

    it("Create Challenge", async () => {
        let instance = await SmartChallenge.deployed();

        await instance.buyNigmas(accounts[1], 100, { from: accounts[0] });
        const tx = await instance.createChallenge(
            await loadOnIPFS("indovina indovinello"),
            sha256("risposta"),
            100,
            20,
            { from: accounts[1] }
        );

        let challenge = await instance.getPlayerCreatedChallenge(0, {
            from: accounts[1]
        });
        assert.ok(challenge);
    });

    it("Answer a question", async () => {
        let instance = await SmartChallenge.deployed();

        await instance.buyNigmas(accounts[2], 100, { from: accounts[0] });
        const tx = await instance.answerChallenge(
            sha256("risposta"),
            await loadOnIPFS("risposta"),
            0,
            50,
            { from: accounts[2] }
        );

        let challenge = await instance.getPlayerCreatedChallenge(0, {
            from: accounts[1]
        });
        //console.log(challenge);

        challenge = await instance.getChallenge(false, 0, {
            from: accounts[2]
        });
        //console.log(challenge);
        assert(challenge["5"]);
    });
});
