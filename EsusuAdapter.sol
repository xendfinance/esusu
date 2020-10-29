pragma solidity ^0.6.6;

import "./IDaiToken.sol";
import "./IYDaiToken.sol";

import "./IDaiLendingService.sol";
import "./OwnableService.sol";

import "./ISavingsConfig.sol";
import "./ISavingsConfigSchema.sol";
import "./IGroups.sol";
import "./SafeMath.sol";
import "./IEsusuStorage.sol";


contract EsusuAdapter is OwnableService, ISavingsConfigSchema {

    /*
        Events to emit 
        1. Creation of Esusu Cycle 
        2. Joining of Esusu Cycle 
        3. Starting of Esusu Cycle 
        4. Withdrawal of ROI
        5. Withdrawal of Capital
    */
    event CreateEsusuCycleEvent
    (
        uint date,
        uint indexed cycleId,
        uint depositAmount,
        address  Owner,
        uint payoutIntervalSeconds,
        CurrencyEnum currency,
        string currencySymbol,
        uint cycleState
    );
    
    event DepricateContractEvent(
        
        uint date,
        address owner, 
        string reason,
        uint yDaiSharesTransfered
    );
    event JoinEsusuCycleEvent
    (
        uint date,
        address indexed member,   
        uint memberPosition,
        uint totalAmountDeposited,
        uint cycleId
    );
    
    event StartEsusuCycleEvent
    (
        uint date,
        uint totalAmountDeposited,
        uint totalCycleDuration,
        uint totalShares,
        uint indexed cycleId
    );
    

    
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

    
        /*  Model definition starts */
    string Dai = "Dai Stablecoin";


    /* Model definition ends */
    
    //  Member variables
    address _owner;
    ISavingsConfig _savingsConfigContract;
    IGroups _groupsContract;

    IDaiLendingService _iDaiLendingService;
    IDaiToken _dai = IDaiToken(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IYDaiToken _yDai = IYDaiToken(0xC2cB1040220768554cf699b0d863A3cd4324ce32);
    IEsusuStorage _esusuStorage;
    address  _delegateContract;
    bool _isActive = true;
    
    using SafeMath for uint256;

    constructor (address payable serviceContract, address savingsConfigContract, 
                     address groupsContract,
                    address esusuStorageContract) public OwnableService(serviceContract){
        _owner = msg.sender;
        _savingsConfigContract = ISavingsConfig(savingsConfigContract);
        _groupsContract = IGroups(groupsContract);
        _esusuStorage = IEsusuStorage(esusuStorageContract);
    }

    
    function UpdateDaiLendingService(address daiLendingServiceContractAddress) onlyOwner active external {
        _iDaiLendingService = IDaiLendingService(daiLendingServiceContractAddress);
    }
    
    function UpdateEsusuAdapterWithdrawalDelegate(address delegateContract) onlyOwner active external {
        _delegateContract = delegateContract;
    }
    
    /*
        NOTE: startTimeInSeconds is the time at which when elapsed, any one can start the cycle 
        -   Creates a new EsusuCycle
        -   Esusu Cycle can only be created by the owner of the group
    */
    
    function CreateEsusu(uint groupId, uint depositAmount, uint payoutIntervalSeconds,uint startTimeInSeconds, address owner, uint maxMembers) public active onlyOwnerAndServiceContract {
        //  Get Current EsusuCycleId
        uint currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();

        // Get Group information by Id
        (uint id, string memory name, string memory symbol, address creatorAddress) = GetGroupInformationById(groupId);
        
        require(owner == creatorAddress, "EsusuCycle can only be created by group owner");
        
        _esusuStorage.CreateEsusuCycleMapping(groupId,depositAmount,payoutIntervalSeconds,startTimeInSeconds,owner,maxMembers);
        
        //  emit event
        emit CreateEsusuCycleEvent(now, currentEsusuCycleId, depositAmount, owner, payoutIntervalSeconds,CurrencyEnum.Dai,Dai,_esusuStorage.GetEsusuCycleState(currentEsusuCycleId));
        
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
    
    function JoinEsusu(uint esusuCycleId, address member) public onlyOwnerAndServiceContract active {
        //  Get Current EsusuCycleId
        uint currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();
        
        //  Check if the cycle ID is valid
        require(esusuCycleId > 0 && esusuCycleId <= currentEsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        //  Get the Esusu Cycle struct
        
        (uint CycleId, uint DepositAmount, uint CycleState,uint TotalMembers,uint MaxMembers) = _esusuStorage.GetEsusuCycleBasicInformation(esusuCycleId);
        //  If cycle is not in Idle State, bounce 
        require( CycleState == uint(CycleStateEnum.Idle), "Esusu Cycle must be in Idle State before you can join");

        
        //  If cycle is filled up, bounce 

        require(TotalMembers < MaxMembers, "Esusu Cycle is filled up, you can't join");
        
        //  check if member is already in this cycle 
        require(_isMemberInCycle(member,esusuCycleId) == false, "Member can't join same Esusu Cycle more than once");
        
        //  If user does not have enough Balance, bounce. For now we use Dai as default
        uint memberBalance = _dai.balanceOf(member);
        
        require(memberBalance >= DepositAmount, "Balance must be greater than or equal to Deposit Amount");
        
        
        //  If user balance is greater than or equal to deposit amount then transfer from member to this contract
        //  NOTE: approve this contract to withdraw before transferFrom can work
        _dai.transferFrom(member, address(this), DepositAmount);
        
        //  Increment the total deposited amount in this cycle
        uint totalAmountDeposited = _esusuStorage.IncreaseTotalAmountDepositedInCycle(esusuCycleId,DepositAmount);
        
        
        _esusuStorage.CreateMemberAddressToMemberCycleMapping(member,esusuCycleId);
        
        //  Increase TotalMembers count by 1
        _esusuStorage.IncreaseTotalMembersInCycle(esusuCycleId);
        
        _esusuStorage.CreateMemberPositionMapping(CycleId, member);

        //  emit event 
        emit JoinEsusuCycleEvent(now, member,TotalMembers, totalAmountDeposited,esusuCycleId);
    }

    
    /*
        - Check if the Id is a valid ID
        - Check if the cycle is in Idle State
        - Anyone  can start that cycle -
        - Get the total number of members and then mulitply by the time interval in seconds to get the total time this Cycle will last for
        - Set the Cycle start time to now 
        - Take everyones deposited DAI from this Esusu Cycle and then invest through Yearn 
        - Track the yDai shares that belong to this cycle using the derived equation below for save/investment operation
            - yDaiSharesPerCycle = Change in yDaiSharesForContract + Current yDai Shares in the cycle 
            - Change in yDaiSharesForContract = yDai.balanceOf(address(this) after save operation - yDai.balanceOf(address(this) after before operation
    */
    
    function StartEsusuCycle(uint esusuCycleId) public onlyOwnerAndServiceContract active{
        
        //  Get Current EsusuCycleId
        uint currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();
        
        //  Get Esusu Cycle Basic information
        (uint CycleId, uint DepositAmount, uint CycleState,uint TotalMembers,uint MaxMembers) = _esusuStorage.GetEsusuCycleBasicInformation(esusuCycleId);

        //  Get Esusu Cycle Total Shares
        (uint EsusuCycleTotalShares) = _esusuStorage.GetEsusuCycleTotalShares(esusuCycleId);
        
        
        //  Get Esusu Cycle Payout Interval 
        (uint EsusuCyclePayoutInterval) = _esusuStorage.GetEsusuCyclePayoutInterval(esusuCycleId);
        
        
        //  If cycle ID is valid, else bonunce
        require(esusuCycleId > 0 && esusuCycleId <= currentEsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        

        require(CycleState == uint(CycleStateEnum.Idle), "Cycle can only be started when in Idle state");
        
        require(now > _esusuStorage.GetEsusuCycleStartTime(esusuCycleId), "Cycle can only be started when start time has elapsed");
        

        //  Calculate Cycle LifeTime in seconds
        uint toalCycleDuration = EsusuCyclePayoutInterval * TotalMembers;

        
        //  Get all the dai deposited for this cycle
        uint esusuCycleBalance = _esusuStorage.GetEsusuCycleTotalAmountDeposited(esusuCycleId);
        
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
        uint totalShares = yDaiSharesForContractAfterSave.sub(yDaiSharesForContractBeforeSave).add(EsusuCycleTotalShares);
        
        //  Increase TotalDeposits made to this contract 

        _esusuStorage.IncreaseTotalDeposits(esusuCycleBalance);
        
        //  Update Esusu Cycle State, total cycle duration, total shares  and  cycle start time, 
        _esusuStorage.UpdateEsusuCycleDuringStart(CycleId,uint(CycleStateEnum.Active),toalCycleDuration,totalShares,now);
        
        //  emit event 
        emit StartEsusuCycleEvent(now,esusuCycleBalance, toalCycleDuration,
                                    totalShares,esusuCycleId);
    }
    
    
  
    function GetMemberCycleInfo(address memberAddress, uint esusuCycleId) active public view returns(uint CycleId, address MemberId, uint TotalAmountDepositedInCycle, uint TotalPayoutReceivedInCycle, uint memberPosition) {
        
        return _esusuStorage.GetMemberCycleInfo(memberAddress, esusuCycleId);
    }

    function GetEsusuCycle(uint esusuCycleId) public view returns(uint CycleId, uint DepositAmount, 
                                                            uint PayoutIntervalSeconds, uint CycleState, 
                                                            uint TotalMembers, uint TotalAmountDeposited, uint TotalShares, 
                                                            uint TotalCycleDurationInSeconds, uint TotalCapitalWithdrawn, uint CycleStartTimeInSeconds,
                                                            uint TotalBeneficiaries, uint MaxMembers){
        
        return _esusuStorage.GetEsusuCycle(esusuCycleId);
        
    }
    
    

    
    function GetDaiBalance(address member) active external view returns(uint){
        return _dai.balanceOf(member);
    }
    
    function GetYDaiBalance(address member) active external view returns(uint){
        return _yDai.balanceOf(member);
    }
    
    
    
    function GetTotalDeposits() active public view returns(uint)  {
        return _esusuStorage.GetTotalDeposits();
    } 
    
    

    
    function GetCurrentEsusuCycleId() active public view returns(uint){
        
        return _esusuStorage.GetEsusuCycleId();
    }
    
    function _isMemberInCycle(address memberAddress,uint esusuCycleId ) internal view returns(bool){
        
        return _esusuStorage.IsMemberInCycle(memberAddress,esusuCycleId);
    }
    
    function _isMemberABeneficiaryInCycle(address memberAddress,uint esusuCycleId ) internal view returns(bool){

        uint amount = _esusuStorage.GetMemberCycleToBeneficiaryMapping(esusuCycleId, memberAddress);

        //  If member has received money from this cycle, the amount recieved should be greater than 0

        if(amount > 0){
            
            return true;
        }else{
            return false;
        }
    }
    
    function _isMemberInWithdrawnCapitalMapping(address memberAddress,uint esusuCycleId ) internal view returns(bool){
        
        uint amount = _esusuStorage.GetMemberWithdrawnCapitalInEsusuCycle(esusuCycleId, memberAddress);
        //  If member has withdrawn capital from this cycle, the amount recieved should be greater than 0

        if(amount > 0){
            
            return true;
        }else{
            return false;
        }
    }
    
    /*
        - Get the group index by name
        - Get the group information by index
    */
    function GetGroupInformationByName(string memory name) active public view returns (uint groupId, string memory groupName, string memory groupSymbol, address groupCreatorAddress){
        
        //  Get the group index by name
        (bool exists, uint index ) = _groupsContract.getGroupIndexerByName(name);
        
        //  Get the group id by index and return 

        return _groupsContract.getGroupByIndex(index);
    }
    
        /*
        - Get the group information by Id
    */
    function GetGroupInformationById(uint id) active public view returns (uint groupId, string memory groupName, string memory groupSymbol, address groupCreatorAddress){
        
        //  Get the group id by index and return 

        return _groupsContract.getGroupById(id);
    }
    
    /*
        - Creates the group 
        - returns the ID and other information
    */
    function CreateGroup(string memory name, string memory symbol, address groupCreator) active public {
        
           _groupsContract.createGroup(name,symbol,groupCreator);
           
    }
    
    function TransferYDaiSharesToWithdrawalDelegate(uint amount) external active onlyOwnerAndDelegateContract {
        
        _yDai.transfer(_delegateContract, amount);

    }


    function DepricateContract(address newEsusuAdapterContract, string calldata reason) external onlyOwner{
        //  set _isActive to false
        _isActive = false;
        
        uint yDaiSharesBalance = _yDai.balanceOf(address(this));

        //  Send yDai shares to the new contract and halt operations of this contract
        _yDai.transfer(newEsusuAdapterContract, yDaiSharesBalance);
        
        DepricateContractEvent(now, _owner, reason, yDaiSharesBalance);

    }
    
    modifier onlyOwnerAndDelegateContract() {
        require(
            msg.sender == owner || msg.sender == _delegateContract,
            "Unauthorized access to contract"
        );
        _;
    }
    
    modifier active(){
        require(_isActive == true, "This contract is depricated, use new version of contract");
        _;
    }
    

}

