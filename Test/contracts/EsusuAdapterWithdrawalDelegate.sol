pragma solidity >=0.6.6;

import "../interfaces/IDaiToken.sol";
import "../interfaces/IYDaiToken.sol";
import "../interfaces/IDaiLendingService.sol";
import "./OwnableService.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/ISavingsConfig.sol";
import "../interfaces/ISavingsConfigSchema.sol";
import "../interfaces/IRewardConfig.sol";
import "../interfaces/IXendToken.sol";
import "./SafeMath.sol";
import "../interfaces/IEsusuStorage.sol";
import "../interfaces/IEsusuAdapter.sol";


contract EsusuAdapterWithdrawalDelegate is OwnableService, ISavingsConfigSchema {
        
        using SafeMath for uint256;

        event ROIWithdrawalEvent
        (
            uint date,
            address indexed member,  
            uint cycleId,
            uint amount
            
        );
    
        event CapitalWithdrawalEvent
        (
            uint date,
            address indexed member,  
            uint cycleId,
            uint amount
            
        );
    
        enum CycleStateEnum{
            Idle,               // Cycle has just been created and members can join in this state
            Active,             // Cycle has started and members can take their ROI
            Expired,            // Cycle Duration has elapsed and members can withdraw their capital as well as ROI
            Inactive            // Total beneficiaries is equal to Total members, so all members have withdrawn their Capital and ROI 
        }
    
        event DepricateContractEvent(
        
        uint date,
        address owner, 
        string reason
        );
        
        ITreasury _treasuryContract;
        ISavingsConfig _savingsConfigContract;
        IRewardConfig _rewardConfigContract;
        IXendToken  _xendTokenContract;
        string _feeRuleKey;

        IEsusuStorage _esusuStorage;
        IEsusuAdapter _esusuAdapterContract;
        IDaiToken _dai = IDaiToken(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        IYDaiToken _yDai = IYDaiToken(0xC2cB1040220768554cf699b0d863A3cd4324ce32);
        IDaiLendingService _iDaiLendingService;
        bool _isActive = true;

    
        constructor(address payable serviceContract, address esusuStorageContract, address esusuAdapterContract, 
                    string memory feeRuleKey, address treasuryContract, address rewardConfigContract, address xendTokenContract, address savingsConfigContract)public OwnableService(serviceContract){
                        
            _esusuStorage = IEsusuStorage(esusuStorageContract);
            _esusuAdapterContract = IEsusuAdapter(esusuAdapterContract);
            _feeRuleKey = feeRuleKey;
            _treasuryContract = ITreasury(treasuryContract);
            _rewardConfigContract = IRewardConfig(rewardConfigContract);
            _xendTokenContract = IXendToken(xendTokenContract);
            _savingsConfigContract = ISavingsConfig(savingsConfigContract);

        }
    
        function UpdateDaiLendingService(address daiLendingServiceContractAddress) active onlyOwner external {
            _iDaiLendingService = IDaiLendingService(daiLendingServiceContractAddress);
        }
    
        /*
            This function allows members to withdraw their capital from the esusu cycle
            
            - Check if member can withdraw capital 
            - Withdraw capital and increase TotalCapitalWithdrawn
                - Get the total balanceShares from the calling contract
                - Withdraw all the money from dai lending service
                - Send the member's deposited amount to his/her address 
                - re-invest the remaining dai until all members have taken their capital, then we set the cycle inactive
            - Reward member with Xend Tokens 
            - Add this member to the EsusuCycleCapitalMapping
            - Check if TotalCapitalWithdrawn == TotalAmountDeposited && if TotalMembers == TotalBeneficiaries, if yes, set the Cycle to Inactive

        */
        
        function WithdrawCapitalFromEsusuCycle(uint esusuCycleId, address member) public active onlyOwnerAndServiceContract {

        //  Get Esusu Cycle Basic information
        (uint CycleId, uint DepositAmount, uint CycleState,uint TotalMembers,uint MaxMembers) = _esusuStorage.GetEsusuCycleBasicInformation(esusuCycleId);
        
        require(_isMemberEligibleToWithdrawCapital(esusuCycleId,member));
        
        //  Add member to capital withdrawn mapping

        //  Get the current yDaiSharesPerCycle and call the WithdrawByShares function on the daiLending Service
        uint yDaiSharesPerCycle = _esusuStorage.GetEsusuCycleTotalShares(esusuCycleId);


        //  transfer yDaiShares from the adapter contract to here 
        _esusuAdapterContract.TransferYDaiSharesToWithdrawalDelegate(yDaiSharesPerCycle);
        
        //  Get the yDaiSharesForContractBeforeWithdrawal 
        uint yDaiSharesForContractBeforeWithdrawal = _yDai.balanceOf(address(this));
        
        //  Withdraw the Dai. At this point, we have withdrawn  Dai Capital deposited by this member for this cycle and we will now transfer the dai capital to the member
        address daiLendingAdapterContractAddress = _iDaiLendingService.GetDaiLendingAdapterAddress();
        
        _yDai.approve(daiLendingAdapterContractAddress,yDaiSharesPerCycle);
        
        _iDaiLendingService.WithdrawByShares(DepositAmount,yDaiSharesPerCycle);
        
        //  Now the Dai is in this contract, transfer it to the member 
        _dai.transfer(member, DepositAmount);
        
        //  Reward member with Xend Tokens
        _rewardMember(_esusuStorage.GetEsusuCycleDuration(esusuCycleId),member,DepositAmount);
        
        //  Get the yDaiSharesForContractAfterWithdrawal 
        uint yDaiSharesForContractAfterWithdrawal = _yDai.balanceOf(address(this));
        
        require(yDaiSharesForContractBeforeWithdrawal > yDaiSharesForContractAfterWithdrawal, "yDai shares before withdrawal must be greater !!!");
        
        //  Update the total balanceShares for this cycle 
        uint cycleTotalShares = yDaiSharesPerCycle.sub(yDaiSharesForContractBeforeWithdrawal.sub(yDaiSharesForContractAfterWithdrawal));
        
        //  Add this member to the CycleToMemberWithdrawnCapitalMapping

        //  Create Member Capital Mapping
        _esusuStorage.CreateMemberCapitalMapping(esusuCycleId,member);
        
        //  Increase total capital withdrawn 
        uint TotalCapitalWithdrawnInCycle = _esusuStorage.GetEsusuCycleTotalCapitalWithdrawn(CycleId).add(DepositAmount);
        
        //   Check if TotalCapitalWithdrawn == TotalAmountDeposited && if TotalMembers == TotalBeneficiaries, if yes, set the Cycle to Inactive
        
        if(TotalCapitalWithdrawnInCycle == _esusuStorage.GetEsusuCycleTotalAmountDeposited(esusuCycleId) && TotalMembers == _esusuStorage.GetEsusuCycleTotalBeneficiaries(esusuCycleId)){
    
            _esusuStorage.UpdateEsusuCycleState(esusuCycleId, uint(CycleStateEnum.Inactive));
            
            //  Since this cycle is inactive, send whatever Total shares Dai equivalent that is left to our treasury contract

            //  Withdraw DAI equivalent fof TotalShares
        
            _yDai.approve(daiLendingAdapterContractAddress,cycleTotalShares);
            _iDaiLendingService.WithdrawBySharesOnly(cycleTotalShares);
            
            
            //  Now the Dai is in this contract, transfer it to the treasury contract 
            uint balance = _dai.balanceOf(address(this));
            _dai.approve(address(_treasuryContract),balance);
            _treasuryContract.depositToken(address(_dai));
            
        }else{
            
            //  Since we have not withdrawn all the capital, then Send the yDai shares back to the adapter contract,
            //  this contract should not hold any coins
            _yDai.transfer(address(_esusuAdapterContract),_yDai.balanceOf(address(this)));

        }
        
        //  Update Esusu Cycle Information For Capital Withdrawal 
        _esusuStorage.UpdateEsusuCycleDuringCapitalWithdrawal(CycleId, cycleTotalShares,TotalCapitalWithdrawnInCycle);

        //  emit event
        emit CapitalWithdrawalEvent(now, member, esusuCycleId,DepositAmount);

    }
    
      /*
        Assumption:
        - We assume even distribution of Overall accumulated ROI among members of the group when a member places a withdrawal request at a time inverval 
          greater than members in the previous position who have not placed a withdrawal request.
        
        This function sends all ROI generated within an Esusu Cycle Payout Interval to a particular member
        
        - Check if member is eligible to withdraw
        - Get the price per full share from Dai Lending Service\
        - Get overall DAI => yDai balanceShares * pricePerFullShare (NOTE: value is in 1e36)
        - Get ROI => overall Dai - Total Deposited Dai in this esusu cycle 
        - Implement our derived equation to determine what ROI will be allocated to this member who is withdrawing 
        - Deduct fees from Member's ROI
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
            - Troi = ((balanceShares * pricePerFullShare ) - TotalDeposited - TotalCapitalWithdrawn)
            - Mroi = (Total accumulated ROI at Tnow) / (Ta)   
        
        NOTE: As members withdraw their funds, the yDai balanceShares will change and we will be updating the TotalShares with this new value
        at all times till TotalShares becomes approximately zero when all amounts have been withdrawn including capital invested
        
        - Track the yDai shares that belong to this cycle using the derived equation below for withdraw operation
            - yDaiSharesPerCycle = Current yDai Shares in the cycle - Change in yDaiSharesForContract   
            - Change in yDaiSharesForContract = yDai.balanceOf(address(this)) before withdraw operation - yDai.balanceOf(address(this)) after withdraw operation
        
    */
    
    function WithdrawROIFromEsusuCycle(uint esusuCycleId, address member)  public active onlyOwnerAndServiceContract {
        
        bool isMemberEligibleToWithdraw = _isMemberEligibleToWithdrawROI(esusuCycleId,member);
        
        require(isMemberEligibleToWithdraw, "Member cannot withdraw at this time");
        
        uint currentBalanceShares = _esusuStorage.GetEsusuCycleTotalShares(esusuCycleId);
        
        uint pricePerFullShare = _iDaiLendingService.getPricePerFullShare();
        
        uint overallGrossDaiBalance = currentBalanceShares.mul(pricePerFullShare).div(1e18);
        
        uint CycleId = esusuCycleId;
        // address memberAddress = member;
        
        //  Implement our derived equation to get the amount of Dai to transfer to the member as ROI
        uint Bt = _esusuStorage.GetEsusuCyclePayoutInterval(esusuCycleId).mul(_esusuStorage.GetEsusuCycleTotalBeneficiaries(esusuCycleId));

        uint Ta = now.sub(Bt);
        uint Troi = overallGrossDaiBalance.sub(_esusuStorage.GetEsusuCycleTotalAmountDeposited(esusuCycleId).sub(_esusuStorage.GetEsusuCycleTotalCapitalWithdrawn(esusuCycleId)));

        uint Mroi = Troi.div(Ta);
        
        //  Get the current yDaiSharesPerCycle and call the WithdrawByShares function on the daiLending Service
        // uint yDaiSharesPerCycle = currentBalanceShares;
        
        //  transfer yDaiShares from the adapter contract to here 
        _esusuAdapterContract.TransferYDaiSharesToWithdrawalDelegate(currentBalanceShares);
        
        //  Get the yDaiSharesForContractBeforeWithdrawal 
        uint yDaiSharesForContractBeforeWithdrawal = _yDai.balanceOf(address(this));
        
        //  Withdraw the Dai. At this point, we have withdrawn the Dai ROI for this member and the dai ROI is in this contract, we will now transfer it to the member
        address daiLendingAdapterContractAddress = _iDaiLendingService.GetDaiLendingAdapterAddress();
        
        //  Before this function is called, we will have triggered a transfer of yDaiShares from the adapter to this withdrawal contract 
        _yDai.approve(daiLendingAdapterContractAddress,currentBalanceShares);
        _iDaiLendingService.WithdrawByShares(Mroi,currentBalanceShares);
        
        
        //  Now the Dai is in this contract, transfer the net ROI to the member and fee to treasury contract 
        sendROI(Mroi,member,CycleId);
        
        
        
        //  Get the yDaiSharesForContractAfterWithdrawal 
        uint yDaiSharesForContractAfterWithdrawal = _yDai.balanceOf(address(this));
        
        require(yDaiSharesForContractBeforeWithdrawal > yDaiSharesForContractAfterWithdrawal, "yDai shares before withdrawal must be greater !!!");
        
        //  Update the total balanceShares for this cycle 
        uint totalShares = currentBalanceShares.sub(yDaiSharesForContractBeforeWithdrawal.sub(yDaiSharesForContractAfterWithdrawal));
        
        //  Increase total number of beneficiaries by 1
        uint totalBeneficiaries = _esusuStorage.GetEsusuCycleTotalBeneficiaries(CycleId).add(1);
        
        /*
                
            - Check whether the TotalCycleDuration has elapsed, if that is the case then this cycle has expired
            - If cycle has expired then we move the left over yDai to treasury
        */
        
        if(now > _esusuStorage.GetEsusuCycleDuration(CycleId)){
            
            _esusuStorage.UpdateEsusuCycleState(CycleId, uint(CycleStateEnum.Expired));
        }
        
        //  Update Esusu Cycle During ROI withdrawal 
        _esusuStorage.UpdateEsusuCycleDuringROIWithdrawal(CycleId, totalShares,totalBeneficiaries);
        
        //  Send the yDai shares back to the adapter contract, this contract should not hold any coins
        _yDai.transfer(address(_esusuAdapterContract),_yDai.balanceOf(address(this)));
        
        //  emit event 
        _emitROIWithdrawalEvent(member,Mroi,CycleId);
    }
    
    /*
        This gets the fee percentage from the fee contract, deducts the fee and sends to treasury contract 
        
        For now let us assume fee percentage is 0.1% 
        - Get the fee
        - Send the net ROI in dai to member 
        - Send the fee to the treasury
        - Add member to beneficiary mapping
    */
    function sendROI(uint Mroi, address memberAddress, uint esusuCycleId) internal{       
        //  get feeRate from fee contract

        (uint minimum, uint maximum, uint exact, bool applies, RuleDefinition e)  = _savingsConfigContract.getRuleSet(_feeRuleKey);
        
        uint feeRate = exact;  
        uint fee = Mroi.div(feeRate);
        
        //  Deduct the fee
        uint memberROINet = Mroi.sub(fee); 
        
         //  Add member to beneficiary mapping
        
        _esusuStorage.CreateEsusuCycleToBeneficiaryMapping(esusuCycleId,memberAddress,memberROINet);
        
        //  Send ROI to member 
        _dai.transfer(memberAddress, memberROINet);
        
        //  Send deducted fee to treasury
        //  Approve the treasury contract
        _dai.approve(address(_treasuryContract),fee);
        _treasuryContract.depositToken(address(_dai));
        
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
    function IsMemberEligibleToWithdrawROI(uint esusuCycleId, address member) active public view returns(bool){
        
        return _isMemberEligibleToWithdrawROI(esusuCycleId,member);
        
    }
    
    /*
        This function checks whether the user can withdraw capital after the Esusu Cycle is complete. 
        
        The cycle must be in an inactive state before capital can be withdrawn
    */
    function IsMemberEligibleToWithdrawCapital(uint esusuCycleId, address member) active public view returns(bool){
        
        return _isMemberEligibleToWithdrawCapital(esusuCycleId,member);
        
    }
    
    function _isMemberEligibleToWithdrawROI(uint esusuCycleId, address member) internal view returns(bool){
        
        //  Get Current EsusuCycleId
        uint currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();        
        
        require(esusuCycleId > 0 && esusuCycleId <= currentEsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        uint cycleState = _esusuStorage.GetEsusuCycleState(esusuCycleId);
        

        require(cycleState == uint(CycleStateEnum.Active) || cycleState == uint(CycleStateEnum.Expired), "Cycle must be in active or expired state");   
        
        require(_isMemberInCycle(member,esusuCycleId), "Member is not in this cycle");
        
        require(_isMemberABeneficiaryInCycle(member,esusuCycleId) == false, "Member is already a beneficiary");
        
        uint memberWithdrawalTime = _calculateMemberWithdrawalTime(esusuCycleId,member); 
        
        if(now > memberWithdrawalTime){
            return true;

        }else{
            return false;
        }
        
    }
    
    function _isMemberEligibleToWithdrawCapital(uint esusuCycleId, address member) internal view returns(bool){
        
        //  Get Current EsusuCycleId
        uint currentEsusuCycleId = _esusuStorage.GetEsusuCycleId();
        
        require(esusuCycleId > 0 && esusuCycleId <= currentEsusuCycleId, "Cycle ID must be within valid EsusuCycleId range");
        
        uint cycleState = _esusuStorage.GetEsusuCycleState(esusuCycleId);
        
        require(cycleState == uint(CycleStateEnum.Expired), "Cycle must be in Expired state for you to withdraw capital");
        
        require(_isMemberInCycle(member,esusuCycleId), "Member is not in this cycle");
        
        require(_isMemberABeneficiaryInCycle(member,esusuCycleId) == true, "Member must be a beneficiary before you can withdraw capital");

        require(_isMemberInWithdrawnCapitalMapping(member,esusuCycleId) == false, "Member can't withdraw capital twice");

        return true;
        
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
    
    function _calculateMemberWithdrawalTime(uint cycleId, address member) internal view returns(uint){
      
        return _esusuStorage.CalculateMemberWithdrawalTime(cycleId,member);
    }
    
        function _emitROIWithdrawalEvent(address member,uint Mroi, uint esusuCycleId) internal{

        emit ROIWithdrawalEvent(now, member,esusuCycleId,Mroi);
    }
    
    function _rewardMember(uint totalCycleTime, address member, uint amount) internal {
        
        uint reward = _rewardConfigContract.CalculateEsusuReward(totalCycleTime, amount);
        
        // get Xend Token contract and mint token for member
        _xendTokenContract.mint(payable(member), reward);
    }

    function DepricateContract(string calldata reason) external onlyOwner{
        //  set _isActive to false
        _isActive = false;
        
        DepricateContractEvent(now, owner, reason);

    }
    
    modifier active(){
        require(_isActive == true, "This contract is depricated, use new version of contract");
        _;
    }
}