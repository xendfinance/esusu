pragma solidity ^0.6.6;

import "./IDaiToken.sol";

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
        Idle, Active, Inactive
    }
    
    
    /*  Struct Definitions */
    struct EsusuCycle{
        uint CycleId;
        uint DepositAmount;
        uint TotalMembers;
        address Owner;
        uint PayoutIntervalMilliSeconds;    //  Time each member receives overall ROI within one Esusu Cycle in milliseconds
        uint CycleDuration; //  The total time it will take for all users to be paid which is (number of members * payout interval)
        CurrencyEnum Currency;  //  Currency supported in this Esusu Cycle 
        string CurrencySymbol;
        CycleStateEnum CycleState;  //  The current state of the Esusu Cycle
        uint256 TotalAmountDeposited;
        uint TotalCycleDuration;
        uint CycleStartTime;
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
    
    //  Member variables
    
    IDaiToken dai = IDaiToken(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    uint EsusuCycleId = 0;
    
    EsusuCycle [] EsusuCyclesArray;  //  Store all EsusuCycles
    
    mapping(uint => EsusuCycle) EsusuCycleMapping;
    

    mapping(address=>mapping(uint=>MemberCycle)) MemberAddressToMemberCycleMapping;

    mapping(uint=>mapping(address=>uint)) CycleToMemberPositionMapping;   //  This tracks position of the  member in an Esusu Cycle

    mapping(uint=>mapping(address=> Member)) CycleToBeneficiaryMapping;  // This tracks members that have received overall ROI within an Esusu Cycle

    function CreateEsusu(uint depositAmount, uint payoutIntervalMilliSeconds) external {
        
        EsusuCycle memory cycle;
        cycle.DepositAmount = depositAmount;
        cycle.PayoutIntervalMilliSeconds = payoutIntervalMilliSeconds;
        cycle.Currency = CurrencyEnum.Dai;
        cycle.CurrencySymbol = Dai;
        cycle.CycleState = CycleStateEnum.Idle; 
        cycle.Owner = msg.sender;
        
        //  Increment EsusuCycleId by 1
        EsusuCycleId += 1;
        cycle.CycleId = EsusuCycleId;

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
    function JoinEsusu(uint esusuCycleId, address member)external {
        
        //  If cycle ID is 0, bonunce
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");

        //  If cycle is not in Idle State, bounce 
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        require(cycle.CycleState == CycleStateEnum.Idle, "Esusu Cycle must be in Idle State before you can join");
        

        //  check if member is already in this cycle 
        require(_isMemberInCycle(member,esusuCycleId) == false, "Member can't join same Esusu Cycle more than once");
        
        //  If user does not have enough Balance, bounce. For now we use Dai as default
        uint memberBalance = dai.balanceOf(member);
        
        require(memberBalance >= cycle.DepositAmount, "Balance must be greater than or equal to Deposit Amount");
        
        //  If user balance is greater than or equal to deposit amount then transfer from member to this contract TODO: we will send to storage contract later
        //  NOTE: approve this contract to withdraw before transferFrom can work
        dai.transferFrom(member, address(this),cycle.DepositAmount);
        
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
    
    function GetMemberCycleInfo(address memberAddress, uint esusuCycleId) external view returns(uint CycleId, address MemberId, uint TotalAmountDepositedInCycle, uint TotalPayoutReceivedInCycle, uint memberPosition){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[memberAddress];
        
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[esusuCycleId];
        
        //  Get Number(Position) of Member In this Cycle
        uint memberPos = memberPositionMapping[memberAddress];
        
        return  (memberCycleMapping[esusuCycleId].CycleId,memberCycleMapping[esusuCycleId].MemberId,
        memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle,
        memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle,memberPos);
    }

    function GetEsusuCycle(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount, 
                                                            uint PayoutIntervalMilliSeconds, uint Currency, 
                                                            string memory CurrencySymbol, uint CycleState, address Owner, uint TotalMembers ){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleId, cycle.DepositAmount,  cycle.PayoutIntervalMilliSeconds, 
                uint256(cycle.Currency),cycle.CurrencySymbol,uint256(cycle.CycleState), cycle.Owner,cycle.TotalMembers);
        
    }
    
    /*
        - Check if the Id is a valid ID
        - Check if the cycle is in Idle State
        - Only owner of a cycle can start that cycle - TODO: Change this function to public so it can be called from another contract
        - Get the total number of members and then mulitply by the time interval in milliseconds to get the total time this Cycle will last for
        - Set the Cycle start time to now 
        - Take everyones deposited DAI from this contract and then invest through Yearn 
    */
    function StartEsusuCycle(uint esusuCycleId, address owner) external {
        
        //  If cycle ID is valid, else bonunce
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        require(cycle.CycleState == CycleStateEnum.Idle, "Cycle can only be started when in Idle state");
        
        require(cycle.Owner == owner, "Only owner of this Esusu Can start this cycle");
        
        EsusuCycleMapping[esusuCycleId].CycleState = CycleStateEnum.Active;
        
        //  Calculate Cycle LifeTime in milliseconds
        EsusuCycleMapping[esusuCycleId].TotalCycleDuration = EsusuCycleMapping[esusuCycleId].PayoutIntervalMilliSeconds * EsusuCycleMapping[esusuCycleId].TotalMembers;
        
        //  Set the Cycle start time 
        EsusuCycleMapping[esusuCycleId].CycleStartTime = now;
        
        //  Get all the dai from this contract : TODO we might change the storage of dai deposits to another address or contract
        uint esusuCycleBalance = dai.balanceOf(address(this));
        
        //  Invest the dai in Yearn Finance : TODO call xend finance yearn contract to save
    }
    
    /*
        This function performs sends all ROI generated within an Esusu Cycle Payout Interval to a particular member
        
        
    
    */
    function WithdrawFromEsusuCycle(uint esusuCycleId, address member) external {
        
    }
    
    /*
        This function checks whether the user can withdraw at the time at which the user is making this call
        
        - Check if cycle is valid 
        - Check if cycle is in active state
        - Check if member is in cycle 
        - Calculate member withdrawal time
        - Check if member can withdraw at this time
    */
    function IsMemberEligibleToWithdraw(uint esusuCycleId, address member) external view returns(bool){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        require(cycle.CycleState == CycleStateEnum.Active, "Cycle must be in active state");
        
        require(_isMemberInCycle(member,esusuCycleId), "Member is not in this cycle");
        
        uint memberWithdrawalTime = _calculateMemberWithdrawalTime(cycle,member);
        
        if(now > memberWithdrawalTime){
            return true;

        }else{
            return false;
        }
        
    }
    
    function GetBalance(address member) external view returns(uint){
        return dai.balanceOf(member);
    }
    
    /*
        This function returns the Withdrawal time for a member in milliseconds
        
        Parameters
        - Wt    -> Withdrawal Time for a member 
        - To    -> Cycle Start Time
        - Mpos  -> Member Position in the Cycle 
        - Ct     -> Cycle Time Interval in milliseconds
        
        Equation
        Wt = (To + (Mpos * Ct))
    */
    
    function _calculateMemberWithdrawalTime(EsusuCycle memory cycle, address member) internal view returns(uint){
        
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[cycle.CycleId];
        
        uint memberPosition = memberPositionMapping[member];
        
        uint withdrawalTime = (cycle.CycleStartTime + (memberPosition.mul(cycle.PayoutIntervalMilliSeconds)));
        
        return withdrawalTime;
    }
    
    function GetCurrentEsusuCycleId() external view returns(uint){
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
}

