const Web3 = require("web3");

const xendToken = require("./abi/contracts/XendToken.json");
const clientRecord = require("./abi/contracts/ClientRecord.json");
const savingsConfig = require("./abi/contracts/SavingsConfig.json");
const esusuAdapter = require("./abi/contracts/EsusuAdapter.json");
const esusuAdapterWithdrawalDelegate = require("./abi/contracts/EsusuAdapterWithdrawalDelegate.json");
const esusuService = require("./abi/contracts/EsusuService.json");
const esusuStorage = require("./abi/contracts/EsusuStorage.json");
const rewardConfig = require("./abi/contracts/RewardConfig.json");
const groups = require("./abi/contracts/Groups.json");

const GroupsContractaddress = "0xb3b7bc9517503c8b45430049ea66c810bb82bf86";
const TreasuryContractaddress = "0x8cab77001da4947ca0e481b54967484a6015890b";
const SavingsConfigContractaddress = "0x03b0e4c161ef638c90b22a66908f305e136510fe";
const DaiLendingServiceContractaddress = "0x4a7bc5f9c801262e21e0ffd8d10a67c817006dae";
const DaiLendingAdapterContractaddress = "0x30ad847cff9cf07d05af8928921bb136487364b2";
const XendTokenContractaddress = "0x759f1d5f2be0df8482b8a153049c6cb63ecaeb3d";
const EsusuServiceContractaddress = "0x0bb527f472bd2c049d9cd33c4252dd3a452fba00";
const EsusuStorageContractaddress = "0x74c3db67357221f517fbf2601d0ba032c9b73b0f";
const ClientRecordContractaddress = "0xed2b9a44bd1d1b469923bf9673b2bd95a795bf3a";
const EsusuAdapterWithdrawalDelegateContractaddress = "0x2719be7a288f293da2a2db28c5f19ad847ac86ad";
const RewardConfigContractaddress = "0xe55033c7dcd3b3c7376b4b677c5e19b74f4d150d";
const EsusuAdapterContractaddress = "0xdfeb7b7c2654f08c20b9fb700be550412c156dd9";
const XendfinanceindividualContractAddress = "0xf6d3457bb28b324c37bc2bf67345f49f5d4c12c0";

const HDWalletProvider = require('@truffle/hdwallet-provider');

const mnemonic = "tiny film armed melody dose erosion cradle moon ivory slice stand clerk"

const provider = new HDWalletProvider(mnemonic, 'https://eth-rinkeby.alchemyapi.io/v2/IC2ZFvMD2Aj5UV-1tZWtuSicwSzqOaN5')

const web3 = new Web3(provider);

const groupsContract = new web3.eth.Contract(groups.abi, GroupsContractaddress);

const clientRecordContract = new web3.eth.Contract(clientRecord.abi, ClientRecordContractaddress);

const savingsConfigContract = new web3.eth.Contract(savingsConfig.abi, SavingsConfigContractaddress);

const xendTokenContract  = new web3.eth.Contract(xendToken.abi, XendTokenContractaddress);

const esusuServiceContract = new web3.eth.Contract(esusuService.abi, EsusuServiceContractaddress);

const esusuAdapterContract = new web3.eth.Contract(esusuAdapter.abi, EsusuAdapterContractaddress);

const esusuAdapterWithdrawalDelegateContract = new web3.eth.Contract(esusuAdapterWithdrawalDelegate.abi, EsusuAdapterWithdrawalDelegateContractaddress);

const rewardConfigContract = new web3.eth.Contract(rewardConfig.abi, RewardConfigContractaddress);

const esusuStorageContract = new web3.eth.Contract(esusuStorage.abi, EsusuStorageContractaddress)


const run = async () => {


const account = await web3.eth.getAccounts();
console.log(account)

  
 await clientRecordContract.methods.activateStorageOracle(XendfinanceindividualContractAddress).send({from : account[0]});

 await esusuAdapterContract.methods.UpdateEsusuAdapterWithdrawalDelegate(EsusuAdapterWithdrawalDelegateContractaddress).send({from: account[0]})
 console.log("7->EsusuAdapter Has Updated Esusu Adapter Withdrawal Delegate Address ...");

 await esusuAdapterWithdrawalDelegateContract.methods.UpdateDaiLendingService(DaiLendingServiceContractaddress).send({from : account[0]})
 console.log("8->Esusu Adapter Withdrawal Delegate Has Updated Dai Lending Service ...");

await esusuServiceContract.methods.UpdateAdapterWithdrawalDelegate(EsusuAdapterWithdrawalDelegateContractaddress).send({from : account[0]})
console.log("9->Esusu Service Contract Has Updated  Esusu Adapter Withdrawal Delegate Address ...");

await esusuStorageContract.methods.UpdateAdapterAndAdapterDelegateAddresses(EsusuAdapterContractaddress, EsusuAdapterWithdrawalDelegateContractaddress).send({from : account[0]});
console.log("10->Esusu Storage Contract Has Updated  Esusu Adapter and Esusu Adapter Withdrawal Delegate Address ...");

await xendTokenContract.methods.grantAccess(EsusuAdapterWithdrawalDelegateContractaddress).send({from : account[0]});
console.log("11->Xend Token Has Given access To Esusu Adapter Withdrawal Delegate to transfer tokens ...");

await rewardConfigContract.methods.SetRewardParams("100000000000000000000000000", "10000000000000000000000000", "2", "7", "10","15", "4","60", "4").send({from : account[0]});
console.log("12-> Reward config contract has set reward params")

await rewardConfigContract.methods.SetRewardActive(true).send({from : account[0]});
console.log("13-> set reward active to true")


};

run();
