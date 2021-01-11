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
     *  9.  Calculate Category Factor                           -   Done
     *  10. Calculate RewardFactor For Current ThresholdLevel   -   Done
     *  11. Get Total Deposits From Existing Xend Finance Services When there is no deposit -   Done
     *  11b. Get Total Deposits From Existing Xend Finance Services When Some money has been deposited  -
     *  12. Get Current ThresholdLevel                          -   Done
     *  13. Get Current XendTokenRewardThreshold At CurrentLevel    Done
     *  14. Get RewardTimeLevel                                 -   Done
     *  15. Calculate PercentageRewardFactor                    -   Done
     */

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
    const EsusuAdapterWithdrawalDelegateContract = artifacts.require('EsusuAdapterWithdrawalDelegate');
    const EsusuStorageContract = artifacts.require('EsusuStorage');

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
    const unlockedAddress = "0xdcd024536877075bfb2ffb1db9655ae331045b4e";   //  Has lots of DAI
    
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
        let esusuAdapterWithdrawalDelegateContract = null;
        let esusuStorageContract = null;
        let rewardConfigContract = null;

        before(async () =>{

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

            //1. Create SavingsConfig rules
            await savingsConfigContract.createRule("esusufee",0,0,1000,1);

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
        it('Reward Config: Should Set reward parameters and Set RewardActive to true and log reward',async () => {
            await rewardConfigContract.SetRewardParams("100000000000000000000000000", "10000000000000000000000000", "2",
                "7", "10","15", "4","120", "4");


            var result = await rewardConfigContract.GetRewardActive();
            assert(result === false);

            await rewardConfigContract.SetRewardActive(true);
            result = await rewardConfigContract.GetRewardActive();

            var totalCycleTimeInSeconds = "2592000";            //  30 days
            var amountDeposited = "1000000000000000000000";     //  1000 Dai
            var reward = await rewardConfigContract.CalculateIndividualSavingsReward(totalCycleTimeInSeconds, amountDeposited);

            console.log(BigInt(reward).toString());

            assert(result === true);

        });

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

        it('Reward Config: Should Get RewardTimeLevel', async () => {

            //  NOTE: 2592000 seconds or 30 days is our minimum time level threshhold
            var totalCycleTime1Day = "86400";                 //  1 day
            var totalCycleTime30Days = "2592000";            //  30 days
            var totalCycleTime60Days = "5184000";            //  60 days
            var totalCycleTime90Days = "7776000";            //  90 days
            var totalCycleTime120Days = "10368000";           //  120 days
            var totalCycleTime120Days1Second = "10368001";           //  120 days and 1 second


            var result0 = BigInt(await rewardConfigContract.GetRewardTimeLevel(totalCycleTime1Day));
            var result1 = BigInt(await rewardConfigContract.GetRewardTimeLevel(totalCycleTime30Days));
            var result2 = BigInt(await rewardConfigContract.GetRewardTimeLevel(totalCycleTime60Days));
            var result3 = BigInt(await rewardConfigContract.GetRewardTimeLevel(totalCycleTime90Days));
            var result4 = BigInt(await rewardConfigContract.GetRewardTimeLevel(totalCycleTime120Days));
            var result5 = BigInt(await rewardConfigContract.GetRewardTimeLevel(totalCycleTime120Days1Second));

            console.log(`Reward Time Level For 1 Days: ${result0.toString()}`);

            console.log(`Reward Time Level For 30 Days: ${result1.toString()}`);
            console.log(`Reward Time Level For 60 Days: ${result2.toString()}`);
            console.log(`Reward Time Level For 90 Days: ${result3.toString()}`);

            console.log(`Reward Time Level For 120 Days: ${result4.toString()}`);
            console.log(`Reward Time Level For 120 Days and 1 Second : ${result5.toString()}`);

            assert(result0.toString() == "0");  //  Any number less than 30 days will result in time level of 0
            assert(result1.toString() == "1");
            assert(result2.toString() == "2");
            assert(result3.toString() == "3");
            assert(result4.toString() == "4");
            assert(result5.toString() == "4");  //  Any number greater than than 120 days will still remain at time level of 4


        });

        it('Reward Config: Should Calculate Percentage Reward Factor Per Time Level', async() => {
            var rewardTimeLevel0 = "0";                 //  Member total cycle time is less than minimum number of seconds or threshold of 30 days
            var rewardTimeLevel1 = "1";
            var rewardTimeLevel2 = "2";
            var rewardTimeLevel3 = "3";
            var rewardTimeLevel4 = "4";

            var result0 = BigInt(await rewardConfigContract.CalculatePercentageRewardFactor(rewardTimeLevel0))
            var result1 = BigInt(await rewardConfigContract.CalculatePercentageRewardFactor(rewardTimeLevel1))
            var result2 = BigInt(await rewardConfigContract.CalculatePercentageRewardFactor(rewardTimeLevel2))
            var result3 = BigInt(await rewardConfigContract.CalculatePercentageRewardFactor(rewardTimeLevel3))
            var result4 = BigInt(await rewardConfigContract.CalculatePercentageRewardFactor(rewardTimeLevel4))

            /**
             * NOTE: For example 250000000000000000 is 25%. We can't have 0.25 as BigInt or uint256 so we just leave the value as it is
             * 500000000000000000 is 50%
             * 750000000000000000 is 75%
             * 1000000000000000000 is 100%
             *  THis means that when the percentage reward is 25% the user will get the 25% of the total reward
             * */
            assert(result0.toString() === "0");
            assert(result1.toString() === "250000000000000000");
            assert(result2.toString() === "500000000000000000");
            assert(result3.toString() === "750000000000000000");
            assert(result4.toString() === "1000000000000000000");

            console.log(`Reward %age For Time Level 0: ${result0.toString()}`);
            console.log(`Reward %age For Time Level 1: ${result1.toString()}`);
            console.log(`Reward %age For Time Level 2: ${result2.toString()}`);
            console.log(`Reward %age For Time Level 3: ${result3.toString()}`);
            console.log(`Reward %age For Time Level 4: ${result4.toString()}`);

        });
        it('Reward Config: Should Get Current Threshold Level', async() => {

            var result0 = BigInt(await rewardConfigContract.GetCurrentThresholdLevel())

            //  Current threshold level will always be equal to 1 in this test since the deposit is not up to $100,000,000
            assert(result0.toString() === "1");

            console.log(`Current Threshold Level: ${result0.toString()}`);
0x9FE325bcC3C18f270888BaF33aAb719a420e4De5
        });


        /**
         *  Equation: CurrentXendTokenRewardAtCurrentLevel = XendTokenRewardAtInitialThreshold.div(DepreciationFactor ** level.sub(1));
         * =>   10,000,000 / 2^(Current level - 1) -> This is from the Litepaper
         */
        it('Reward Config: Should Get Current Xend Token Reward At Current Level', async() => {

            //  Assumptions are based on the Litepaper
            //  Current threshold level will always be equal to 1 in this test since the deposit is not up to $100,000,000
            //  Current Xend Token Reward At Current Threshold Level of 1 will always be 10,000,000 Xend Tokens

            var result0 = BigInt(await rewardConfigContract.GetCurrentThresholdLevel());

            assert(result0.toString() === "1");

            var result1 = BigInt(await rewardConfigContract.GetCurrentXendTokenRewardThresholdAtCurrentLevel())

            assert(result1.toString() === "10000000000000000000000000");

            console.log(`Current Threshold Level: ${result1.toString()}`);

        });

        it('Reward Config: Should Get Total Deposits From All Xend Finance Services', async() => {

            //  NOTE: Total Deposits will always be zero if Individual, group or Esusu operations have not occured.
            var result0 = BigInt(await rewardConfigContract.GetTotalDeposits());

            assert(result0.toString() === "0");

            console.log(`Total Deposits: ${result0.toString()}`);

        });

        /**
         * From the Litepaper
         * Reward factor for current threshold level (XTf) => Xend Token Threshold Per Level / Deposit Threshold for that level in USD
         * Using our initial values as example, Reward Factor At Current Threshold Level (XTf) = 10,000,000 XT/ $100,000,000
         * NOTE: Since we are dealing with BigInt, we will multiply 10,000,000 by 1 * 10^18 so we will not have a decimal result
         * This makes the value to be 100000000000000000 which is 0.1 in decimal at initial values of 10m XT and $100m
         */
        it('Reward Config: Should Calculate Reward Factor For Current Threshold Level', async() => {

            var result0 = BigInt(await rewardConfigContract.CalculateRewardFactorForCurrentThresholdLevel());

            assert(result0.toString() === "100000000000000000");

            console.log(`Reward Factor At Initial values: ${result0.toString()}`);

        });

        /**
         * Category Reward Factor is determined by the totalCycleTime and the Reward Factor for
         * that particular operation(eg 0.7 reward factor is for individual saving category,
         * 1.0 reward factor is for group saving category and 1.5 reward factor is for esusu category)
         *
         *
         */
        it('Reward Config: Should Calculate Category Reward Factor', async() => {

            var totalCycleTime30Days = "2592000";               //  30 days -> This means our overall category reward factor will be multiplied by 25% or 1/4
            var individualRewardFactor = "7";                   //  0.7 * 10 -> We need to take care of the decimal
            var groupRewardFactor      = "10";                  //  1.0 * 10
            var esusuRewardFactor      = "15";                  //  1.5 * 10

            //  IndividualAt25Percent -> 0.25 * 0.7 = 0.175
            var resultIndividualAt25PercentageReward = BigInt(await rewardConfigContract.CalculateCategoryFactor(totalCycleTime30Days,individualRewardFactor));

            //  GroupAt25Percent -> 0.25 * 1.0 = 0.25
            var resultGroupAt25PercentageReward = BigInt(await rewardConfigContract.CalculateCategoryFactor(totalCycleTime30Days,groupRewardFactor));

            //  EsusuAt25Percent -> 0.25 * 1.5 = 0.375
            var resultEsusuAt25PercentageReward = BigInt(await rewardConfigContract.CalculateCategoryFactor(totalCycleTime30Days,esusuRewardFactor));

            assert(resultIndividualAt25PercentageReward.toString() === "175000000000000000");
            assert(resultGroupAt25PercentageReward.toString() === "250000000000000000");
            assert(resultEsusuAt25PercentageReward.toString() === "375000000000000000");

            console.log(`Individual Reward Factor At 25%: ${resultIndividualAt25PercentageReward.toString()}`);
            console.log(`Group Reward Factor At 25%: ${resultGroupAt25PercentageReward.toString()}`);
            console.log(`Esusu Reward Factor At 25%: ${resultEsusuAt25PercentageReward.toString()}`);

        });

    });
