const Web3 = require("web3");

const DaiContractABI = require("./test/abi/DaiContract.json");
const YDaiContractABI = require("./test/abi/YDaiContractABI.json");

const xendToken = require("./abi/contracts/XendToken.json");
const clientRecord = require("./abi/contracts/ClientRecord.json");
const savingsConfig = require("./abi/contracts/SavingsConfig.json");
const esusuAdapter = require("./abi/contracts/EsusuAdapter.json");
const esusuAdapterWithdrawalDelegate = require("./abi/contracts/EsusuAdapterWithdrawalDelegate.json");
const esusuService = require("./abi/contracts/EsusuService.json");
const esusuStorage = require("./abi/contracts/EsusuStorage.json");
const rewardConfig = require("./abi/contracts/RewardConfig.json");
const groups = require("./abi/contracts/Groups.json");

GroupsContractaddress = 0xb3b7bc9517503c8b45430049ea66c810bb82bf86;
TreasuryContractaddress = 0x8cab77001da4947ca0e481b54967484a6015890b;
SavingsConfigContractaddress = 0x03b0e4c161ef638c90b22a66908f305e136510fe;
DaiLendingServiceContractaddress = 0x4a7bc5f9c801262e21e0ffd8d10a67c817006dae;
DaiLendingAdapterContractaddress = 0x30ad847cff9cf07d05af8928921bb136487364b2;
XendTokenContractaddress = 0x759f1d5f2be0df8482b8a153049c6cb63ecaeb3d;
EsusuServiceContractaddress = 0x0bb527f472bd2c049d9cd33c4252dd3a452fba00;
EsusuStorageContractaddress = 0x74c3db67357221f517fbf2601d0ba032c9b73b0f;
ClientRecordContractaddress = 0xed2b9a44bd1d1b469923bf9673b2bd95a795bf3a;
EsusuAdapterWithdrawalDelegateContractaddress = 0x2719be7a288f293da2a2db28c5f19ad847ac86ad;
RewardConfigContractaddress = 0xe55033c7dcd3b3c7376b4b677c5e19b74f4d150d;
EsusuAdapterContractaddress = 0xdfeb7b7c2654f08c20b9fb700be550412c156dd9;
XendfinanceindividualContractAddress = 0xf6d3457bb28b324c37bc2bf67345f49f5d4c12c0;

const web3 = new Web3(
  "https://eth-rinkeby.alchemyapi.io/v2/IC2ZFvMD2Aj5UV-1tZWtuSicwSzqOaN5"
);
const daiContract = new web3.eth.Contract(DaiContractABI, DaiContractAddress);
const yDaiContract = new web3.eth.Contract(
  YDaiContractABI,
  yDaiContractAddress
);

const groupsContract = new web3.eth.Contract(groups, GroupsContractaddress);

const clientRecordContract = new web3.eth.Contract(clientRecord, ClientRecordContractaddress);

const run = async () => {};
