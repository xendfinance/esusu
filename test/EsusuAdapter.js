const EsusuAdapter = artifacts.require("EsusuAdapter")

let contractInstance;

contract("EsusuAdapter", (accounts) => {
    beforeEach(async () => {
        contractInstance = await EsusuAdapter.deployed();
    });

    //it should create a group and return the id

    it("should create a group", async () => {
        const result = await contractInstance.CreateGroup("NjokuEsusuGroup", "NSU", {from : accounts[0]});

        console.log(result)
    })
})