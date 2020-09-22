pragma solidity ^0.6.6;

import "./EsusuAdapter.sol";



contract DaiLendingService{
    
    address _owner;
    EsusuAdapter _esusuAdapter;
    
    
    mapping(address => uint) userDaiDeposits;   

    constructor() public {
        _owner = msg.sender;
    }
    
    function TransferOwnership(address account) onlyOwner() external{
        _owner = account;
    }
    
    function UpdateAdapter(address adapterAddress) onlyOwner() external{
        _esusuAdapter = EsusuAdapter(adapterAddress);   
    }
    
    
    function GetEsusuAdapterAddress() external view returns (address){
        return address(_esusuAdapter);
    }
    
    
    function CreateEsusu(uint depositAmount, uint payoutIntervalSeconds) external {
        
        _esusuAdapter.CreateEsusu(depositAmount,payoutIntervalSeconds,msg.sender);
    }
    
    /*
        NOTE: member must approve _esusuAdapter to transfer deposit amount on his/her behalf
    */
    function JoinEsusu(uint esusuCycleId, address member) external {
        _esusuAdapter.JoinEsusu(esusuCycleId,member);
    }
    
    
    /*
        This function returns information about a member in an esusu Cycle 
    */
    function GetMemberCycleInfo(address memberAddress, uint esusuCycleId) 
                                external view returns(uint CycleId, address MemberId, uint TotalAmountDepositedInCycle, 
                                uint TotalPayoutReceivedInCycle, uint memberPosition){
        
        return _esusuAdapter.GetMemberCycleInfo(memberAddress,esusuCycleId);
    }
    
     function GetEsusuCycle(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount, 
                                                            uint PayoutIntervalSeconds, uint CycleState, address Owner, 
                                                            uint TotalMembers, uint TotalAmountDeposited, uint TotalShares, 
                                                            uint TotalCycleDurationInSeconds, uint TotalCapitalWithdrawn, uint CycleStartTimeInSeconds,
                                                            uint TotalBeneficiaries){
    
        return _esusuAdapter.GetEsusuCycle(esusuCycleId);                                                        
    }
    
    function StartEsusuCycle(uint esusuCycleId) external {
        _esusuAdapter.StartEsusuCycle(esusuCycleId,msg.sender);
    }
    
    function WithdrawROIFromEsusuCycle(uint esusuCycleId) external{
        _esusuAdapter.WithdrawROIFromEsusuCycle(esusuCycleId,msg.sender);
    }
    
    function WithdrawCapitalFromEsusuCycle(uint esusuCycleId) external{
        _esusuAdapter.WithdrawCapitalFromEsusuCycle(esusuCycleId,msg.sender);
    }
    
    function IsMemberEligibleToWithdrawROI(uint esusuCycleId, address member) external view returns(bool){
        _esusuAdapter.IsMemberEligibleToWithdrawROI(esusuCycleId,member);
    }
    
    function IsMemberEligibleToWithdrawCapital(uint esusuCycleId, address member) public view returns(bool){
        _esusuAdapter.IsMemberEligibleToWithdrawCapital(esusuCycleId,member);
    }
    
    function GetCurrentEsusuCycleId() external view returns(uint){
        return _esusuAdapter.GetCurrentEsusuCycleId();
    }
    modifier onlyOwner(){
        require(_owner == msg.sender, "Only owner can make this call");
        _;
    }
    
    
}