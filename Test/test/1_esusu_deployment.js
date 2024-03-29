    /**
     *  @todo    
     *  Ensure to install web3 before running this test -> npm install web3
     *  Tests to write:
     *  1.  Create Group                        -   Done  
     *  2.  Get Group By Name                   -   Done
     *  3.  Create Esusu & Get current ID       -   Done
     *  4.  Join Esusu                          -   Done
     *  5.  Get Member Cycle Info               -   Done
     *  6.  Get Esusu Cycle Info                -   Done
     *  7.  Start Esusu Cycle                   -   Done
     *  8.  Withdraw ROI From Cycle. ( Delay for sometime before this test is called)   -   Done
     *  9.  Withdraw Capital From Cycle ( Delay for sometime before this test is called ) - Done
     *  10. Create Group with account 2         -   Done
     *  11. Create Esusu with account 2         -   Done
     *  12. Join Esusu with 3 accounts          -   Done
     *  13. Start the Esusu Cycle with 3 accounts   -   Done
     *  14. Withdraw ROI for 3 accounts             -   Done
     *  15. Withraw Capital for 3 accounts          -   Done
     *  16. Test contract deprication               -   Done
     */

    // if(true){
    //     return;
    // }
    console.log("********************** Running Esusu Test *****************************");
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
    

    contract('EsusuService', () => {
        let daiLendingAdapterContract = null;
        let daiLendingServiceContract = null;
        let savingsConfigContract = null;
        let esusuAdapterContract = null;
        let esusuServiceContract = null;
        let groupsContract = null;
        let xendTokenContract = null;
        let esusuAdapterWithdrawalDelegateContract = null;
        let esusuStorageContract = null;

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
   
        var groupName = "Omega Reality";
        var groupSymbol = "Ω";
        var groupId = null;
        var depositAmount = "2000000000000000000000";   //2,000 DAI 10000000000000000000000 
        var payoutIntervalSeconds = "30";  // 2 minutes
        var startTimeInSeconds = Math.floor((Date.now() + 120)/1000); // starts 2 minutes afer current time
        var maxMembers = "2";
        var currentEsusuCycleId = null;

        //1 & 2.  Create Group and Get Group Information By name

        it('EsusuService Contract: Should Create Group and Get the Group By Name', async () => {

            await esusuServiceContract.CreateGroup(groupName, groupSymbol);

            var groupInfo = await esusuServiceContract.GetGroupInformationByName(groupName);

            console.log(`Group Id: ${BigInt(groupInfo[0])}, Name: ${groupInfo[1]}, Symbol: ${groupInfo[2]}, Owner: ${groupInfo[3]}`);

            groupId = BigInt(groupInfo[0]);
            assert(groupInfo[1] === groupName);
            assert(groupInfo[2] === groupSymbol);

        });
        
        //3  & 6.Create An Esusu Cycle, Get Current ID and Get the Esusu Cycle Information
        it('EsusuService Contract: Should Create Esusu Cycle and Get The Current Esusu Cycle', async () => {

            //  Create esusu cycle
            await esusuServiceContract.CreateEsusu(groupId.toString(),depositAmount, payoutIntervalSeconds,startTimeInSeconds.toString(),maxMembers);
            //  get current cycle ID
            currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId());

            console.log(`Current Esusu Cycle ID: ${currentEsusuCycleId}`);
            
            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());

            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);
        });

        //4 Join Esusu
        it('EsusuService Contract: Should Join The Current Esusu Cycle', async () => {
            
            //  Give allowance to the EsusuAdapter to spend DAI on behalf of account 1 and 2
            var approvedAmountToSpend = BigInt(10000000000000000000000); //   10,000 Dai
            approveDai(esusuAdapterContract.address,account1,approvedAmountToSpend);
            approveDai(esusuAdapterContract.address,account2,approvedAmountToSpend);
            
            //  Account 1 and 2 should Join esusu cycle
            await esusuServiceContract.JoinEsusu(currentEsusuCycleId.toString(), account1);
            await esusuServiceContract.JoinEsusu(currentEsusuCycleId.toString(), account2);

            //  get current cycle ID
            currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId());
            
            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());

            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());
            assert(maxMembers.toString() === BigInt(result[11]).toString());

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);
        });

        //5 Start Esusu Cycle after about (currentTimeInSeconds - startTimeInSeconds)  to ensure the start time has been reached
        it('EsusuService Contract: Should Start The Current Esusu Cycle', async () => {

            var timeoutTimeInSeconds = 0;
            var currentTimeInSeconds = Math.floor(Date.now() / 1000);
            var timeDiff = currentTimeInSeconds - startTimeInSeconds;
            
            console.log(`currentTimeInSeconds: ${currentTimeInSeconds} ; startTimeInSeconds: ${startTimeInSeconds} `);
            
            if(timeDiff < 0){
                console.log(`Time is ${timeoutTimeInSeconds} Time never reach!!!`);
                timeoutTimeInSeconds = Math.abs(timeDiff);
            }else{

                console.log(`Time is ${timeoutTimeInSeconds} Time don reach!!!`);
                //  Just add wait of 5 seconds just to have some delay before Start cycle is called even when current time is greater than start time
                timeoutTimeInSeconds += 5; 

            }

            //  if currentTimeInSeconds is less than startTimeInSeconds, it means we have to wait for (startTimeInSeconds - currentTimeInSeconds)
            function timeout(s){
                return new Promise(resolve => setTimeout(resolve,s*1000));
            }

            console.log(`Waiting for ${timeoutTimeInSeconds} seconds for cycle to start`);

            await timeout(timeoutTimeInSeconds);
            console.log(`Done Waiting for ${timeoutTimeInSeconds} seconds. Starting Cycle ...`);

            //  Start esusu cycle
            await esusuServiceContract.StartEsusuCycle(currentEsusuCycleId.toString());

            //  get current cycle ID
            currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId());
            
            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());
            var cycleState = BigInt(result[3]).toString();

            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());

            //  Cycle state must be active 
            assert(cycleState === "1");

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);   

        });

        //  Get Member Cycle Info
        it('EsusuService Contract: Should Get Member Cycle Information', async () => {

            var result = await esusuServiceContract.GetMemberCycleInfo(account1, currentEsusuCycleId.toString());

            console.log(`CycleId: ${BigInt(result[0])},MemberId: ${result[1]}, TotalAmountDepositedInCycle: ${BigInt(result[2])},
                TotalPayoutReceivedInCycle: ${BigInt(result[3])}, memberPosition: ${Number(BigInt(result[4]))}`);
            
            var memberPosition = Number(BigInt(result[4]));

            assert(memberPosition == 1);
        });

        // Withdraw ROI From Esusu Cycle
        it('EsusuService Contract: Should Withdraw ROI The Current Esusu Cycle', async () => {
            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());

            //  get the member position from the cycle information  so we can determine the approx withdrawal wait time
            var memberCyclerInfo = await esusuServiceContract.GetMemberCycleInfo(account1, currentEsusuCycleId.toString());


            //  Get DaiBalance before withdrawal
            var DaiBalanceBeforeWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account1));
            console.log(`Dai Balance Before Withdrawing Overall ROI: ${DaiBalanceBeforeWithdrawing}`);

            
            //  Get the total cycle duration and start time
            var totalCycleDurationInSeconds = Number(BigInt(result[7]));
            var cycleStartTimeInSeconds = Number(BigInt(result[9]));
            var currentTimeInSeconds = (Math.floor(Date.now() / 1000));
            var withdrawalWaitTimeInSeconds = 0;
            if(currentTimeInSeconds > (cycleStartTimeInSeconds + totalCycleDurationInSeconds)){
                withdrawalWaitTimeInSeconds += 5;  //  Just add 5 seconds delay for no reason :D
            }else{
                var payoutIntervalSeconds = Number(BigInt(result[2]));
                var memberPosition = Number(BigInt(memberCyclerInfo[4]));

                withdrawalWaitTimeInSeconds = memberPosition * payoutIntervalSeconds;
            }
            console.log(`Withdrawal Wait Time In Seconds: ${withdrawalWaitTimeInSeconds}`);

            function timeout(s){
                return new Promise(resolve => setTimeout(resolve,s*1000));
            }

            await timeout(withdrawalWaitTimeInSeconds);

            //  Withdraw overall ROI 
            await esusuServiceContract.WithdrawROIFromEsusuCycle(currentEsusuCycleId.toString());

            console.log(`YDAI Balance of Esusu Adapter Withdrawal Delegate: ${await yDaiContract.methods.balanceOf(esusuAdapterWithdrawalDelegateContract.address).call()}`);
            console.log(`DAI Balance of Esusu Adapter Withdrawal Delegate: ${await daiContract.methods.balanceOf(esusuAdapterWithdrawalDelegateContract.address).call()}`);

            console.log(`Withdrawing...`);

            var DaiBalanceAfterWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account1));
            console.log(`Dai Balance After Withdrawing Overall ROI: ${DaiBalanceAfterWithdrawing}`);

            //  get current cycle ID
            currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId());

            //  Get updated status of this cycle
            result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());
            var totalBeneficiaries = BigInt(result[10]);
            
            //  TODO: get the treasury balance and ensure dai balance is greater than 0

            assert(DaiBalanceAfterWithdrawing > DaiBalanceBeforeWithdrawing);  
            assert(totalBeneficiaries > 0);   //    Total Beneficiaries must be greater than 0   
            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());
            assert(maxMembers.toString() === BigInt(result[11]).toString());

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);                
        });

        // Withdraw Capital From Esusu Cycle
        it('EsusuService Contract: Should Withdraw Capital From The Current Esusu Cycle', async () => {
            //  NOTE: To withdraw capital, the total cycle time must have elapsed, so we must wait for the cycle time to elapse

            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());

            //  Get DaiBalance before withdrawal
            var DaiBalanceBeforeWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account1));
            console.log(`Dai Balance Before Withdrawing Capital : ${DaiBalanceBeforeWithdrawing}`);

            
            //  Get the total cycle duration and start time
            var totalCycleDurationInSeconds = Number(BigInt(result[7]));
            var cycleStartTimeInSeconds = Number(BigInt(result[9]));
            var currentTimeInSeconds = (Math.floor(Date.now() / 1000));
            var withdrawalWaitTimeInSeconds = 0;
            if(currentTimeInSeconds > (cycleStartTimeInSeconds + totalCycleDurationInSeconds)){
                withdrawalWaitTimeInSeconds += 5;  //  Just add 5 seconds delay for no reason :D
            }else{
                
                withdrawalWaitTimeInSeconds = (cycleStartTimeInSeconds + totalCycleDurationInSeconds) - currentTimeInSeconds ;
            }
            console.log(`Withdrawal Wait Time In Seconds: ${withdrawalWaitTimeInSeconds}`);

            function timeout(s){
                return new Promise(resolve => setTimeout(resolve,s*1000));
            }

            await timeout(withdrawalWaitTimeInSeconds);

            //  Withdraw capital
            await esusuServiceContract.WithdrawCapitalFromEsusuCycle(currentEsusuCycleId.toString());

            console.log(`Withdrawing...`);

            var DaiBalanceAfterWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account1));
            console.log(`Dai Balance After Withdrawing Capital: ${DaiBalanceAfterWithdrawing}`);

            //  get current cycle ID
            currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId());

            //  Get updated status of this cycle
            result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());
            var totalBeneficiaries = BigInt(result[10]);
            var TotalCapitalWithdrawn = BigInt(result[8]);


            assert(DaiBalanceAfterWithdrawing > DaiBalanceBeforeWithdrawing);  
            assert(totalBeneficiaries > 0);     //  Total Beneficiaries must be greater than 0   
            assert(TotalCapitalWithdrawn > 0);  //  Total Capital Withdrawn must be greater than 0
            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());
            assert(maxMembers.toString() === BigInt(result[11]).toString());

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);                
        });


        /**
         *  The tests below repeat core operations by using different accounts to make the function calls and 
         *  also increasing the number of members in each operation
         */

        maxMembers = "4";
        payoutIntervalSeconds = "60";  // 1 minute
        it('EsusuService Contract: Should Create Group With Account 2', async () => {

            await esusuServiceContract.CreateGroup("Jedi Master", "JM",{from: account2});

            var groupInfo = await esusuServiceContract.GetGroupInformationByName("Jedi Master");

            console.log(`Group Id: ${BigInt(groupInfo[0])}, Name: ${groupInfo[1]}, Symbol: ${groupInfo[2]}, Owner: ${groupInfo[3]}`);

            groupId = BigInt(groupInfo[0]);
            assert(groupInfo[1] === "Jedi Master");
            assert(groupInfo[2] === "JM");

        });

        it('EsusuService Contract: Should Create Esusu Cycle With Account 2', async () => {

            //  Create esusu cycle
            await esusuServiceContract.CreateEsusu(groupId.toString(),depositAmount, payoutIntervalSeconds,startTimeInSeconds.toString(),maxMembers,{from:account2});
            //  get current cycle ID
            currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId(),{from:account2});

            console.log(`Current Esusu Cycle ID: ${currentEsusuCycleId}`);
            
            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString(),{from:account2});

            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);
        });

        it('EsusuService Contract: Should Join The Current Esusu Cycle With 3 accounts', async () => {
            
            //  Give allowance to the EsusuAdapter to spend DAI on behalf of account 1, 2 & 3
            var approvedAmountToSpend = BigInt(10000000000000000000000); //   10,000 Dai
            approveDai(esusuAdapterContract.address,account1,approvedAmountToSpend);
            approveDai(esusuAdapterContract.address,account2,approvedAmountToSpend);
            approveDai(esusuAdapterContract.address,account3,approvedAmountToSpend);

            //  Account 1, 2 & 3 should Join esusu cycle
            await esusuServiceContract.JoinEsusu(currentEsusuCycleId.toString(), account1, {from: account1});
            await esusuServiceContract.JoinEsusu(currentEsusuCycleId.toString(), account2, {from: account2});
            await esusuServiceContract.JoinEsusu(currentEsusuCycleId.toString(), account3, {from: account3});

            //  get current cycle ID
            currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId());
            
            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());

            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());
            assert(maxMembers.toString() === BigInt(result[11]).toString());

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);
        });
        
        it('EsusuService Contract: Should Start The Current Esusu Cycle With 3 accounts in the Cycle', async () => {

            var timeoutTimeInSeconds = 0;
            var currentTimeInSeconds = Math.floor(Date.now() / 1000);
            var timeDiff = currentTimeInSeconds - startTimeInSeconds;
            
            console.log(`currentTimeInSeconds: ${currentTimeInSeconds} ; startTimeInSeconds: ${startTimeInSeconds} `);
            
            if(timeDiff < 0){
                console.log(`Time is ${timeoutTimeInSeconds} Time never reach!!!`);
                timeoutTimeInSeconds = Math.abs(timeDiff);
            }else{

                console.log(`Time is ${timeoutTimeInSeconds} Time don reach!!!`);
                //  Just add wait of 5 seconds just to have some delay before Start cycle is called even when current time is greater than start time
                timeoutTimeInSeconds += 5; 

            }

            //  if currentTimeInSeconds is less than startTimeInSeconds, it means we have to wait for (startTimeInSeconds - currentTimeInSeconds)
            function timeout(s){
                return new Promise(resolve => setTimeout(resolve,s*1000));
            }

            console.log(`Waiting for ${timeoutTimeInSeconds} seconds for cycle to start`);

            await timeout(timeoutTimeInSeconds);
            console.log(`Done Waiting for ${timeoutTimeInSeconds} seconds. Starting Cycle ...`);

            //  Start esusu cycle
            await esusuServiceContract.StartEsusuCycle(currentEsusuCycleId.toString(), {from : account3});

            //  get current cycle ID
            currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId());
            
            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());
            var cycleState = BigInt(result[3]).toString();

            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());

            //  Cycle state must be active 
            assert(cycleState === "1");

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);   

        });

        it('EsusuService Contract: Should Withdraw ROI For Each Of The 3 Accounts In The Current Esusu Cycle', async () => {
            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());

            //  get the member position from the cycle information  so we can determine the approx withdrawal wait time
            var member1CycleInfo = await esusuServiceContract.GetMemberCycleInfo(account1, currentEsusuCycleId.toString());
            var member2CycleInfo = await esusuServiceContract.GetMemberCycleInfo(account2, currentEsusuCycleId.toString());
            var member3CycleInfo = await esusuServiceContract.GetMemberCycleInfo(account3, currentEsusuCycleId.toString());

            //  Get DaiBalance before withdrawal
            var member1DaiBalanceBeforeWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account1));
            var member2DaiBalanceBeforeWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account2));
            var member3DaiBalanceBeforeWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account3));

            console.log(`Member 1 Dai Balance Before Withdrawing Overall ROI: ${member1DaiBalanceBeforeWithdrawing}`);
            console.log(`Member 2 Dai Balance Before Withdrawing Overall ROI: ${member2DaiBalanceBeforeWithdrawing}`);
            console.log(`Member 3 Dai Balance Before Withdrawing Overall ROI: ${member3DaiBalanceBeforeWithdrawing}`);

            
            //  Get the total cycle duration and start time
            var totalCycleDurationInSeconds = Number(BigInt(result[7]));
            var cycleStartTimeInSeconds = Number(BigInt(result[9]));
            var currentTimeInSeconds = (Math.floor(Date.now() / 1000));

            var member1WithdrawalWaitTimeInSeconds = 0;
            var member2WithdrawalWaitTimeInSeconds = 0;
            var member3WithdrawalWaitTimeInSeconds = 0;

            if(currentTimeInSeconds > (cycleStartTimeInSeconds + totalCycleDurationInSeconds)){
                member1WithdrawalWaitTimeInSeconds += 5;  //  Just add 5 seconds delay for no reason :D
                member2WithdrawalWaitTimeInSeconds += 5;
                member3WithdrawalWaitTimeInSeconds += 5;

            }else{
                var payoutIntervalSeconds = Number(BigInt(result[2]));
                var member1Position = Number(BigInt(member1CycleInfo[4]));
                var member2Position = Number(BigInt(member2CycleInfo[4]));
                var member3Position = Number(BigInt(member3CycleInfo[4]));

                member1WithdrawalWaitTimeInSeconds = member1Position * payoutIntervalSeconds;
                member2WithdrawalWaitTimeInSeconds = member2Position * payoutIntervalSeconds;
                member3WithdrawalWaitTimeInSeconds = member3Position * payoutIntervalSeconds;

            }
            console.log(`Member 1 Withdrawal Wait Time In Seconds: ${member1WithdrawalWaitTimeInSeconds}`);
            console.log(`Member 2 Withdrawal Wait Time In Seconds: ${member2WithdrawalWaitTimeInSeconds}`);
            console.log(`Member 3 Withdrawal Wait Time In Seconds: ${member3WithdrawalWaitTimeInSeconds}`);

            function timeout(s){
                return new Promise(resolve => setTimeout(resolve,s*1000));
            }

            //  Withdraw overall ROI For Member 1
            await timeout(payoutIntervalSeconds + 10);
            await esusuServiceContract.WithdrawROIFromEsusuCycle(currentEsusuCycleId.toString(), {from: account1});
            console.log(`Member 1 ROI withdrawal complete ...`);

            //  Withdraw overall ROI For Member 2
            await timeout(payoutIntervalSeconds + 10);
            await esusuServiceContract.WithdrawROIFromEsusuCycle(currentEsusuCycleId.toString(), {from: account2});
            console.log(`Member 2 ROI withdrawal complete ...`);
           
            //  Withdraw overall ROI For Member 3
            await timeout(payoutIntervalSeconds + 10);
            await esusuServiceContract.WithdrawROIFromEsusuCycle(currentEsusuCycleId.toString(), {from: account3});
            console.log(`Member 3 ROI withdrawal complete ...`);

            var member1DaiBalanceAfterWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account1));
            var member2DaiBalanceAfterWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account2));
            var member3DaiBalanceAfterWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account3));

            console.log(`Member 1 Dai Balance After Withdrawing Overall ROI: ${member1DaiBalanceAfterWithdrawing}`);
            console.log(`Member 2 Dai Balance After Withdrawing Overall ROI: ${member2DaiBalanceAfterWithdrawing}`);
            console.log(`Member 3 Dai Balance After Withdrawing Overall ROI: ${member3DaiBalanceAfterWithdrawing}`);
            
            //  get current cycle ID
            currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId());

            //  Get updated status of this cycle
            result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());
            var totalBeneficiaries = Number(BigInt(result[10]));
            var cycleState = BigInt(result[3]).toString();

            assert(member1DaiBalanceBeforeWithdrawing < member1DaiBalanceAfterWithdrawing);  
            assert(member2DaiBalanceBeforeWithdrawing < member2DaiBalanceAfterWithdrawing);  
            assert(member3DaiBalanceBeforeWithdrawing < member3DaiBalanceAfterWithdrawing);  
            assert(totalBeneficiaries === 3);               
            //  Cycle state must be expired after all ROI has been withdrawn because the Cycle time should have elapsed for last member to withdraw 
            assert(cycleState === "2");
            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());
            assert(maxMembers.toString() === BigInt(result[11]).toString());

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);                
        });

        it('EsusuService Contract: Should Withdraw Capital For Each Of The 3 Accounts In The Current Esusu Cycle', async () => {
            //  NOTE: No need to have a withdrawal wait time since the cycle should be in expired state before this test is called

            //  Get esusu cycle information
            var result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());
            var cycleState = BigInt(result[3]).toString();

            //  Withdraw capitals when the cycle is in expired state
            if(cycleState === "2"){

                //  get the member position from the cycle information  so we can determine the approx withdrawal wait time
                var member1CycleInfo = await esusuServiceContract.GetMemberCycleInfo(account1, currentEsusuCycleId.toString());
                var member2CycleInfo = await esusuServiceContract.GetMemberCycleInfo(account2, currentEsusuCycleId.toString());
                var member3CycleInfo = await esusuServiceContract.GetMemberCycleInfo(account3, currentEsusuCycleId.toString());

                //  Get DaiBalance before withdrawal
                var member1DaiBalanceBeforeWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account1));
                var member2DaiBalanceBeforeWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account2));
                var member3DaiBalanceBeforeWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account3));

                console.log(`Member 1 Dai Balance Before Withdrawing Capital: ${member1DaiBalanceBeforeWithdrawing}`);
                console.log(`Member 2 Dai Balance Before Withdrawing Capital: ${member2DaiBalanceBeforeWithdrawing}`);
                console.log(`Member 3 Dai Balance Before Withdrawing Capital: ${member3DaiBalanceBeforeWithdrawing}`);

                //  Withdraw Capital For Member 1
                await esusuServiceContract.WithdrawCapitalFromEsusuCycle(currentEsusuCycleId.toString(), {from: account1});
                console.log(`Member 1 Capital withdrawal complete ...`);

                //  Withdraw Capital For Member 2
                await esusuServiceContract.WithdrawCapitalFromEsusuCycle(currentEsusuCycleId.toString(), {from: account2});
                console.log(`Member 2 Capital withdrawal complete ...`);
            
                //  Withdraw Capital For Member 3
                await esusuServiceContract.WithdrawCapitalFromEsusuCycle(currentEsusuCycleId.toString(), {from: account3});
                console.log(`Member 3 Capital withdrawal complete ...`);

                var member1DaiBalanceAfterWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account1));
                var member2DaiBalanceAfterWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account2));
                var member3DaiBalanceAfterWithdrawing = BigInt(await daiLendingAdapterContract.GetDaiBalance(account3));

                console.log(`Member 1 Dai Balance After Withdrawing Capital: ${member1DaiBalanceAfterWithdrawing}`);
                console.log(`Member 2 Dai Balance After Withdrawing Capital: ${member2DaiBalanceAfterWithdrawing}`);
                console.log(`Member 3 Dai Balance After Withdrawing Capital: ${member3DaiBalanceAfterWithdrawing}`);
                
                //  get current cycle ID
                currentEsusuCycleId = BigInt(await esusuServiceContract.GetCurrentEsusuCycleId());

                //  Get updated status of this cycle
                result = await esusuServiceContract.GetEsusuCycle(currentEsusuCycleId.toString());
                var totalBeneficiaries = Number(BigInt(result[10]));
                var cycleState = BigInt(result[3]).toString();

                assert(member1DaiBalanceBeforeWithdrawing < member1DaiBalanceAfterWithdrawing);  
                assert(member2DaiBalanceBeforeWithdrawing < member2DaiBalanceAfterWithdrawing);  
                assert(member3DaiBalanceBeforeWithdrawing < member3DaiBalanceAfterWithdrawing);  
                assert(totalBeneficiaries === 3);               
                //  Cycle state must be inactive after all Capital has been withdrawn
                assert(cycleState === "3");
                assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());
                assert(maxMembers.toString() === BigInt(result[11]).toString());

                console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])}, 
                CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])}, 
                TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
                TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);  
            }else{
                console.log("Cycle has not expired. Something is wrong !!!")
            }
              
        });

        //  Should depricate contract
        it('EsusuAdapter Contract: Should Depricate Contract', async () => {

            let adapterYDaiBalanceBeforeDeprication = await yDaiContract.methods.balanceOf(esusuAdapterContract.address).call();

            console.log(`YDai Shares Balance Before Deprication: ${adapterYDaiBalanceBeforeDeprication}`);

            await esusuAdapterContract.DepricateContract(esusuServiceContract.address, "the liquid metal");

            let adapterYDaiBalanceAfterDeprication = await yDaiContract.methods.balanceOf(esusuAdapterContract.address).call();

            console.log(`YDai Shares Balance After Deprication: ${adapterYDaiBalanceAfterDeprication}`);

            
            //  The code below should fail
            
            var groupInfo = await esusuServiceContract.GetGroupInformationByName(groupName);

            console.log(`Group Id: ${BigInt(groupInfo[0])}, Name: ${groupInfo[1]}, Symbol: ${groupInfo[2]}, Owner: ${groupInfo[3]}`);

        });

    });
    