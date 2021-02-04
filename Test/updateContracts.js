const Web3 = require('web3');

const DaiContractABI = require('./test/abi/DaiContract.json');
const YDaiContractABI = require('./test/abi/YDaiContractABI.json');

const xendToken = require('./abi/contracts/XendToken.json');
const clientRecord = require('./abi/contracts/ClientRecord.json');
const savingsConfig = require('./abi/contracts/SavingsConfig.json');
const esusuAdapter = require('./abi/contracts/EsusuAdapter.json');
const esusuAdapterWithdrawalDelegate = require('./abi/contracts/EsusuAdapterWithdrawalDelegate.json');
const esusuService = require('./abi/contracts/EsusuService.json');
const esusuStorage = require('./abi/contracts/EsusuStorage.json');
const rewardConfig = require('./abi/contracts/RewardConfig.json');
const groups = require('./abi/contracts/e')

const web3 = new Web3("HTTP://127.0.0.1:8545");
const daiContract = new web3.eth.Contract(DaiContractABI, DaiContractAddress);
const yDaiContract = new web3.eth.Contract(YDaiContractABI, yDaiContractAddress);

    const run =  async ()  => {

}