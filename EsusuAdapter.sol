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
    
    enum TimeUnitEnum{
        Hour, Day, Week, Year
    }
    
    /*  Struct Definitions */
    struct EsusuCycle{
        uint CycleId;
        uint DepositAmount;
        uint TotalMembers;
        address Owner;
        uint PayoutInterval;    //  Time each member receives overall ROI within one Esusu Cycle
        TimeUnitEnum PayoutTimeIntervalUnit;  //  
        uint CycleDuration; //  The total time it will take for all users to be paid which is (number of members * payout interval)
        CurrencyEnum Currency;  //  Currency supported in this Esusu Cycle 
        string CurrencySymbol;
        CycleStateEnum CycleState;  //  The current state of the Esusu Cycle
        uint256 TotalAmountDeposited;
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

    function CreateEsusu(uint depositAmount, uint payoutTimeIntervalUnit, uint payoutInterval) external {
        
        EsusuCycle memory cycle;
        cycle.DepositAmount = depositAmount;
        cycle.PayoutTimeIntervalUnit = TimeUnitEnum(payoutTimeIntervalUnit);
        cycle.PayoutInterval = payoutInterval;
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
                                                            uint PayoutTimeIntervalUnit, uint PayoutInterval, uint Currency, 
                                                            string memory CurrencySymbol, uint CycleState, address Owner, uint TotalMembers ){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleId, cycle.DepositAmount, uint256(cycle.PayoutTimeIntervalUnit),  cycle.PayoutInterval, 
                uint256(cycle.Currency),cycle.CurrencySymbol,uint256(cycle.CycleState), cycle.Owner,cycle.TotalMembers);
        
    }
    
    /*
        - Check if the Id is a valid ID
        - Check if the cycle is in Idle State
        - Only owner of a cycle can start that cycle - TODO: Change this function to public so it can be called from another contract
    */
    function StartEsusuCycle(uint esusuCycleId, address owner) external {
        
        //  If cycle ID is valid, else bonunce
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        require(cycle.CycleState == CycleStateEnum.Idle, "Cycle can only be started when in Idle state");
        
        require(cycle.Owner == owner, "Only owner of this Esusu Can start this cycle");
        
        EsusuCycleMapping[esusuCycleId].CycleState = CycleStateEnum.Active;
        
        //
    }
    
    function GetBalance(address member) external view returns(uint){
        return dai.balanceOf(member);
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

