pragma solidity ^0.6.6;

contract EsusuAdapter{
    
    /*  Model definition starts */
    string ETH = "Ethers";
    string Dai = "Dai Stablecoin";
    string USDT = "USDT";
    
    /*  Enum definitions */
    enum CurrencyEnum{
        Dai, Ether, USDT
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
    }
    
    struct Member{
        address MemberId;
        uint Balance;
    }
    
    struct MemberCycle{
        uint CycleId;
        address MemberId;
        uint TotalAmountDeposited;
        uint TotalPayoutReceived;
    }
    
    /* Model definition ends */
    
    //  Member variables
    uint EsusuCycleId = 0;
    
    EsusuCycle [] EsusuCyclesArray;  //  Store all EsusuCycles
    
    mapping(uint => EsusuCycle) EsusuCycleMapping;
    string ProtocolKey; //  TODO: implement ProtocolKey selection

    function CreateEsusu(uint depositAmount, uint payoutTimeIntervalUnit, uint payoutInterval, uint currency, uint depositWindow, uint depositWindowUnit ) external {
        
        EsusuCycle memory cycle;
        cycle.DepositAmount = depositAmount;
        cycle.PayoutTimeIntervalUnit = TimeUnitEnum(payoutTimeIntervalUnit);
        cycle.PayoutInterval = payoutInterval;
        cycle.Currency = CurrencyEnum(currency);
        cycle.ProtocolKey = ProtocolKey;
        cycle.CurrencySymbol = getCurrencySymbol(CurrencyEnum(currency));
        cycle.CycleState = CycleStateEnum.Idle; 
        cycle.DepositWindow = depositWindow;
        cycle.DepositWindowUnit = TimeUnitEnum(depositWindowUnit);
        cycle.Owner = msg.sender;
        
        //  Increment EsusuCycleId by 1
        EsusuCycleId += 1;
        cycle.CycleId = EsusuCycleId;

        //  Create mapping
        EsusuCycleMapping[EsusuCycleId] = cycle;
        
        //  TODO: Add EsusuCycle to array
        EsusuCyclesArray.push(cycle);


    }
    
    //  Join a particular Esusu Cycle 
    function JoinEsusu(uint esusuCycleId)external {
        
        //  If cycle ID is 0, bonunce
        require(esusuCycleId > 0, "Cycle ID must be greater than 0");

        //  If cycle is not in Idle State, bounce 
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        require(cycle.CycleState == CycleStateEnum.Idle, "Esusu Cycle must be in Idle State before you can join");

    }
    

    function GetEsusuCycle(uint esusuCycleId) external view returns(uint CycleId, uint DepositAmount, 
                                                            uint PayoutTimeIntervalUnit, uint PayoutInterval, uint Currency, 
                                                            string memory ProtocolKey, string memory CurrencySymbol, uint CycleState, uint DepositWindow, uint  DepositWindowUnit, address Onwer ){
        
        require(esusuCycleId > 0, "Cycle ID must be greater than 0");
        
        EsusuCycle memory cycle = EsusuCycleMapping[esusuCycleId];
        
        return (cycle.CycleId, cycle.DepositAmount, uint256(cycle.PayoutTimeIntervalUnit),  cycle.PayoutInterval, uint256(cycle.Currency), cycle.ProtocolKey,cycle.CurrencySymbol,uint256(cycle.CycleState), cycle.DepositWindow,uint256(cycle.DepositWindowUnit), cycle.Owner  );
        
    }
    
    
    function GetCurrentEsusuCycleId() external view returns(uint){
        return EsusuCycleId;
    }
    
    function getCurrencySymbol(CurrencyEnum currency) internal view returns(string memory){
        
        if(currency == CurrencyEnum.Dai){
            return Dai;
        }else if(currency == CurrencyEnum.Ether){
            return ETH;
        }
        else if(currency == CurrencyEnum.USDT){
            return USDT;
        }
        
        revert("Invalid Currency Symbol");
    }
}