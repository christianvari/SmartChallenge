const bs58 = require("bs58");
const sha = require("sha256");
const IPFS = require("ipfs-http-client");
const ipfs = new IPFS({
    host: "ipfs.infura.io",
    port: 5001,
    protocol: "https"
});

export const LoadOnIPFS = async string_data => {
    let enigma_hash = await ipfs.add(string_data);
    assert.equal(
        string_data,
        await ipfs.cat(enigma_hash[0].hash),
        "not saving enigma"
    );
    const bytes = bs58.decode(enigma_hash[0].hash);
    return bytes.slice(2, bytes.length);
};

export const GetFromIPFS = async buffer => {
    let string = "1220" + buffer.slice(2, buffer.length);
    let ipfs_hash = bs58.encode(new Buffer(string, "hex"));
    return (await ipfs.cat(ipfs_hash)).toString();
};

export const Sha256 = string_data => {
    const bytes = sha(string_data, { asBytes: true });
    return bytes;
};
