    /**
     *  @todo    
     *  Ensure to install web3 before running this test -> npm install web3
     *  Tests to write:
     *  1.  Set reward parameters and Set RewardActive to true  -   Done
     *  2.  Calculate the reward amount for Individual Savings  -   Done
     *  3.  Calculate the reward amount for Group Savings       -   Done
     *  4.  Calculate the reward amount for Esusu               -   Done
     *  5.  Reward Individual member with Xend Tokens           -   Done
     *  6.  Reward group member with Xend Tokens                -   Done
     *  7.  Reward Esusu member with Xend Tokens                -   Done
     *  8.  Deactivete the reward system                        -   Done
     * 
     */
    
    //  Uncomment if you want to skip this test
    // if(true){
    //     return;
    // }
    console.log("********************** Running Reward Test *****************************");
    const Web3 = require('web3');
    const { assert } = require('console');
    const web3 = new Web3("HTTP://127.0.0.1:8545");
    
    const DaiLendingAdapterContract = artifacts.require("DaiLendingAdapter");
    const DaiLendingServiceContract = artifacts.require("DaiLendingService");
    const GroupsContract = artifacts.require('Groups');
    const TreasuryContract = artifacts.require('Treasury');
    const SavingsConfigContract = artifacts.require('SavingsConfig');
    const XendTokenContract = artifacts.require('XendToken');
    const EsusuServiceContract = artifacts.require('EsusuService');
    const RewardConfigContract = artifacts.require('RewardConfig');
    const EsusuAdapterContract = artifacts.require('EsusuAdapter'); 

    /** External contracts definition for DAI and YDAI
     *  1. I have unlocked an address from Ganache-cli that contains a lot of dai
     *  2. We will use the DAI contract to enable transfer and also balance checking of the generated accounts
     *  3. We will use the YDAI contract to enable transfer and also balance checking of the generated accounts
    */
    const DaiContractABI = require("../abi/DAIContract.json");
    const YDaiContractABI = require("../abi/YDAIContractABI.json");
