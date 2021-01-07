
//  1. Ensure you have done truffle compile to ensure the contract ABI has been added to the artifact
const DaiLendingAdapterContract = artifacts.require("DaiLendingAdapter");
const DaiLendingServiceContract = artifacts.require("DaiLendingService");
const GroupsContract = artifacts.require('Groups');
const TreasuryContract = artifacts.require('Treasury');
const SavingsConfigContract = artifacts.require('SavingsConfig');
const XendTokenContract = artifacts.require('XendToken');
const EsusuServiceContract = artifacts.require('EsusuService');
const RewardConfigContract = artifacts.require('RewardConfig');
const EsusuAdapterContract = artifacts.require('EsusuAdapter');
const EsusuAdapterWithdrawalDelegateContract = artifacts.require('EsusuAdapterWithdrawalDelegate');
const EsusuStorageContract = artifacts.require('EsusuStorage');

module.exports = function (deployer) {

  console.log("********************** Running Esusu Migrations *****************************");

  deployer.then(async () => {


     await deployer.deploy(GroupsContract);

     await deployer.deploy(TreasuryContract);

     await deployer.deploy(SavingsConfigContract);

     await deployer.deploy(DaiLendingServiceContract);

     await deployer.deploy(DaiLendingAdapterContract,DaiLendingServiceContract.address);

     await deployer.deploy(XendTokenContract, "Xend Token", "$XEND","18","200000000000000000000000000");

     await deployer.deploy(EsusuServiceContract);

     await deployer.deploy(RewardConfigContract,EsusuServiceContract.address, GroupsContract.address);

     await deployer.deploy(EsusuStorageContract);

    //  address payable serviceContract, address esusuStorageContract, address esusuAdapterContract,
    //                 string memory feeRuleKey, address treasuryContract, address rewardConfigContract, address xendTokenContract

     await deployer.deploy(EsusuAdapterContract,
                            EsusuServiceContract.address,
                            GroupsContract.address,
                            EsusuStorageContract.address);

      await deployer.deploy(EsusuAdapterWithdrawalDelegateContract,
                              EsusuServiceContract.address,
                              EsusuStorageContract.address,
                              EsusuAdapterContract.address,
                              "esusufee",
                              TreasuryContract.address,
                              RewardConfigContract.address,
                              XendTokenContract.address,
                              SavingsConfigContract.address);

     console.log("Groups Contract address: "+GroupsContract.address);

     console.log("Treasury Contract address: "+TreasuryContract.address);

     console.log("SavingsConfig Contract address: "+SavingsConfigContract.address);

     console.log("DaiLendingService Contract address: " + DaiLendingServiceContract.address);

     console.log("DaiLendingAdapter Contract address: "+DaiLendingAdapterContract.address );

     console.log("XendToken Contract address: "+XendTokenContract.address );

     console.log("EsusuService Contract address: "+EsusuServiceContract.address );

     console.log("EsusuStorage Contract address: "+EsusuStorageContract.address );

     console.log("EsusuAdapterWithdrawalDelegate Contract address: "+EsusuAdapterWithdrawalDelegateContract.address );

     console.log("RewardConfig Contract address: "+RewardConfigContract.address );

     console.log("EsusuAdapter Contract address: "+EsusuAdapterContract.address );

     let daiLendingAdapterContract = null;
     let daiLendingServiceContract = null;
     let savingsConfigContract = null;
     let esusuAdapterContract = null;
     let esusuServiceContract = null;
     let groupsContract = null;
     let xendTokenContract = null;
     let esusuAdapterWithdrawalDelegateContract = null;
     let esusuStorageContract = null;
     let rewardConfigContract = null;

     savingsConfigContract = await SavingsConfigContract.deployed();
     daiLendingAdapterContract = await DaiLendingAdapterContract.deployed();
     daiLendingServiceContract = await DaiLendingServiceContract.deployed();
     esusuAdapterContract = await EsusuAdapterContract.deployed();
     esusuServiceContract = await EsusuServiceContract.deployed();
     groupsContract = await GroupsContract.deployed();
     xendTokenContract = await XendTokenContract.deployed();
     esusuAdapterWithdrawalDelegateContract = await EsusuAdapterWithdrawalDelegateContract.deployed();
     esusuStorageContract = await EsusuStorageContract.deployed();
     rewardConfigContract = await RewardConfigContract.deployed();
 
  })

};
