
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
const XendFinanceIndividual_Yearn_V1Contract = artifacts.require(
  "XendFinanceIndividual_Yearn_V1"
);
const ClientRecordContract = artifacts.require("ClientRecord");

const YDAIContractAddress = "0xC2cB1040220768554cf699b0d863A3cd4324ce32";

const DaiContractAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F"

module.exports = function (deployer) {

  console.log("********************** Running Migrations *****************************");

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

     await deployer.deploy(ClientRecordContract);

    //  address payable serviceContract, address esusuStorageContract, address esusuAdapterContract,
    //                 string memory feeRuleKey, address treasuryContract, address rewardConfigContract, address xendTokenContract

     await deployer.deploy(EsusuAdapterContract,
                            EsusuServiceContract.address,
                            SavingsConfigContract.address,
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

                              await deployer.deploy(
                                XendFinanceIndividual_Yearn_V1Contract,
                                DaiLendingServiceContract.address,
                                DaiContractAddress,
                                ClientRecordContract.address,
                                SavingsConfigContract.address,
                                YDAIContractAddress,
                                RewardConfigContract.address,
                                XendTokenContract.address,
                                TreasuryContract.address
                              );

     console.log("Groups Contract address: "+GroupsContract.address);

     console.log("Treasury Contract address: "+TreasuryContract.address);

     console.log("SavingsConfig Contract address: "+SavingsConfigContract.address);

     console.log("DaiLendingService Contract address: " + DaiLendingServiceContract.address);

     console.log("DaiLendingAdapter Contract address: "+DaiLendingAdapterContract.address );

     console.log("XendToken Contract address: "+XendTokenContract.address );

     console.log("EsusuService Contract address: "+EsusuServiceContract.address );

     console.log("EsusuStorage Contract address: "+EsusuStorageContract.address );

     console.log("ClientRecordContract address", ClientRecordContract.address);

     console.log("EsusuAdapterWithdrawalDelegate Contract address: "+EsusuAdapterWithdrawalDelegateContract.address );

     console.log("RewardConfig Contract address: "+RewardConfigContract.address );

     console.log("EsusuAdapter Contract address: "+EsusuAdapterContract.address );

     console.log(
      "Xend finance individual",
      XendFinanceIndividual_Yearn_V1Contract.address
    );

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
     let clientRecordContract = null;
     let individualContract = null;

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
     clientRecordContract = await ClientRecordContract.deployed();
     individualContract = await XendFinanceIndividual_Yearn_V1Contract.deployed();

     // 1. Create SavingsConfig rules
     await savingsConfigContract.createRule("esusufee",0,0,1000,1);

       await savingsConfigContract.createRule("XEND_FINANCE_COMMISION_DIVISOR", 0, 0, 100, 1)

    await savingsConfigContract.createRule("XEND_FINANCE_COMMISION_DIVIDEND", 0, 0, 1, 1)

    await savingsConfigContract.createRule("PERCENTAGE_PAYOUT_TO_USERS", 0, 0, 0, 1)

    await savingsConfigContract.createRule("PERCENTAGE_AS_PENALTY", 0, 0, 1, 1);

     console.log("1->Savings Config Rule Created ...");

     //2. Update the DaiLendingadapter Address in the DaiLendingService Contract
     await daiLendingServiceContract.updateAdapter(daiLendingAdapterContract.address);
     console.log("2->DaiLendingAdapter Address Updated In DaiLendingService ...");

     //3. Update the DaiLendingService Address in the EsusuAdapter Contract
     await esusuAdapterContract.UpdateDaiLendingService(daiLendingServiceContract.address);
     console.log("3->DaiLendingService Address Updated In EsusuAdapter ...");

     //4. Update the EsusuAdapter Address in the EsusuService Contract
     await esusuServiceContract.UpdateAdapter(esusuAdapterContract.address);
     console.log("4->EsusuAdapter Address Updated In EsusuService ...");

     //5. Activate the storage oracle in Groups.sol with the Address of the EsusuApter
     await  groupsContract.activateStorageOracle(esusuAdapterContract.address);
     console.log("5->EsusuAdapter Address Updated In Groups contract ...");

     //6. Xend Token Should Grant access to the  Esusu Adapter Contract
     await xendTokenContract.grantAccess(esusuAdapterContract.address);
     console.log("6->Xend Token Has Given access To Esusu Adapter to transfer tokens ...");

     //6b. Xend Token should grant access to the individudal contract
     await xendTokenContract.grantAccess(individualContract.address);
     console.log("6b->Xend Token Has Given access To Individula contract to transfer tokens ...")

     await clientRecordContract.activateStorageOracle(individualContract.address);

     //7. Esusu Adapter should Update Esusu Adapter Withdrawal Delegate
     await esusuAdapterContract.UpdateEsusuAdapterWithdrawalDelegate(esusuAdapterWithdrawalDelegateContract.address);
     console.log("7->EsusuAdapter Has Updated Esusu Adapter Withdrawal Delegate Address ...");

     //8. Esusu Adapter Withdrawal Delegate should Update Dai Lending Service
     await esusuAdapterWithdrawalDelegateContract.UpdateDaiLendingService(daiLendingServiceContract.address);
     console.log("8->Esusu Adapter Withdrawal Delegate Has Updated Dai Lending Service ...");

     //9. Esusu Service should update esusu adapter withdrawal delegate
     await esusuServiceContract.UpdateAdapterWithdrawalDelegate(esusuAdapterWithdrawalDelegateContract.address);
     console.log("9->Esusu Service Contract Has Updated  Esusu Adapter Withdrawal Delegate Address ...");

     //10. Esusu Storage should Update Adapter and Adapter Withdrawal Delegate
     await esusuStorageContract.UpdateAdapterAndAdapterDelegateAddresses(esusuAdapterContract.address,esusuAdapterWithdrawalDelegateContract.address);
     console.log("10->Esusu Storage Contract Has Updated  Esusu Adapter and Esusu Adapter Withdrawal Delegate Address ...");

     //11. Xend Token Should Grant access to the  Esusu Adapter Withdrawal Delegate Contract
     await xendTokenContract.grantAccess(esusuAdapterWithdrawalDelegateContract.address);
     console.log("11->Xend Token Has Given access To Esusu Adapter Withdrawal Delegate to transfer tokens ...");

     //12.
     await rewardConfigContract.SetRewardParams("100000000000000000000000000", "10000000000000000000000000", "2", "7", "10","15", "4","60", "4");

     //13. 
     await rewardConfigContract.SetRewardActive(true);
  })

};