const { Contract } = require('web3-eth-contract');
    
    const DaiContractAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    const yDaiContractAddress = "0xC2cB1040220768554cf699b0d863A3cd4324ce32"
    const unlockedAddress = "0x1eC32Bfdbdbd40C0D3ec0fe420EBCfEEb2D56917";   //  Has lots of DAI
    
    const daiContract = new web3.eth.Contract(DaiContractABI,DaiContractAddress);
    const yDaiContract = new web3.eth.Contract(YDaiContractABI,yDaiContractAddress);
    
    
    var account1;   
    var account2;
    var account3;

    var account1Balance;
    var account2Balance;
    var account3Balance;
    
    //  Send Dai from our constant unlocked address to any recipient
    async function sendDai(amount, recipient){
    
        var amountToSend = BigInt(amount); //  1000 Dai
    
        console.log(`Sending  ${ amountToSend } x 10^-18 Dai to  ${recipient}`);
    
        await daiContract.methods.transfer(recipient,amountToSend).send({from: unlockedAddress});
    
        let recipientBalance = await daiContract.methods.balanceOf(recipient).call();
        
        console.log(`Recipient: ${recipient} DAI Balance: ${recipientBalance}`);
    
    
    }
    
    //  Approve a smart contract address or normal address to spend on behalf of the owner
    async function approveDai(spender,  owner,  amount){
    
        await daiContract.methods.approve(spender,amount).send({from: owner});
    
        console.log(`Address ${spender}  has been approved to spend ${ amount } x 10^-18 Dai by Owner:  ${owner}`);
    
    };
    
    //  Approve a smart contract address or normal address to spend on behalf of the owner
    async function approveYDai(spender,  owner,  amount){
    
        await yDaiContract.methods.approve(spender,amount).send({from: owner});
    
        console.log(`Address ${spender}  has been approved to spend ${ amount } x 10^-18 YDai by Owner:  ${owner}`);
    
    };
    

    contract('RewardConfig',() =>{

        let daiLendingAdapterContract = null;
        let daiLendingServiceContract = null;
        let savingsConfigContract = null;
        let esusuAdapterContract = null;
        let esusuServiceContract = null;
        let groupsContract = null;
        let xendTokenContract = null;
        let rewardConfigContract = null;

        before(async () =>{

            savingsConfigContract = await SavingsConfigContract.deployed();
            daiLendingAdapterContract = await DaiLendingAdapterContract.deployed();
            daiLendingServiceContract = await DaiLendingServiceContract.deployed();
            esusuAdapterContract = await EsusuAdapterContract.deployed();
            esusuServiceContract = await EsusuServiceContract.deployed();
            groupsContract = await GroupsContract.deployed();
            xendTokenContract = await XendTokenContract.deployed();
            rewardConfigContract = await RewardConfigContract.deployed();

            //1. Create SavingsConfig rules
            await savingsConfigContract.createRule("esusufee","","","1000","1");

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

            //6. Xend Token Should Grant access to the  Esusu Adapter Contract and the 3 accounts
            await xendTokenContract.grantAccess(esusuAdapterContract.address);


            console.log("6->EsusuAdapter Address Given access In Xend Token contract to transfer tokens ...");
          
            //  Get the addresses and Balances of at least 2 accounts to be used in the test
            //  Send DAI to the addresses
            web3.eth.getAccounts().then(function(accounts){
    
                account1 = accounts[0];
                account2 = accounts[1];
                account3 = accounts[2];
                
                //  Xend Token Should Grant access to the 3 accounts
                xendTokenContract.grantAccess(account1);
                xendTokenContract.grantAccess(account2);
                xendTokenContract.grantAccess(account3);
                //  send money from the unlocked dai address to accounts 1 and 2
                var amountToSend = BigInt(10000000000000000000000); //   10,000 Dai
    
                //  get the eth balance of the accounts
                web3.eth.getBalance(account1, function(err, result) {
                    if (err) {
                        console.log(err)
                    } else {
            
                        account1Balance = web3.utils.fromWei(result, "ether");
                        console.log("Account 1: "+ accounts[0] + "  Balance: " + account1Balance + " ETH");
                        sendDai(amountToSend,account1);
    
                    }
                });
        
                web3.eth.getBalance(account2, function(err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        account2Balance = web3.utils.fromWei(result, "ether");
                        console.log("Account 2: "+ accounts[1] + "  Balance: " + account2Balance + " ETH");
                        sendDai(amountToSend,account2);                              
    
                    }
                });
    
                web3.eth.getBalance(account3, function(err, result) {
                    if (err) {
                        console.log(err)
                    } else {
                        account3Balance = web3.utils.fromWei(result, "ether");
                        console.log("Account 3: "+ accounts[2] + "  Balance: " + account3Balance + " ETH");
                        sendDai(amountToSend,account3);                              
    
                    }
                });
            });
    
    
        });

        /**
         * InitialThresholdValueInUSD - $100,000,000 => 100000000000000000000000000 - This is the initial limit within which the first 10m Xend Tokens to be distributed to the users
         * XendTokenRewardAtInitialThreshold - 10,000,000 XT => 10000000000000000000000000 - This is the total number of tokens that will be distributed within the initial threshold value
         * DepreciationFactor - 2 - This is the factor by which the total token rewards reduce based on the current threshold level
         * SavingsCategoryRewardFactor;    //  Cir -> 0.7 (but we have to make it 7 to handle decimal)
         * GroupCategoryRewardFactor;     //  Cgr -> 1.0 (but we have to make it 10 to handle decimal)
         * EsusuCategoryRewardFactor;     //  Cer -> 1.5 (but we have to make it 15 to handle decimal)
         * PercentageRewardFactorPerTimeLevel   //  This determines the percentage of the reward factor paid for each time level eg 4 means 25%, 5 means 20%
         * MinimumNumberOfSeconds = 2592000;      //  This determines whether we are checking time level by days, weeks, months or years. It is 30 days(1 month) in seconds by default
         * MaximumTimeLevel;                      //  This determines how many levels can be derived based on the MinimumNumberOfSeconds that has been set
         */
        it('Reward Config: Should Set reward parameters and Set RewardActive to true',async () => {
            await rewardConfigContract.SetRewardParams("100000000000000000000000000", "10000000000000000000000000", "2", 
                "7", "10","15", "4","2592000", "4");


            var result = await rewardConfigContract.GetRewardActive();
            assert(result === false);

            await rewardConfigContract.SetRewardActive(true);
            result = await rewardConfigContract.GetRewardActive();

            assert(result === true);

        });

        /**
         *  Assumption: We are still within the first level which is $100,000,000 deposit with 10,000,000 XT in distribution 
         *  (1/4) * (0.7) * (1000) * (10,000,000 / 100,000,000)
         *  (1/4) - this means that we have a maximum reward Level of 4(i.e 4 * 30 days = 120 days) and since we set MinimumNumberOfSeconds to 30 days it means
         *  that we are using 30 days are the standard unit for measuring each time level. So the 1 in the numerator means (30 days /30 days which is 1).
         */
        it('Reward Config: Should Calculate the reward for individual savings ',async () => {

            var totalCycleTimeInSeconds = "2592000";            //  30 days
            var amountDeposited = "1000000000000000000000";     //  1000 Dai 
            var result = await rewardConfigContract.CalculateIndividualSavingsReward(totalCycleTimeInSeconds, amountDeposited);

            assert(BigInt(result).toString() === "17500000000000000000");
            console.log(BigInt(result).toString());
            
        });

        /**
         *  Assumption: We are still within the first level which is $100,000,000 deposit with 10,000,000 XT in distribution 
         *  
         *  (2/4) * (1.0) * (1000) * (10,000,000 / 100,000,000)
         */
        it('Reward Config: Should Calculate the reward for Group savings ',async () => {

            var totalCycleTimeInSeconds = "5184000";            //  60 days
            var amountDeposited = "1000000000000000000000";     //  1000 Dai 
            var result = await rewardConfigContract.CalculateCooperativeSavingsReward(totalCycleTimeInSeconds, amountDeposited);

            assert(BigInt(result).toString() === "50000000000000000000");
            
            console.log(BigInt(result).toString());
            
        });

        /**
         *  Assumption: We are still within the first level which is $100,000,000 deposit with 10,000,000 XT in distribution 
         *  
         *  (3/4) * (1.5) * (1000) * (10,000,000 / 100,000,000)
         */
        it('Reward Config: Should Calculate the reward for Esusu  ',async () => {

            var totalCycleTimeInSeconds = "7776000";            //  90 days
            var amountDeposited = "1000000000000000000000";     //  1000 Dai 
            var result = await rewardConfigContract.CalculateEsusuReward(totalCycleTimeInSeconds, amountDeposited);
            
            assert(BigInt(result).toString() === "112500000000000000000");

            console.log(BigInt(result).toString());
            
        });

        it('Reward Config: Should Calculate the reward for individual savings and Send the Xend Token Reward to the User ',async () => {

            var totalCycleTimeInSeconds = "2592000";            //  30 days
            var amountDeposited = "1000000000000000000000";     //  1000 Dai 
            var result = await rewardConfigContract.CalculateIndividualSavingsReward(totalCycleTimeInSeconds, amountDeposited);

            await xendTokenContract.mint(account1,BigInt(result).toString());
            var memberXendTokenBalance = await xendTokenContract.balanceOf(account1);

            assert(BigInt(memberXendTokenBalance).toString() === "17500000000000000000");
            console.log(`Member 1 Xend Token Balance ${BigInt(memberXendTokenBalance).toString()}`);
            
        });

        it('Reward Config: Should Calculate the reward for Group/Cooperative savings and Send the Xend Token Reward to the User ',async () => {


            var totalCycleTimeInSeconds = "5184000";            //  60 days
            var amountDeposited = "1000000000000000000000";     //  1000 Dai 
            var result = await rewardConfigContract.CalculateCooperativeSavingsReward(totalCycleTimeInSeconds, amountDeposited);

            await xendTokenContract.mint(account2,BigInt(result).toString());
            var memberXendTokenBalance = await xendTokenContract.balanceOf(account2);
            
            
            assert(BigInt(memberXendTokenBalance).toString() === "50000000000000000000");
            console.log(`Member 2 Xend Token Balance ${BigInt(memberXendTokenBalance).toString()}`);
        });

        it('Reward Config: Should Calculate the reward for Esusu and Send the Xend Token Reward to the User ',async () => {

            var totalCycleTimeInSeconds = "7776000";            //  90 days
            var amountDeposited = "1000000000000000000000";     //  1000 Dai 
            var result = await rewardConfigContract.CalculateEsusuReward(totalCycleTimeInSeconds, amountDeposited);

            await xendTokenContract.mint(account3,BigInt(result).toString());
            var memberXendTokenBalance = await xendTokenContract.balanceOf(account3);
            
            
            assert(BigInt(memberXendTokenBalance).toString() === "112500000000000000000");
            console.log(`Member 3 Xend Token Balance ${BigInt(memberXendTokenBalance).toString()}`);
            
        });

        it('Reward Config: Should Deactivate the Reward System Stop Sending Rewards ',async () => {

            await rewardConfigContract.SetRewardActive(false);
            result = await rewardConfigContract.GetRewardActive();


            var totalCycleTimeInSeconds = "7776000";            //  90 days
            var amountDeposited = "1000000000000000000000";     //  1000 Dai 
            var resultIndividual = await rewardConfigContract.CalculateIndividualSavingsReward(totalCycleTimeInSeconds, amountDeposited);
            var resultGroup = await rewardConfigContract.CalculateCooperativeSavingsReward(totalCycleTimeInSeconds, amountDeposited);
            var resultEsusu = await rewardConfigContract.CalculateEsusuReward(totalCycleTimeInSeconds, amountDeposited);

            assert(result === false);
            assert(BigInt(resultIndividual).toString() === "0");
            assert(BigInt(resultGroup).toString() === "0");
            assert(BigInt(resultEsusu).toString() === "0");
            
        }); 

    });