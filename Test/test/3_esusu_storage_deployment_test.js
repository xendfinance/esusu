    /**
     *  @todo
     *  Ensure to install web3 before running this test -> npm install web3
     *  Tests to write:
     *  1.  Get Esusu ID                            -   Done
     *  2,  IncrementEsusuCycleId                   -   Done
     *  3.  CreateEsusuCycleMapping                 -   Done
     *  4.  Check if member is in cycle
     *  5.  IncreaseTotalAmountDepositedInCycle     -   Done
     *  6.  CreateMemberAddressToMemberCycleMapping -   Done
     *  7.  IncreaseTotalMembersInCycle             -   Done
     *  8.  CreateMemberPositionMapping             -   Done
     *  9.  IncreaseTotalDeposits                   -   Done
     *  10. UpdateEsusuCycleDuringStart             -   Done
     *  11. UpdateEsusuCycleState                   -   Done
     *  12. CreateMemberCapitalMapping              -   Done
     *  13. UpdateEsusuCycleDuringCapitalWithdrawal -   Done
     *  14. UpdateEsusuCycleDuringROIWithdrawal     -   Done
     *  15. CreateEsusuCycleToBeneficiaryMapping    -   Done
     *  16. CalculateMemberWithdrawalTime           -   Done
     */
     if(true){
         return;
     }
    console.log("********************** Running Esusu Storage Test *****************************");
    const Web3 = require('web3');
    const { assert } = require('console');
    const { Contract } = require('web3-eth-contract');
    const { deepStrictEqual } = require('assert');
    const web3 = new Web3("HTTP://127.0.0.1:8545");


    const EsusuStorageContract = artifacts.require('EsusuStorage');

    var account1;
    var account2;
    var account3;

    var account1Balance;
    var account2Balance;
    var account3Balance;

    /**
     *  @NOTE: This contract can only be modified by the owner, esusu adapter contract or esusu adapter withdrawal delegate contract
     *  For the purpose of this test, the modification will be done by the owner
     */


    contract('EsusuStorage', ()=>{

        let esusuStorageContract = null;

        before(async () =>{
            esusuStorageContract = await EsusuStorageContract.deployed();

                        //  Get the addresses and Balances of at least 2 accounts to be used in the test
            //  Send DAI to the addresses
            web3.eth.getAccounts().then(function(accounts){

                account1 = accounts[0];
                account2 = accounts[1];
                account3 = accounts[2];

            });
        });

        var groupId = "1";
        var depositAmount = "2000000000000000000000";   //2,000 DAI 10000000000000000000000
        var payoutIntervalSeconds = "30";  // 2 minutes
        var startTimeInSeconds = Math.floor((Date.now() + 120)/1000); // starts 2 minutes afer current time
        var maxMembers = "2";
        var currentEsusuCycleId = null;

        it('Esusu Storage: Should Get The Current Esusu Cycle ID',async () => {

            var result = await esusuStorageContract.GetEsusuCycleId();

            assert(BigInt(result).toString() === "0");

            console.log(`Esusu Storage: Current Cycle ID ${BigInt(result).toString()}`);

        });

        it('Esusu Storage: Should Increase The Esusu Cycle ID By 1',async () => {

            await esusuStorageContract.IncrementEsusuCycleId();

            var result = await esusuStorageContract.GetEsusuCycleId();

            currentEsusuCycleId = BigInt(result);

            assert(BigInt(result).toString() === "1");

            console.log(`Esusu Storage: Current Cycle ID ${BigInt(result).toString()}`);

        });

        it('Esusu Storage: Should Create Esusu Cycle Mapping ',async () => {

            // CreateEsusuCycleMapping(uint groupId, uint depositAmount, uint payoutIntervalSeconds,uint startTimeInSeconds, address owner, uint maxMembers)
            await esusuStorageContract.CreateEsusuCycleMapping(groupId, depositAmount,payoutIntervalSeconds,startTimeInSeconds,account1,maxMembers);

            currentEsusuCycleId = BigInt(await esusuStorageContract.GetEsusuCycleId());

            var result = await esusuStorageContract.GetEsusuCycle(currentEsusuCycleId.toString());

            var cycleOwner = await esusuStorageContract.GetCycleOwner(currentEsusuCycleId.toString());

            assert(currentEsusuCycleId.toString() === BigInt(result[0]).toString());
            assert(BigInt(result[0]).toString() === "2");
            assert(BigInt(result[1]).toString() === "2000000000000000000000");
            assert(BigInt(result[2]).toString() === "30");
            assert(BigInt(result[11]).toString() === "2");
            assert(cycleOwner.toString() === account1);



            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])},
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])},
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);


        });

        it('Esusu Storage: Should Increase Total Amount Deposited In Cycle  ',async () => {

            await esusuStorageContract.IncreaseTotalAmountDepositedInCycle(currentEsusuCycleId.toString(), depositAmount);


            var result = await esusuStorageContract.GetEsusuCycle(currentEsusuCycleId.toString());

            assert(BigInt(result[5]).toString() === "2000000000000000000000");

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])},
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])},
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);

        });

        //  This ensures that a member is also added to membercyclemapping for tracking the cycles members belong to
        it('Esusu Storage: Should Create MemberAddressToMemberCycleMapping  ',async () => {

            await esusuStorageContract.CreateMemberAddressToMemberCycleMapping(account1,currentEsusuCycleId.toString());

            var result = await esusuStorageContract.GetMemberCycleInfo(account1,currentEsusuCycleId.toString());

            assert(result[1] === account1);
            assert(BigInt(result[4]).toString() === "0");   //  This will always be 0. It can only increase when a member joins a cycle.

            console.log(`CycleId: ${BigInt(result[0])}, MemberId: ${result[1]},TotalAmountDepositedInCycle: ${BigInt(result[2])}, TotalPayoutReceivedInCycle: ${BigInt(result[3])}, MemberPosition: ${BigInt(result[4])} `);

        });

        it('Esusu Storage: Should Increase TotalMembers In An Esusu Cycle  ',async () => {

            await esusuStorageContract.IncreaseTotalMembersInCycle(currentEsusuCycleId.toString());

            var result = await esusuStorageContract.GetEsusuCycleBasicInformation(currentEsusuCycleId.toString());

            assert(BigInt(result[3]).toString() === "1");

            console.log(`Cycle Basic Information-> CycleId: ${BigInt(result[0])}, DepositAmount: ${result[1]},CycleState: ${BigInt(result[2])}, TotalMembers: ${BigInt(result[3])}, MaxMembers: ${BigInt(result[4])} `);
        });

        it('Esusu Storage: Should Create Member Position Mapping  ',async () => {

            await esusuStorageContract.CreateMemberPositionMapping(currentEsusuCycleId.toString(), account1);

            var result = await esusuStorageContract.GetMemberCycleInfo(account1, currentEsusuCycleId.toString());

            assert(BigInt(result[4]).toString() === "1");
            console.log(account1.toString());

            console.log(`Member Cycle Info-> CycleId: ${BigInt(result[0])}, MemberId: ${result[1]},TotalAmountDepositedInCycle: ${BigInt(result[2])}, TotalPayoutReceivedInCycle: ${BigInt(result[3])}, memberPosition: ${BigInt(result[4])} `);

        });

        it('Esusu Storage: Should Increase Total Deposits ',async () => {

            await esusuStorageContract.IncreaseTotalDeposits(depositAmount);

            var totalDepositsMadeInStorageContract = await esusuStorageContract.GetTotalDeposits();

            console.log(`Total Doposits Made In Esusu Storage Contract: ${totalDepositsMadeInStorageContract}`);

            assert(BigInt(totalDepositsMadeInStorageContract).toString() === "2000000000000000000000");


        });

        it('Esusu Storage: Should Update Esusu Cycle During Start ',async () => {

            await esusuStorageContract.UpdateEsusuCycleDuringStart(currentEsusuCycleId.toString(), "1","360","345000000000000000000", "1603958687");
            var result = await esusuStorageContract.GetEsusuCycle(currentEsusuCycleId.toString());

            assert(BigInt(result[6]).toString() === "345000000000000000000");

            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])},
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])},
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);

        });


        it('Esusu Storage: Should Update Esusu Cycle State ',async () => {

            //  Update cycle state here with one value
            await esusuStorageContract.UpdateEsusuCycleDuringStart(currentEsusuCycleId.toString(), "1","360","345000000000000000000", "1603958687");

            //  Update the cycle state with the function we are testin
            await esusuStorageContract.UpdateEsusuCycleState(currentEsusuCycleId.toString(), "2");

            var result = await esusuStorageContract.GetEsusuCycle(currentEsusuCycleId.toString());

            assert(BigInt(result[3]).toString() === "2");



            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])},
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])},
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);
        });

        it('Esusu Storage: Should Create Member Capital Mapping  ',async () => {

            await esusuStorageContract.CreateMemberCapitalMapping(currentEsusuCycleId.toString(), account1);

            var capitalWithdrawn = await esusuStorageContract.GetMemberWithdrawnCapitalInEsusuCycle(currentEsusuCycleId.toString(),account1);

            console.log(`Capital Withdrawn: ${capitalWithdrawn}`);

            //  capital withdrawn is 2000000000000000000000 because I have called CreateMemberCapitalMapping before calling GetMemberWithdrawnCapitalInEsusuCycle
            //  creating capital mapping for a member means he has withdrawn the deposit amount of that cycle
            assert(BigInt(capitalWithdrawn).toString() === "2000000000000000000000");

        });

        it('Esusu Storage: Should Update Esusu Cycle During Capital Withdrawal ',async () => {


            await esusuStorageContract.UpdateEsusuCycleDuringCapitalWithdrawal(currentEsusuCycleId.toString(), "880000000000000000000","2000000000000000000000");

            var result = await esusuStorageContract.GetEsusuCycle(currentEsusuCycleId.toString());


            assert(BigInt(result[8]).toString() === "2000000000000000000000");



            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])},
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])},
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);

        });

        it('Esusu Storage: Should Update Esusu Cycle During ROI Withdrawal',async () => {


            await esusuStorageContract.UpdateEsusuCycleDuringROIWithdrawal(currentEsusuCycleId.toString(),"4560000000006540000000", "2");

            var totalBeneficiaries = await esusuStorageContract.GetEsusuCycleTotalBeneficiaries(currentEsusuCycleId.toString());

            // console.log(`Total Beneficiaries: ${totalBeneficiaries}`);

            assert(BigInt(totalBeneficiaries).toString() === "2");

            var result = await esusuStorageContract.GetEsusuCycle(currentEsusuCycleId.toString());

            assert(BigInt(result[6]).toString() === "4560000000006540000000");



            console.log(`CycleId: ${BigInt(result[0])}, DepositAmount: ${BigInt(result[1])}, PayoutIntervalSeconds: ${BigInt(result[2])},
            CycleState: ${BigInt(result[3])}, TotalMembers: ${BigInt(result[4])}, TotalAmountDeposited: ${BigInt(result[5])},TotalShares: ${BigInt(result[6])},
            TotalCycleDurationInSeconds: ${BigInt(result[7])}, TotalCapitalWithdrawn: ${BigInt(result[8])}, CycleStartTimeInSeconds: ${BigInt(result[9])},
            TotalBeneficiaries: ${BigInt(result[10])}, MaxMembers: ${BigInt(result[11])}`);
        });

        it('Esusu Storage: Should Calculate Member WithdrawalTime',async () => {


            //  1. We need to create esusu cycle mapping
            await esusuStorageContract.CreateEsusuCycleMapping(groupId, depositAmount,payoutIntervalSeconds,startTimeInSeconds,account1,maxMembers);

            var cycleId = await esusuStorageContract.GetEsusuCycleId();

            console.log(`Current Cycle ID: ${BigInt(cycleId).toString()}`);
            console.log(`Current Cycle ID - Variable: ${currentEsusuCycleId}`);

            //  2. Increase the total members in cycle so when we create member position mapping it will assign total members as 1
            await esusuStorageContract.IncreaseTotalMembersInCycle(cycleId.toString());

            //  3. We need to create member position mapping
            await esusuStorageContract.CreateMemberPositionMapping(cycleId.toString(), account1);


            //  4. Get member position
            var memberPosistion = await esusuStorageContract.GetMemberCycleInfo(account1, cycleId.toString());

            var expectedWithdrawalTime = startTimeInSeconds + (Number(BigInt(memberPosistion[4]).toString()) * Number(payoutIntervalSeconds));
            console.log(`Expected Withdrawal Time: ${expectedWithdrawalTime}`);


            var withdrawalTime = await esusuStorageContract.CalculateMemberWithdrawalTime(cycleId.toString(), account1);

            console.log(`Withdrawal Time: ${withdrawalTime}`);

            assert(expectedWithdrawalTime.toString() === Number(withdrawalTime).toString());
        });



    })
