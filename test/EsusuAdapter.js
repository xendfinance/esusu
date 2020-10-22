const EsusuAdapter = artifacts.require("EsusuAdapter")

let esusuAdapterContract;

contract("EsusuAdapter", (accounts) => {
    beforeEach(async () => {
        esusuAdapterContract = await EsusuAdapter.deployed();
    });

    it("Should deploy the EsusuAdapter smart contracts", async () => {
        assert(esusuAdapterContract !== "");
    })

    //it should return total deposits
    it("should get total deposits", async () => {
        const result = await esusuAdapterContract.GetTotalDeposits();

        console.log(result)
    })
})