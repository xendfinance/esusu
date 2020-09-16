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
        mapping(address=>Member) Members;
        address Owner;
        uint PayoutInterval;    //  Time each member receives overall ROI within one Esusu Cycle
        TimeUnitEnum PayoutTimeIntervalUnit;  //  
        uint CycleDuration; //  The total time it will take for all users to be paid which is (number of members * payout interval)
        mapping(address=> Member) Beneficiary;  // Members that have received overall ROI within one Esusu Cycle
        CurrencyEnum Currency;  //  Currency supported in this Esusu Cycle 
        string ProtocolKey;
        string CurrencySymbol;
        CycleStateEnum CycleState;  //  The current state of the Esusu Cycle
        uint DepositWindow; //  Time each cycle will be in the Idle State for people to be able to make their deposits
        TimeUnitEnum DepositWindowUnit;    
        uint256 TotalAmountDeposited;
    }
    
    struct Member{
        address MemberId;
        uint Balance;
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

    function CreateEsusu(uint depositAmount, uint payoutTimeIntervalUnit, uint payoutInterval, uint currency, uint depositWindow, uint depositWindowUnit ) external {
        
        EsusuCycle memory cycle;
        cycle.DepositAmount = depositAmount;
        cycle.PayoutTimeIntervalUnit = TimeUnitEnum(payoutTimeIntervalUnit);
        cycle.PayoutInterval = payoutInterval;
        cycle.Currency = CurrencyEnum(currency);
        cycle.CurrencySymbol = Dai;
        cycle.CycleState = CycleStateEnum.Idle; 
        cycle.DepositWindow = depositWindow;
        cycle.DepositWindowUnit = TimeUnitEnum(depositWindowUnit);
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
        1. Check if the cycle ID is valid
        2. Check if the cycle is in Idle state, that is the only state a member can join
        3. Check if we are within the deposit window
        4. Check if member is already in Cycle
        4. Ensure member has approved this contract to transfer the token on his/her behalf
        5. If member has enough balance, transfer the tokens to this contract else bounce
        6. Increment the total deposited amount in this cycle and total deposited amount for the member cycle struct 
    */
    function JoinEsusu(uint esusuCycleId, address member)external {
        
        //  If cycle ID is 0, bonunce
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");

        //  If cycle is not in Idle State, bounce 
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        require(cycle.CycleState == CycleStateEnum.Idle, "Esusu Cycle must be in Idle State before you can join");
        
        //  TODO: check if we are within deposit window
        //  TODO: check if member is already in this cycle 
        
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
        
        // uint CycleId;
        // address MemberId;
        // uint TotalAmountDepositedInCycle;
        // uint TotalPayoutReceivedInCycle;
        memberCycleMapping[esusuCycleId].CycleId = esusuCycleId;
        memberCycleMapping[esusuCycleId].MemberId = member;
        memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle = memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle.add(cycle.DepositAmount);
        memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle = memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle.add(0);
        
        
    }
    
    function GetMemberCycleInfo(address memberAddress, uint esusuCycleId) external view returns(uint CycleId, address MemberId, uint TotalAmountDepositedInCycle, uint TotalPayoutReceivedInCycle){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[memberAddress];
        
        return(memberCycleMapping[esusuCycleId].CycleId,memberCycleMapping[esusuCycleId].MemberId,memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle,memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle);
    }

    function GetEsusuCycle(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount, 
                                                            uint PayoutTimeIntervalUnit, uint PayoutInterval, uint Currency, 
                                                            string memory CurrencySymbol, uint CycleState, uint DepositWindow, uint  DepositWindowUnit, address Onwer ){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleId, cycle.DepositAmount, uint256(cycle.PayoutTimeIntervalUnit),  cycle.PayoutInterval, uint256(cycle.Currency),cycle.CurrencySymbol,uint256(cycle.CycleState), cycle.DepositWindow,uint256(cycle.DepositWindowUnit), cycle.Owner  );
        
    }
    
    
    function GetBalance(address member) external view returns(uint){
        return dai.balanceOf(member);
    }
    
    function GetCurrentEsusuCycleId() external view returns(uint){
        return EsusuCycleId;
    }
    
}

