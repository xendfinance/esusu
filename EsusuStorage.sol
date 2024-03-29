
pragma solidity ^0.6.6;

import "./SafeMath.sol";


contract EsusuStorage {
    
    using SafeMath for uint256;

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
        uint GroupId;                   //  Group this Esusu Cycle belongs to
        uint DepositAmount;
        uint TotalMembers;
        uint TotalBeneficiaries;        //  This is the total number of members that have withdrawn their ROI 
        address Owner;                  //  This is the creator of the cycle who is also the creator of the group
        uint PayoutIntervalSeconds;     //  Time each member receives overall ROI within one Esusu Cycle in seconds
        uint TotalCycleDuration;        //  The total time it will take for all users to be paid which is (number of members * payout interval)
        CurrencyEnum Currency;          //  Currency supported in this Esusu Cycle 
        CycleStateEnum CycleState;      //  The current state of the Esusu Cycle
        uint TotalAmountDeposited;   // Total  Dai Deposited
        uint TotalCapitalWithdrawn;     // Total Capital In Dai Withdrawn
        uint CycleStartTime;            //  Time which the cycle will start when it has elapsed. Anyone can start cycle after this time has elapsed
        uint TotalShares;               //  Total yDai Shares 
        uint MaxMembers;                //  Maximum number of members that can join this esusu cycle
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
    
        /*  Model definition starts */
    string Dai = "Dai Stablecoin";


    /* Model definition ends */
    
    //  Member variables
    address _owner;

    string _feeRuleKey;

    uint EsusuCycleId = 0;
    

    mapping(uint => EsusuCycle) EsusuCycleMapping;
    

    mapping(address=>mapping(uint=>MemberCycle)) MemberAddressToMemberCycleMapping;

    mapping(uint=>mapping(address=>uint)) CycleToMemberPositionMapping;   //  This tracks position of the  member in an Esusu Cycle

    mapping(uint=>mapping(address=> uint)) CycleToBeneficiaryMapping;  // This tracks members that have received overall ROI and amount received within an Esusu Cycle
    
    mapping(uint=>mapping(address=> uint)) CycleToMemberWithdrawnCapitalMapping;    // This tracks members that have withdrawn their capital and the amount withdrawn 
    
    uint TotalDeposits; //  This holds all the dai amounts users have deposited in this contract
    
    
    address  _adapterContract;
    address _adapterDelegateContract;
    
    constructor () public {
        _owner = msg.sender;
    }
    
    function UpdateAdapterAndAdapterDelegateAddresses(address adapterContract, address adapterDelegateContract) onlyOwner external {
            _adapterContract = adapterContract;
            _adapterDelegateContract = adapterDelegateContract;
    }
        
    function GetEsusuCycleId() external view returns (uint){
        return EsusuCycleId;
    }
    
    function IncrementEsusuCycleId() external onlyOwnerAdapterAndAdapterDelegateContract {
        EsusuCycleId += 1;
    }
    
    function CreateEsusuCycleMapping(uint groupId, uint depositAmount, uint payoutIntervalSeconds,uint startTimeInSeconds, address owner, uint maxMembers) external onlyOwnerAdapterAndAdapterDelegateContract {
        
        EsusuCycleId += 1;

        EsusuCycleMapping[EsusuCycleId].CycleId = EsusuCycleId;
        EsusuCycleMapping[EsusuCycleId].DepositAmount = depositAmount;
        EsusuCycleMapping[EsusuCycleId].PayoutIntervalSeconds = payoutIntervalSeconds;
        EsusuCycleMapping[EsusuCycleId].Currency = CurrencyEnum.Dai;
        EsusuCycleMapping[EsusuCycleId].CycleState = CycleStateEnum.Idle; 
        EsusuCycleMapping[EsusuCycleId].Owner = owner;
        EsusuCycleMapping[EsusuCycleId].MaxMembers = maxMembers;
        
        
        //  Set the Cycle start time 
        EsusuCycleMapping[EsusuCycleId].CycleStartTime = startTimeInSeconds;

         //  Assign groupId
        EsusuCycleMapping[EsusuCycleId].GroupId = groupId;
    }
    
    function GetEsusuCycle(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount, 
                                                            uint PayoutIntervalSeconds, uint CycleState, 
                                                            uint TotalMembers, uint TotalAmountDeposited, uint TotalShares, 
                                                            uint TotalCycleDurationInSeconds, uint TotalCapitalWithdrawn, uint CycleStartTimeInSeconds,
                                                            uint TotalBeneficiaries, uint MaxMembers){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleId, cycle.DepositAmount,  cycle.PayoutIntervalSeconds, 
                uint256(cycle.CycleState),
                cycle.TotalMembers, cycle.TotalAmountDeposited, cycle.TotalShares,
                cycle.TotalCycleDuration, cycle.TotalCapitalWithdrawn, cycle.CycleStartTime,
                cycle.TotalBeneficiaries, cycle.MaxMembers);
        
    }
    
    
    function GetEsusuCycleBasicInformation(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount, uint CycleState,uint TotalMembers,uint MaxMembers){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleId, cycle.DepositAmount, 
                uint256(cycle.CycleState),
                cycle.TotalMembers, cycle.MaxMembers);
        
    } 
    
    function GetEsusuCycleTotalShares(uint esusuCycleId) external view returns(uint TotalShares){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.TotalShares);
    }                                                        

    function GetEsusuCycleStartTime(uint esusuCycleId)external view returns(uint EsusuCycleStartTime){
         
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleStartTime);      
    }
    
    
    function GetEsusuCyclePayoutInterval(uint esusuCycleId)external view returns(uint EsusuCyclePayoutInterval){
         
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.PayoutIntervalSeconds);      
    }
    
    function GetEsusuCycleTotalAmountDeposited(uint esusuCycleId)external view returns(uint EsusuCycleTotalAmountDeposited){
         
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.TotalAmountDeposited);      
    }
    
    function GetCycleOwner(uint esusuCycleId)external view returns(address EsusuCycleOwner){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.Owner);
        
    }
    
    function GetEsusuCycleDuration(uint esusuCycleId)external view returns(uint EsusuCycleDuration){
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.TotalCycleDuration);    
    }
    
    function GetEsusuCycleTotalCapitalWithdrawn(uint esusuCycleId)external view returns(uint EsusuCycleTotalCapitalWithdrawn){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.TotalCapitalWithdrawn);       
    }
    function GetEsusuCycleTotalBeneficiaries(uint esusuCycleId)external view returns(uint EsusuCycleTotalBeneficiaries){
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.TotalBeneficiaries);       
    }
    function GetMemberWithdrawnCapitalInEsusuCycle(uint esusuCycleId,address memberAddress) external view returns (uint) {
        
        mapping(address=>uint) storage memberWithdrawnCapitalMapping =  CycleToMemberWithdrawnCapitalMapping[esusuCycleId];
        
        uint amount = memberWithdrawnCapitalMapping[memberAddress];
        
        return amount;
    }
    
    function GetMemberCycleToBeneficiaryMapping(uint esusuCycleId,address memberAddress) external view returns(uint){
        
        mapping(address=>uint) storage beneficiaryMapping =  CycleToBeneficiaryMapping[esusuCycleId];
        
        uint amount = beneficiaryMapping[memberAddress];
        
        return amount;
    }
    
    function IsMemberInCycle(address memberAddress,uint esusuCycleId ) external view returns(bool){
        
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[memberAddress];
        
        //  If member is in cycle, the cycle ID should be greater than 0
        if(memberCycleMapping[esusuCycleId].CycleId > 0){
            
            return true;
        }else{
            return false;
        }
    }
    
    function IncreaseTotalAmountDepositedInCycle(uint esusuCycleId, uint amount) external onlyOwnerAdapterAndAdapterDelegateContract returns (uint){
    
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");

        EsusuCycleMapping[esusuCycleId].TotalAmountDeposited =  EsusuCycleMapping[esusuCycleId].TotalAmountDeposited.add(amount);
        
        return EsusuCycleMapping[esusuCycleId].TotalAmountDeposited;
    }
    
    function CreateMemberAddressToMemberCycleMapping(address member,uint esusuCycleId ) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        require(esusuCycleId > 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");

        //  Increment the total deposited amount for the member cycle struct
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[member];
        

        memberCycleMapping[esusuCycleId].CycleId = esusuCycleId;
        memberCycleMapping[esusuCycleId].MemberId = member;
        memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle = memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle.add( EsusuCycleMapping[esusuCycleId].DepositAmount);
        memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle = memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle.add(0);
        
    }
    
    function IncreaseTotalMembersInCycle(uint esusuCycleId) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        
        //  Increase TotalMembers count by 1

        EsusuCycleMapping[esusuCycleId].TotalMembers +=1;
    }
    
    function CreateMemberPositionMapping(uint esusuCycleId, address member) onlyOwnerAdapterAndAdapterDelegateContract external{
        
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[esusuCycleId];
        
        //  Assign Position to Member In this Cycle
        memberPositionMapping[member] = EsusuCycleMapping[esusuCycleId].TotalMembers;
    }
    
    function IncreaseTotalDeposits(uint esusuCycleBalance) external onlyOwnerAdapterAndAdapterDelegateContract {
        
        TotalDeposits = TotalDeposits.add(esusuCycleBalance);
       
    }
    
    function UpdateEsusuCycleDuringStart(uint esusuCycleId,uint cycleStateEnum, uint toalCycleDuration, uint totalShares,uint currentTime) external onlyOwnerAdapterAndAdapterDelegateContract{
       
        EsusuCycleMapping[esusuCycleId].TotalCycleDuration = toalCycleDuration;
        EsusuCycleMapping[esusuCycleId].CycleState = CycleStateEnum(cycleStateEnum); 
        EsusuCycleMapping[esusuCycleId].TotalShares = totalShares;
        EsusuCycleMapping[esusuCycleId].CycleStartTime = currentTime;
        
    }
    
    function UpdateEsusuCycleState(uint esusuCycleId,uint cycleStateEnum) external onlyOwnerAdapterAndAdapterDelegateContract{
       
        EsusuCycleMapping[esusuCycleId].CycleState = CycleStateEnum(cycleStateEnum); 
        
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
    
    function CreateMemberCapitalMapping(uint esusuCycleId, address member) external onlyOwnerAdapterAndAdapterDelegateContract {
         
        mapping(address=>uint) storage memberCapitalMapping =  CycleToMemberWithdrawnCapitalMapping[esusuCycleId];
        memberCapitalMapping[member] = EsusuCycleMapping[esusuCycleId].DepositAmount;
    }
    
    function UpdateEsusuCycleDuringCapitalWithdrawal(uint esusuCycleId, uint cycleTotalShares, uint totalCapitalWithdrawnInCycle) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        EsusuCycleMapping[esusuCycleId].TotalCapitalWithdrawn = totalCapitalWithdrawnInCycle; 
        EsusuCycleMapping[esusuCycleId].TotalShares = cycleTotalShares;
    }
    
    function UpdateEsusuCycleDuringROIWithdrawal(uint esusuCycleId, uint totalShares, uint totalBeneficiaries) external onlyOwnerAdapterAndAdapterDelegateContract{
        EsusuCycleMapping[esusuCycleId].TotalBeneficiaries = totalBeneficiaries; 
        EsusuCycleMapping[esusuCycleId].TotalShares = totalShares;        
    }
    
    function CreateEsusuCycleToBeneficiaryMapping(uint esusuCycleId, address memberAddress, uint memberROINet) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        mapping(address=>uint) storage beneficiaryMapping =  CycleToBeneficiaryMapping[esusuCycleId];
        
        beneficiaryMapping[memberAddress] = memberROINet;
    }
    
    function CalculateMemberWithdrawalTime(uint cycleId, address member) external view returns(uint){
      
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[cycleId];
        
        uint memberPosition = memberPositionMapping[member];
        
        uint withdrawalTime = (EsusuCycleMapping[cycleId].CycleStartTime.add(memberPosition.mul(EsusuCycleMapping[cycleId].PayoutIntervalSeconds)));
        
        return withdrawalTime;
    }
    
    function GetTotalDeposits() external view returns (uint){
        return TotalDeposits;
    }
    
    function GetEsusuCycleState(uint esusuCycleId) external view returns (uint){
        
        return uint(EsusuCycleMapping[esusuCycleId].CycleState);
        
    }
    
    modifier onlyOwner() {
        require(msg.sender == _owner, "Unauthorized access to contract");
        _;
    }
    
    modifier onlyOwnerAdapterAndAdapterDelegateContract() {
        require(
            msg.sender == _owner || msg.sender == _adapterDelegateContract || msg.sender == _adapterContract,
            "Unauthorized access to contract"
        );
        _;
    }
    
}