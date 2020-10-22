//const EsusuAdapter = artifacts.require("EsusuAdapter");
const DaiLendingService = artifacts.require("DaiLendingService")
const DaiLendingAdapter = artifacts.require("DaiLendingAdapter")
const TreasuryContract = artifacts.require("Treasury")

module.exports = async (deployer) => {

    await deployer.deploy(DaiLendingService)

    await deployer.deploy(DaiLendingAdapter,DaiLendingService.address);

    console.log("DaiLendingService Contract address: " + DaiLendingService.address);

    console.log("DaiLendingAdapterContract address: "+DaiLendingAdapter.address )

    await deployer.deploy(TreasuryContract)

    console.log("TreasuryContract address: " + TreasuryContract.address)

}

// module.exports = async (deployer) =>{
//     const treasuryContract = 0xd9145CCE52D386f254917e481eB44e9943F39138;
//     const feeRuleKey = "njoku";
//     const serviceContract = 0xcD6a42782d230D7c13A74ddec5dD140e55499Df9;
//     // const esusuServiceContract = 0xD7ACd2a9FD159E69Bb102A1ca21C9a3e3A5F771B;
//     const savingsConfigContract = 0x358AA13c52544ECCEF6B0ADD0f801012ADAD5eE3;
//     const groupsContract = 0xddaAd340b0f1Ef65169Ae5E41A8b10776a75482d;
//     const rewardConfigContract = 0x0fC5025C764cE34df352757e82f7B5c4Df39A836;
//     const xendTokenAddress = 0xb27A31f1b0AF2946B7F582768f03239b1eC07c2c;

//     await deployer.deploy(EsusuAdapter, serviceContract, treasuryContract, savingsConfigContract, feeRuleKey, groupsContract, rewardConfigContract, xendTokenAddress)
// }
