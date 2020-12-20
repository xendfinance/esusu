
pragma solidity >=0.6.6;

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
        uint256 CycleId;
        uint256 GroupId;                   //  Group this Esusu Cycle belongs to
        uint256 DepositAmount;
        uint256 TotalMembers;
        uint256 TotalBeneficiaries;        //  This is the total number of members that have withdrawn their ROI 
        uint256 PayoutIntervalSeconds;     //  Time each member receives overall ROI within one Esusu Cycle in seconds
        uint256 TotalCycleDuration;        //  The total time it will take for all users to be paid which is (number of members * payout interval)
        uint256 TotalAmountDeposited;      // Total  Dai Deposited
        uint256 TotalCapitalWithdrawn;     // Total Capital In Dai Withdrawn
        uint256 CycleStartTime;            //  Time, when the cycle starts has elapsed. Anyone can start cycle after this time has elapsed
        uint256 TotalShares;               //  Total yDai Shares 
        uint256 MaxMembers;                //  Maximum number of members that can join this esusu cycle
        address Owner;                  //  This is the creator of the cycle who is also the creator of the group
        CurrencyEnum Currency;          //  Currency supported in this Esusu Cycle 
        CycleStateEnum CycleState;      //  The current state of the Esusu Cycle
    }
    
    struct MemberCycle{
        uint256 CycleId;
        address MemberId;
        uint256 TotalAmountDepositedInCycle;
        uint256 TotalPayoutReceivedInCycle;
    }
    
        /*  Model definition starts */

    /* Model definition ends */
    
    //  Member variables
    address _owner;

    uint256 EsusuCycleId;
    

    mapping(uint256 => EsusuCycle) EsusuCycleMapping;
    

    mapping(address=>mapping(uint=>MemberCycle)) MemberAddressToMemberCycleMapping;

    mapping(uint=>mapping(address=>uint)) CycleToMemberPositionMapping;   //  This tracks position of the  member in an Esusu Cycle

    mapping(uint=>mapping(address=> uint)) CycleToBeneficiaryMapping;  // This tracks members that have received overall ROI and amount received within an Esusu Cycle
    
    mapping(uint=>mapping(address=> uint)) CycleToMemberWithdrawnCapitalMapping;    // This tracks members that have withdrawn their capital and the amount withdrawn 
    
    uint256 TotalDeposits; //  This holds all the dai amounts users have deposited in this contract
    
    
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
    
    function CreateEsusuCycleMapping(uint256 groupId, uint256 depositAmount, uint256 payoutIntervalSeconds,uint256 startTimeInSeconds, address owner, uint256 maxMembers) external onlyOwnerAdapterAndAdapterDelegateContract {
        
        EsusuCycleId += 1;
        EsusuCycle storage cycle = EsusuCycleMapping[EsusuCycleId];

        cycle.CycleId = EsusuCycleId;
        cycle.DepositAmount = depositAmount;
        cycle.PayoutIntervalSeconds = payoutIntervalSeconds;
        cycle.Currency = CurrencyEnum.Dai;
        cycle.CycleState = CycleStateEnum.Idle; 
        cycle.Owner = owner;
        cycle.MaxMembers = maxMembers;
        
        
        //  Set the Cycle start time 
        cycle.CycleStartTime = startTimeInSeconds;

         //  Assign groupId
        cycle.GroupId = groupId;
    }
    
    function GetEsusuCycle(uint256 esusuCycleId) external view returns(uint256 CycleId, uint256 DepositAmount, 
                                                            uint256 PayoutIntervalSeconds, uint256 CycleState, 
                                                            uint256 TotalMembers, uint256 TotalAmountDeposited, uint256 TotalShares, 
                                                            uint256 TotalCycleDurationInSeconds, uint256 TotalCapitalWithdrawn, uint256 CycleStartTimeInSeconds,
                                                            uint256 TotalBeneficiaries, uint256 MaxMembers){
        
        require(esusuCycleId != 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleId, cycle.DepositAmount,  cycle.PayoutIntervalSeconds, 
                uint256(cycle.CycleState),
                cycle.TotalMembers, cycle.TotalAmountDeposited, cycle.TotalShares,
                cycle.TotalCycleDuration, cycle.TotalCapitalWithdrawn, cycle.CycleStartTime,
                cycle.TotalBeneficiaries, cycle.MaxMembers);
        
    }
    
    
    function GetEsusuCycleBasicInformation(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 CycleId, uint256 DepositAmount, uint256 CycleState,uint256 TotalMembers,uint256 MaxMembers, uint256 PayoutIntervalSeconds, uint256 GroupId){
                
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleId, cycle.DepositAmount, 
                uint256(cycle.CycleState),
                cycle.TotalMembers, cycle.MaxMembers, cycle.PayoutIntervalSeconds, cycle.GroupId);
        
    } 
    
    
    function GetEsusuCycleTotalShares(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 TotalShares){
                        
        return (EsusuCycleMapping[esusuCycleId].TotalShares);
    }                                                        

    function GetEsusuCycleStartTime(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleStartTime){
                         
        return (EsusuCycleMapping[esusuCycleId].CycleStartTime);      
    }
    
    
    function GetEsusuCyclePayoutInterval(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCyclePayoutInterval){
                         
        return (EsusuCycleMapping[esusuCycleId].PayoutIntervalSeconds);      
    }
    
    function GetEsusuCycleTotalAmountDeposited(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleTotalAmountDeposited){
                        
        return (EsusuCycleMapping[esusuCycleId].TotalAmountDeposited);      
    }
    
    function GetCycleOwner(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(address EsusuCycleOwner){
                        
        return (EsusuCycleMapping[esusuCycleId].Owner);
        
    }
    
    function GetEsusuCycleDuration(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleDuration){
        
        return (EsusuCycleMapping[esusuCycleId].TotalCycleDuration);    
    }
    
    function GetEsusuCycleTotalCapitalWithdrawn(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleTotalCapitalWithdrawn){
                        
        return (EsusuCycleMapping[esusuCycleId].TotalCapitalWithdrawn);       
    }
    function GetEsusuCycleTotalBeneficiaries(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 EsusuCycleTotalBeneficiaries){
                        
        return (EsusuCycleMapping[esusuCycleId].TotalBeneficiaries);       
    }
    function GetMemberWithdrawnCapitalInEsusuCycle(uint256 esusuCycleId,address memberAddress) external view returns (uint) {
                        
        return CycleToMemberWithdrawnCapitalMapping[esusuCycleId][memberAddress];
    }
    
    function GetMemberCycleToBeneficiaryMapping(uint256 esusuCycleId,address memberAddress) external view returns(uint){
        
        return CycleToBeneficiaryMapping[esusuCycleId][memberAddress];
    }
    
    function GetTotalMembersInCycle(uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 TotalMembers){
                         
        return (EsusuCycleMapping[esusuCycleId].TotalMembers);      
    }

    function IsMemberInCycle(address memberAddress,uint256 esusuCycleId ) external view returns(bool){
        return MemberAddressToMemberCycleMapping[memberAddress][esusuCycleId].CycleId > 0;
    }
    
    function IncreaseTotalAmountDepositedInCycle(uint256 esusuCycleId, uint256 amount) isCycleIdValid(esusuCycleId) external onlyOwnerAdapterAndAdapterDelegateContract returns (uint){
    
        uint256 amountDeposited = EsusuCycleMapping[esusuCycleId].TotalAmountDeposited.add(amount);

        EsusuCycleMapping[esusuCycleId].TotalAmountDeposited =  amountDeposited;
        
        return amountDeposited;
    }
    
    function CreateMemberAddressToMemberCycleMapping(address member,uint256 esusuCycleId ) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        //  Increment the total deposited amount for the member cycle struct
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[member];
        
        memberCycleMapping[esusuCycleId].CycleId = esusuCycleId;
        memberCycleMapping[esusuCycleId].MemberId = member;
        memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle = memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle.add( EsusuCycleMapping[esusuCycleId].DepositAmount);        
    }
    
    function IncreaseTotalMembersInCycle(uint256 esusuCycleId) external onlyOwnerAdapterAndAdapterDelegateContract{
        //  Increase TotalMembers count by 1

        EsusuCycleMapping[esusuCycleId].TotalMembers +=1;
    }
    
    function CreateMemberPositionMapping(uint256 esusuCycleId, address member) onlyOwnerAdapterAndAdapterDelegateContract external{
        
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[esusuCycleId];
        
        //  Assign Position to Member In this Cycle
        memberPositionMapping[member] = EsusuCycleMapping[esusuCycleId].TotalMembers;
    }
    
    function IncreaseTotalDeposits(uint256 esusuCycleBalance) external onlyOwnerAdapterAndAdapterDelegateContract {
        
        TotalDeposits = TotalDeposits.add(esusuCycleBalance);
       
    }
    
    function UpdateEsusuCycleDuringStart(uint256 esusuCycleId,uint256 cycleStateEnum, uint256 toalCycleDuration, uint256 totalShares,uint256 currentTime) external onlyOwnerAdapterAndAdapterDelegateContract{
       
        EsusuCycle storage cycle = EsusuCycleMapping[esusuCycleId];

        cycle.TotalCycleDuration = toalCycleDuration;
        cycle.CycleState = CycleStateEnum(cycleStateEnum); 
        cycle.TotalShares = totalShares;
        cycle.CycleStartTime = currentTime;
        
    }
    
    function UpdateEsusuCycleState(uint256 esusuCycleId,uint256 cycleStateEnum) external onlyOwnerAdapterAndAdapterDelegateContract{
       
        EsusuCycleMapping[esusuCycleId].CycleState = CycleStateEnum(cycleStateEnum); 
        
    }
    function GetMemberCycleInfo(address memberAddress, uint256 esusuCycleId) isCycleIdValid(esusuCycleId) external view returns(uint256 CycleId, address MemberId, uint256 TotalAmountDepositedInCycle, uint256 TotalPayoutReceivedInCycle, uint256 memberPosition){
                
        mapping(uint=>MemberCycle) storage memberCycleMapping =  MemberAddressToMemberCycleMapping[memberAddress];
        
        mapping(address=>uint) storage memberPositionMapping =  CycleToMemberPositionMapping[esusuCycleId];
        
        //  Get Number(Position) of Member In this Cycle
        uint256 memberPos = memberPositionMapping[memberAddress];
        
        return  (memberCycleMapping[esusuCycleId].CycleId,memberCycleMapping[esusuCycleId].MemberId,
        memberCycleMapping[esusuCycleId].TotalAmountDepositedInCycle,
        memberCycleMapping[esusuCycleId].TotalPayoutReceivedInCycle,memberPos);
    }
    
    function CreateMemberCapitalMapping(uint256 esusuCycleId, address member) external onlyOwnerAdapterAndAdapterDelegateContract {
         
        mapping(address=>uint) storage memberCapitalMapping =  CycleToMemberWithdrawnCapitalMapping[esusuCycleId];
        memberCapitalMapping[member] = EsusuCycleMapping[esusuCycleId].DepositAmount;
    }
    
    function UpdateEsusuCycleDuringCapitalWithdrawal(uint256 esusuCycleId, uint256 cycleTotalShares, uint256 totalCapitalWithdrawnInCycle) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        EsusuCycleMapping[esusuCycleId].TotalCapitalWithdrawn = totalCapitalWithdrawnInCycle; 
        EsusuCycleMapping[esusuCycleId].TotalShares = cycleTotalShares;
    }
    
    function UpdateEsusuCycleDuringROIWithdrawal(uint256 esusuCycleId, uint256 totalShares, uint256 totalBeneficiaries) external onlyOwnerAdapterAndAdapterDelegateContract{
        EsusuCycleMapping[esusuCycleId].TotalBeneficiaries = totalBeneficiaries; 
        EsusuCycleMapping[esusuCycleId].TotalShares = totalShares;        
    }
    
    function CreateEsusuCycleToBeneficiaryMapping(uint256 esusuCycleId, address memberAddress, uint256 memberROINet) external onlyOwnerAdapterAndAdapterDelegateContract{
        
        mapping(address=>uint) storage beneficiaryMapping =  CycleToBeneficiaryMapping[esusuCycleId];
        
        beneficiaryMapping[memberAddress] = memberROINet;
    }

    function CalculateMemberWithdrawalTime(uint256 cycleId, address member) external view returns(uint256 withdrawalTime){

        mapping(address=>uint) storage memberPositionMapping = CycleToMemberPositionMapping[cycleId];

        uint256 memberPosition = memberPositionMapping[member];

        withdrawalTime = (EsusuCycleMapping[cycleId].CycleStartTime.add(memberPosition.mul(EsusuCycleMapping[cycleId].PayoutIntervalSeconds)));
        return withdrawalTime;
    }
    
    function GetTotalDeposits() external view returns (uint){
        return TotalDeposits;
    }
    
    function GetEsusuCycleState(uint256 esusuCycleId) external view returns (uint){
        
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

    modifier isCycleIdValid(uint256 esusuCycleId) {

        require(esusuCycleId != 0 && esusuCycleId <= EsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        _;
    }
    
}