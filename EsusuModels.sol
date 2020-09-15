pragma solidity ^0.6.6;

contract EsusuModels{
    
    uint private ModelId = 1000;

  
    /*  Enum definitions */
    enum Currency{
        Dai, Ether, USDT
    }
    
    enum CycleState{
        Idle, Active, Inactive
    }
    
    /*  Struct Definitions */
    struct EsusuCycle{
        uint CycleId;
        uint DepositAmount;
        mapping(address=>Member) Members;
        uint PayoutInterval;    //  Time each member receives overall ROI within one Esusu Cycle
        mapping(address=> Member) Beneficiary;  // Members that have received overall ROI within one Esusu Cycle
        Currency currency;  //  Currency supported in this Esusu Cycle 
        string ProtocolKey;
        string CurrencySymbol;
        CycleState cycleState;  //  The current state of the Esusu Cycle
        uint DepositWindow; //  Time each cycle will be in the Idle State for people to be able to make their deposits
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
    
    //  Auto-increments the ID field to ensure uniqueness 
    function GetId() public returns(uint){
        ModelId += 1;
        return ModelId;
    }
}
