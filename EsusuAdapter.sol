pragma solidity ^0.6.6;

import "./IDaiToken.sol";
import "./IYDaiToken.sol";

import "./IDaiLendingService.sol";


// TODO: change all these external functions to public once we create the Esusu Service contract that call this
// TODO: add a function that only owner of this contract can call to transfer the left over dai for every inactive cycle if any to the community wallet

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;

        return c;
    }
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract EsusuAdapter{
    
    using SafeMath for uint256;

    /*  Model definition starts */
    string Dai = "Dai Stablecoin";

    /*  Enum definitions */
    enum CurrencyEnum{
        Dai
    }
    
    enum CycleStateEnum{
        Idle,               // Cycle has just been created and members can join in this state
        Active,             // Cycle has started and members can take their ROI
        Expired,            // Cycle Duration has elapsed and members can withdraw their capital as well as ROI
        Inactive            // Total beneficiaries is equal to Total members, so all members have withdrawn their Capital and ROI 
    }
    
    
    /*  Struct Definitions */
    struct EsusuCycle{
        uint CycleId;
        uint DepositAmount;
        uint TotalMembers;
        uint TotalBeneficiaries;
        address Owner;
        uint PayoutIntervalSeconds;    //  Time each member receives overall ROI within one Esusu Cycle in seconds
        uint CycleDuration; //  The total time it will take for all users to be paid which is (number of members * payout interval)
        CurrencyEnum Currency;  //  Currency supported in this Esusu Cycle 
        string CurrencySymbol;
        CycleStateEnum CycleState;  //  The current state of the Esusu Cycle
        uint256 TotalAmountDeposited;   // Total  Dai Deposited
        uint TotalCapitalWithdrawn;      // Total Capital In Dai Withdrawn
        uint TotalCycleDuration;
        uint CycleStartTime;
        uint TotalShares;               //  Total yDai Shares 
    }
    
    struct Member{
        address MemberId;
        uint TotalDeposited;
        uint TotalPayoutReceived;
    }
    
    struct MemberCycle{
        uint CycleId;
        address MemberId;
        uint TotalAmountDepositedInCycle;
        uint TotalPayoutReceivedInCycle;
    }
    
    /* Model definition ends */
    
    constructor () public{
        _owner = msg.sender;
    }
    
    
    //  Member variables
    address _owner;
    IDaiLendingService _iDaiLendingService;
    IDaiToken _dai = IDaiToken(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IYDaiToken _yDai = IYDaiToken(0xC2cB1040220768554cf699b0d863A3cd4324ce32);

     

    uint EsusuCycleId = 0;
    
    EsusuCycle [] EsusuCyclesArray;  //  Store all EsusuCycles
    
    mapping(uint => EsusuCycle) EsusuCycleMapping;
    

    mapping(address=>mapping(uint=>MemberCycle)) MemberAddressToMemberCycleMapping;

    mapping(uint=>mapping(address=>uint)) CycleToMemberPositionMapping;   //  This tracks position of the  member in an Esusu Cycle

    mapping(uint=>mapping(address=> uint)) CycleToBeneficiaryMapping;  // This tracks members that have received overall ROI and amount received within an Esusu Cycle
    
    mapping(uint=>mapping(address=> uint)) CycleToMemberWithdrawnCapitalMapping;    // Rhis tracks members that have withdrawn their capital and the amount withdrawn 
    
    function UpdateDaiLendingService(address daiLendingServiceContractAddress) external onlyOwner(){
        _iDaiLendingService = IDaiLendingService(daiLendingServiceContractAddress);
    }
    
    
    function CreateEsusu(uint depositAmount, uint payoutIntervalSeconds, address owner) public {
        
        EsusuCycle memory cycle;
        cycle.DepositAmount = depositAmount;
        cycle.PayoutIntervalSeconds = payoutIntervalSeconds;
        cycle.Currency = CurrencyEnum.Dai;
        cycle.CurrencySymbol = Dai;
        cycle.CycleState = CycleStateEnum.Idle; 
        cycle.Owner = owner;
        
        //  Increment EsusuCycleId by 1
        EsusuCycleId += 1;
        EsusuCycleMapping[EsusuCycleId].CycleId = EsusuCycleId;

        //  Create mapping
        EsusuCycleMapping[EsusuCycleId] = cycle;
        
        //  Add EsusuCycle to array
        EsusuCyclesArray.push(cycle);

        
    }
    
    //  Join a particular Esusu Cycle 
    /*
        - Check if the cycle ID is valid
        - Check if the cycle is in Idle state, that is the only state a member can join
        - Check if member is already in Cycle
        - Ensure member has approved this contract to transfer the token on his/her behalf
        - If member has enough balance, transfer the tokens to this contract else bounce
        - Increment the total deposited amount in this cycle and total deposited amount for the member cycle struct 
        - Increment the total number of Members that have joined this cycle 
    */
    function JoinEsusu(uint esusuCycleId, address member) public {
        
        //  Check if the cycle ID is valid
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");

        //  If cycle is not in Idle State, bounce 
        EsusuCycle storage cycle = EsusuCycleMapping[esusuCycleId];
        require(cycle.CycleState == CycleStateEnum.Idle, "Esusu Cycle must be in Idle State before you can join");
        

        //  check if member is already in this cycle 
        require(_isMemberInCycle(member,esusuCycleId) == false, "Member can't join same Esusu Cycle more than once");
        
        //  If user does not have enough Balance, bounce. For now we use Dai as default
        uint memberBalance = _dai.balanceOf(member);
        
        require(memberBalance >= cycle.DepositAmount, "Balance must be greater than or equal to Deposit Amount");
        
        //  If user balance is greater than or equal to deposit amount then transfer from member to this contract TODO: we will send to storage contract later
        //  NOTE: approve this contract to withdraw before transferFrom can work
        _dai.transferFrom(member, address(this),cycle.DepositAmount);
        
        //  Increment the total deposited amount in this cycle
        cycle.TotalAmountDeposited = cycle.TotalAmountDeposited.add(cycle.DepositAmount);
        
        //  Increment the total deposited amount for the member cycle struct
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[member];
        

        memberCycleMapping[esusuCycleId].CycleId = esusuCycleId;
        memberCycleMapping[esusuCycleId].MemberId = member;
        memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle = memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle.add(cycle.DepositAmount);
        memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle = memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle.add(0);
        
        //  Increase TotalMembers count by 1
        EsusuCycleMapping[esusuCycleId].TotalMembers = EsusuCycleMapping[esusuCycleId].TotalMembers.add(1);
        
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[esusuCycleId];
        
        //  Assign Position to Member In this Cycle
        memberPositionMapping[member] = EsusuCycleMapping[esusuCycleId].TotalMembers;
    }
    
    function GetMemberCycleInfo(address memberAddress, uint esusuCycleId) public view returns(uint CycleId, address MemberId, uint TotalAmountDepositedInCycle, uint TotalPayoutReceivedInCycle, uint memberPosition){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[memberAddress];
        
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[esusuCycleId];
        
        //  Get Number(Position) of Member In this Cycle
        uint memberPos = memberPositionMapping[memberAddress];
        
        return  (memberCycleMapping[esusuCycleId].CycleId,memberCycleMapping[esusuCycleId].MemberId,
        memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle,
        memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle,memberPos);
    }

    function GetEsusuCycle(uint esusuCycleId) public view returns(uint CycleId, uint DepositAmount, 
                                                            uint PayoutIntervalSeconds, uint CycleState, address Owner, 
                                                            uint TotalMembers, uint TotalAmountDeposited, uint TotalShares, 
                                                            uint TotalCycleDurationInSeconds, uint TotalCapitalWithdrawn, uint CycleStartTimeInSeconds,
                                                            uint TotalBeneficiaries){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleId, cycle.DepositAmount,  cycle.PayoutIntervalSeconds, 
                uint256(cycle.CycleState),
                cycle.Owner,cycle.TotalMembers, cycle.TotalAmountDeposited, cycle.TotalShares,
                cycle.TotalCycleDuration, cycle.TotalCapitalWithdrawn, cycle.CycleStartTime,
                cycle.TotalBeneficiaries);
        
    }
    
    /*
        - Check if the Id is a valid ID
        - Check if the cycle is in Idle State
        - Only owner of a cycle can start that cycle - TODO: Change this function to public so it can be called from another contract
        - Get the total number of members and then mulitply by the time interval in seconds to get the total time this Cycle will last for
        - Set the Cycle start time to now 
        - Take everyones deposited DAI from this Esusu Cycle and then invest through Yearn 
        - Track the yDai shares that belong to this cycle using the derived equation below for save/investment operation
            - yDaiSharesPerCycle = Change in yDaiSharesForContract + Current yDai Shares in the cycle 
            - Change in yDaiSharesForContract = yDai.balanceOf(address(this) after save operation - yDai.balanceOf(address(this) after before operation
    */
    function StartEsusuCycle(uint esusuCycleId, address owner) public {
        
        //  If cycle ID is valid, else bonunce
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle storage cycle = EsusuCycleMapping[esusuCycleId];
        
        require(cycle.CycleState == CycleStateEnum.Idle, "Cycle can only be started when in Idle state");
        
        require(cycle.Owner == owner, "Only owner of this Esusu Can start this cycle");
        
        EsusuCycleMapping[esusuCycleId].CycleState = CycleStateEnum.Active;
        
        //  Calculate Cycle LifeTime in seconds
        EsusuCycleMapping[esusuCycleId].TotalCycleDuration = cycle.PayoutIntervalSeconds * cycle.TotalMembers;
        
        //  Set the Cycle start time 
        EsusuCycleMapping[esusuCycleId].CycleStartTime = now;
        
        //  Get all the dai deposited for this cycle
        uint esusuCycleBalance = cycle.TotalAmountDeposited;
        
        //  Get the balance of yDaiSharesForContract before save opration
        uint yDaiSharesForContractBeforeSave = _yDai.balanceOf(address(this));
        
        //  Invest the dai in Yearn Finance using Dai Lending Service.
        
        //  NOTE: yDai will be sent to this contract
        //  Transfer dai from this contract to dai lending adapter and then call a new save function that will not use transferFrom internally
        //  Approve the daiLendingAdapter so it can spend our Dai on our behalf 
        address daiLendingAdapterContractAddress = _iDaiLendingService.GetDaiLendingAdapterAddress();
        _dai.approve(daiLendingAdapterContractAddress,esusuCycleBalance);
        
        _iDaiLendingService.save(esusuCycleBalance);
        
        //  Get the balance of yDaiSharesForContract after save operation
        uint yDaiSharesForContractAfterSave = _yDai.balanceOf(address(this));
        
        
        //  Save yDai Total balanceShares
        EsusuCycleMapping[esusuCycleId].TotalShares = yDaiSharesForContractAfterSave.sub(yDaiSharesForContractBeforeSave).add(EsusuCycleMapping[esusuCycleId].TotalShares);
        
    }
    
    /*
        Assumption:
        - We assume even distribution of Overall accumulated ROI among members of the group when a member places a withdrawal request at a time inverval 
          greater than members in the previous position who have not placed a withdrawal request.
        
        This function performs sends all ROI generated within an Esusu Cycle Payout Interval to a particular member
        
        - Check if member is eligible to withdraw
        - Get the price per full share from Dai Lending Service\
        - Get overall DAI => yDai balanceShares * pricePerFullShare (NOTE: value is in 1e36)
        - Get ROI => overall Dai - Total Deposited Dai in this esusu cycle 
        - Implement our derived equation to determine what ROI will be allocated to this member who is withdrawing 
        - Equation Parameters
            - Ta => Total available time in seconds
            - Bt => Total Time Interval for beneficiaries in this cycle in seconds
            - Tnow => Current Time in seconds
            - T => Cycle PayoutIntervalSeconds
            - Troi => Total accumulated ROI
            - Mroi => Member ROI 
            
            Equations 
            - Bt = T * number of beneficiaries
            - Ta = Tnow - Bt
            - Troi = ((balanceShares * pricePerFullShare ) - TotalDeposited)
            - Mroi = (Total accumulated ROI at Tnow) / (Ta)   
        
        NOTE: As members withdraw their funds, the yDai balanceShares will change and we will be updating the TotalShares with this new value
        at all times till TotalShares becomes approximately zero when all amounts have been withdrawn including capital invested
        
        - Track the yDai shares that belong to this cycle using the derived equation below for withdraw operation
            - yDaiSharesPerCycle = Current yDai Shares in the cycle - Change in yDaiSharesForContract   
            - Change in yDaiSharesForContract = yDai.balanceOf(address(this)) before withdraw operation - yDai.balanceOf(address(this)) after withdraw operation
        
    */
    function WithdrawROIFromEsusuCycle(uint esusuCycleId, address member) public {
        
        bool isMemberEligibleToWithdraw = _isMemberEligibleToWithdrawROI(esusuCycleId,member);
        
        require(isMemberEligibleToWithdraw, "Member cannot withdraw at this time");
        
        EsusuCycle storage cycle = EsusuCycleMapping[esusuCycleId];

        uint currentBalanceShares = cycle.TotalShares;
        
        uint pricePerFullShare = _iDaiLendingService.getPricePerFullShare();
        
        uint overallGrossDaiBalance = currentBalanceShares.mul(pricePerFullShare).div(1e18);
        
        
        //  Implement our derived equation to get the amount of Dai to transfer to the member as ROI
        uint Bt = cycle.PayoutIntervalSeconds.mul(cycle.TotalBeneficiaries);
        uint Ta = now.sub(Bt);
        uint Troi = overallGrossDaiBalance.sub(cycle.TotalAmountDeposited.sub(cycle.TotalCapitalWithdrawn));
        uint Mroi = Troi.div(Ta);
        
        
        //  Add member to beneficiary mapping
        mapping(address=>uint) storage beneficiaryMapping =  CycleToBeneficiaryMapping[esusuCycleId];
        beneficiaryMapping[member] = Mroi;
        
        
        //  Get the current yDaiSharesPerCycle and call the WithdrawByShares function on the daiLending Service
        uint yDaiSharesPerCycle = cycle.TotalShares;
        
        //  Get the yDaiSharesForContractBeforeWithdrawal 
        uint yDaiSharesForContractBeforeWithdrawal = _yDai.balanceOf(address(this));
        
        //  Withdraw the Dai. At this point, we have withdrawn the Dai ROI for this member and the dai ROI is in this contract, we will now transfer it to the member
        address daiLendingAdapterContractAddress = _iDaiLendingService.GetDaiLendingAdapterAddress();
        _yDai.approve(daiLendingAdapterContractAddress,yDaiSharesPerCycle);
        _iDaiLendingService.WithdrawByShares(Mroi,yDaiSharesPerCycle);
        
        //  Now the Dai is in this contract, transfer it to the member 
        _dai.transfer(member, Mroi);
        
        //  Get the yDaiSharesForContractAfterWithdrawal 
        uint yDaiSharesForContractAfterWithdrawal = _yDai.balanceOf(address(this));
        
        require(yDaiSharesForContractBeforeWithdrawal > yDaiSharesForContractAfterWithdrawal, "yDai shares before withdrawal must be greater !!!");
        
        //  Update the total balanceShares for this cycle 
        cycle.TotalShares = yDaiSharesPerCycle.sub(yDaiSharesForContractBeforeWithdrawal.sub(yDaiSharesForContractAfterWithdrawal));
        
        //  Increase total number of beneficiaries by 1
        cycle.TotalBeneficiaries = cycle.TotalBeneficiaries.add(1);
        
        /*
                
            - Check whether the TotalCycleDuration has elapsed, if that is the case then this cycle has expired

        */
        
        if(now > cycle.TotalCycleDuration){
            
            cycle.CycleState = CycleStateEnum.Expired;
        }
        

    }
    
    
    
    /*
        This function allows members to withdraw their capital from the esusu cycle
        
        - Check if member can withdraw capital 
        - Withdraw capital and increase TotalCapitalWithdrawn
            - Get the total balanceShares from the calling contract
            - Withdraw all the money from dai lending service
            - Send the member's deposited amount to his/her address 
            - re-invest the remaining dai until all members have taken their capital, then we set the cycle inactive
        - Add this member to the EsusuCycleCapitalMapping
        - Check if TotalCapitalWithdrawn == TotalAmountDeposited && if TotalMembers == TotalBeneficiaries, if yes, set the Cycle to Inactive

    */
    
    function WithdrawCapitalFromEsusuCycle(uint esusuCycleId, address member) public {
        
        require(_isMemberEligibleToWithdrawCapital(esusuCycleId,member));
        
        //  Add member to capital withdrawn mapping
        
        mapping(address=>uint) storage memberCapitalMapping =  CycleToMemberWithdrawnCapitalMapping[esusuCycleId];
        
        EsusuCycle storage cycle = EsusuCycleMapping[esusuCycleId];

        uint memberDeposit = cycle.DepositAmount;
        
        //  Get the current yDaiSharesPerCycle and call the WithdrawByShares function on the daiLending Service
        uint yDaiSharesPerCycle = cycle.TotalShares;
        
        //  Get the yDaiSharesForContractBeforeWithdrawal 
        uint yDaiSharesForContractBeforeWithdrawal = _yDai.balanceOf(address(this));
        
        //  Withdraw the Dai. At this point, we have withdrawn  Dai Capital deposited by this member for this cycle and we will now transfer the dai capital to the member
        address daiLendingAdapterContractAddress = _iDaiLendingService.GetDaiLendingAdapterAddress();
        _yDai.approve(daiLendingAdapterContractAddress,yDaiSharesPerCycle);
        _iDaiLendingService.WithdrawByShares(memberDeposit,yDaiSharesPerCycle);
        
        //  Now the Dai is in this contract, transfer it to the member 
        _dai.transfer(member, memberDeposit);
        
        //  Get the yDaiSharesForContractAfterWithdrawal 
        uint yDaiSharesForContractAfterWithdrawal = _yDai.balanceOf(address(this));
        
        require(yDaiSharesForContractBeforeWithdrawal > yDaiSharesForContractAfterWithdrawal, "yDai shares before withdrawal must be greater !!!");
        
        //  Update the total balanceShares for this cycle 
        cycle.TotalShares = yDaiSharesPerCycle.sub(yDaiSharesForContractBeforeWithdrawal.sub(yDaiSharesForContractAfterWithdrawal));
        
        //  Add this member to the CycleToMemberWithdrawnCapitalMapping
        memberCapitalMapping[member] = memberDeposit;
        
        //  Increase total capital withdrawn 
        cycle.TotalCapitalWithdrawn = cycle.TotalCapitalWithdrawn.add(memberDeposit);
        
        //   Check if TotalCapitalWithdrawn == TotalAmountDeposited && if TotalMembers == TotalBeneficiaries, if yes, set the Cycle to Inactive
        
        if(cycle.TotalCapitalWithdrawn == cycle.TotalAmountDeposited && cycle.TotalMembers == cycle.TotalBeneficiaries){
            
            EsusuCycleMapping[esusuCycleId].CycleState = CycleStateEnum.Inactive;
        }
    }
    
    /*
        This function checks whether the user can withdraw at the time at which the user is making this call
        
        - Check if cycle is valid 
        - Check if cycle is in active state
        - Check if member is in cycle
        - Check if member is a beneficiary
        - Calculate member withdrawal time
        - Check if member can withdraw at this time
    */
    function IsMemberEligibleToWithdrawROI(uint esusuCycleId, address member) public view returns(bool){
        
        return _isMemberEligibleToWithdrawROI(esusuCycleId,member);
        
    }
    
    /*
        This function checks whether the user can withdraw capital after the Esusu Cycle is complete. 
        
        The cycle must be in an inactive state before capital can be withdrawn
    */
    function IsMemberEligibleToWithdrawCapital(uint esusuCycleId, address member) public view returns(bool){
        
        return _isMemberEligibleToWithdrawCapital(esusuCycleId,member);
        
    }
    
    function _isMemberEligibleToWithdrawROI(uint esusuCycleId, address member) internal view returns(bool){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        require(cycle.CycleState == CycleStateEnum.Active || cycle.CycleState == CycleStateEnum.Expired, "Cycle must be in active or expired state");
        
        require(_isMemberInCycle(member,esusuCycleId), "Member is not in this cycle");
        
        require(_isMemberABeneficiaryInCycle(member,esusuCycleId) == false, "Member is already a beneficiary");
        
        uint memberWithdrawalTime = _calculateMemberWithdrawalTime(cycle,member);
        
        if(now > memberWithdrawalTime){
            return true;

        }else{
            return false;
        }
        
    }
    
    function _isMemberEligibleToWithdrawCapital(uint esusuCycleId, address member) internal view returns(bool){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        require(cycle.CycleState == CycleStateEnum.Expired, "Cycle must be in Expired state for you to withdraw capital");
        
        require(_isMemberInCycle(member,esusuCycleId), "Member is not in this cycle");
        
        require(_isMemberABeneficiaryInCycle(member,esusuCycleId) == true, "Member must be a beneficiary before you can withdraw capital");

        require(_isMemberInWithdrawnCapitalMapping(member,esusuCycleId) == false, "Member can't withdraw capital twice");

        return true;
        
    }
    
    /* Test helper functions starts  TODO: remove later */
    function GetDaiBalance(address member) external view returns(uint){
        return _dai.balanceOf(member);
    }
    
    function GetYDaiBalance(address member) external view returns(uint){
        return _yDai.balanceOf(member);
    }
    
    function GetCurrentTime() external view returns (uint){
        return now;
    }
    function GetTimeInMinutes() external view returns (uint){
        return 5 minutes;
    }
    function GetTimeInMinutesPlusnow() external view returns (uint){
        return 5 minutes + now;
    }
    
    function CalculateMemberWithdrawalTime(uint esusuCycleId, address member) internal view returns(uint){
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];

        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[cycle.CycleId];
        
        uint memberPosition = memberPositionMapping[member];
        
        uint withdrawalTime = (cycle.CycleStartTime.add(memberPosition.mul(cycle.PayoutIntervalSeconds)));
        
        return withdrawalTime;
    }
    
    
    /*  Test helper functions ends TODO: remove later */

    /*
        This function returns the Withdrawal time for a member in seconds
        
        Parameters
        - Wt    -> Withdrawal Time for a member 
        - To    -> Cycle Start Time
        - Mpos  -> Member Position in the Cycle 
        - Ct     -> Cycle Time Interval in seconds
        
        Equation
        Wt = (To + (Mpos * Ct))
    */
    
    function _calculateMemberWithdrawalTime(EsusuCycle memory cycle, address member) internal view returns(uint){
        
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[cycle.CycleId];
        
        uint memberPosition = memberPositionMapping[member];
        
        uint withdrawalTime = (cycle.CycleStartTime.add(memberPosition.mul(cycle.PayoutIntervalSeconds)));
        
        return withdrawalTime;
    }
    
    function GetCurrentEsusuCycleId() public view returns(uint){
        return EsusuCycleId;
    }
    
    function _isMemberInCycle(address memberAddress,uint esusuCycleId ) internal view returns(bool){
        
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[memberAddress];
        
        //  If member is in cycle, the cycle ID should be greater than 0
        if(memberCycleMapping[esusuCycleId].CycleId > 0){
            
            return true;
        }else{
            return false;
        }
    }
    
    function _isMemberABeneficiaryInCycle(address memberAddress,uint esusuCycleId ) internal view returns(bool){
        
        mapping(address=>uint) storage beneficiaryMapping =  CycleToBeneficiaryMapping[esusuCycleId];
        
        uint amount = beneficiaryMapping[memberAddress];
        
        //  If member has received money from this cycle, the amount recieved should be greater than 0

        if(amount > 0){
            
            return true;
        }else{
            return false;
        }
    }
    function _isMemberInWithdrawnCapitalMapping(address memberAddress,uint esusuCycleId ) internal view returns(bool){
        
        mapping(address=>uint) storage memberWithdrawnCapitalMapping =  CycleToMemberWithdrawnCapitalMapping[esusuCycleId];
        
        uint amount = memberWithdrawnCapitalMapping[memberAddress];
        
        //  If member has withdrawn capital from this cycle, the amount recieved should be greater than 0

        if(amount > 0){
            
            return true;
        }else{
            return false;
        }
    }
    
    
    modifier onlyOwner(){
        require(_owner == msg.sender, "Only owner can make this call");
        _;
    }
}

