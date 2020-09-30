pragma solidity ^0.6.6;
import "./Ownable.sol";
import "./IEsusuService.sol";

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


// Parameters:
// Contract creation Time (T0)
// $XEND - XT
// Total XT minted (m) - 200,000,000 XT
// Total Amount in dollars Contributed (Y)
// Amount in dollars Contributed by user per cycle (Yu)
// Category (c)  [Group (Cg) or Individual (Ci)] 
// Category Reward Factor [ Group Reward Factor (Cgr) , Individual Reward Factor (Cir) ]
// XT Reward factor (XTf) has unit of XT per $ = Overall XT Reward Threshold per level (Tr) / Savings Threshold in USD (Ts) per level

// XT Reward (XTr) = XTf * Yu

// Cgr = 1
// Cir = 0.7
// Threshold Multiplier Factor [Tf] = 2
// Xend Token(XT) Depreciation Factor [Df]  = 2 (where time > 0 & Threshold > T1)
// Threshold 1 [T1] = $100,000,000 & 10,000,000 XT
// Threshold 2 [T2] = $200,000,000 & 5,000,000 XT
// . 
// .
// .
// Threshold n [Tn] = ($100,000,000 * n) & (10,000,000 XT / (Df ^ n-1) ]

// Relationship between Savings Threshold in USD (Ts) and Overall XT Reward Threshold per level (Tr) - Ts is inversely proportional to Tr 
// Ts = k/ Tr, where K is a constant.  


// Algorithm Implementation


// if(c == Cg)
// 	if(time > T0)
// 		Level = GetCurrentThresholdLevel()
// 		XTf = GetXTf(Level)
// 		XTr = XTf * Cgr
// 		return XTr

// if(c == Ci)
// 	if(time > T0)
// 		Level = GetCurrentThresholdLevel()
// 		XTf = GetXTf(Level)
// 		XTr = XTf * Cgi
// 		return XTr


/*
    @Brief: This contract should reward users with Xend Tokens when the following conditions are met
    1. We must get the Current Threshold level which is determined by the total amount deposited on the different smart contracts 
    2. They perform one or more of the following operations (Individual savings, cooperative savings, esusu)
    3. The users must meet the timelock conditions per operation to receive reward for that condition
    4. Create timelock to Category to CategoryRewardFactor Mapping 
    5. Once a new threshold level is reached, we will add it to the threshold level mapping with maximum Xend Tokens to be distributed in that level
    6. We should be able to stop reward distribution by the owner 
*/
contract RewardConfig is Ownable {
    
    using SafeMath for uint256;

    
    constructor(address esusuServiceContract, address individualSavingsServiceContract, address groupSavingsServiceContract) public{
        EsusuServiceContract = esusuServiceContract;
        IndividualSavingsServiceContract = individualSavingsServiceContract;
        GroupSavingsServiceContract = groupSavingsServiceContract;
    }
    
    address EsusuServiceContract;
    address IndividualSavingsServiceContract;
    address GroupSavingsServiceContract;
    
    uint CurrentThresholdLevel;                 //  
    
    mapping(uint => uint)   DurationToRewardFactorMapping;
    
    uint InitialThresholdValueInUSD;
    uint XendTokenRewardAtInitialThreshold;
    uint DepreciationFactor;
    uint TimeLevelUnitInSeconds;     //  This unit is used to calculate the time levels.
    uint SavingsCategoryRewardFactor;
    uint GroupCategoryRewardFactor;
    uint EsusuCategoryRewardFactor;
    //  The member variables below determine the reward factor based on time. 
    //  NOTE: Ensure that the PercentageRewardFactorPerTimeLevel at 100% corresponds with MaximumTimeLevel. It means MaximumTimeLevel/PercentageRewardFactorPerTimeLevel = 1
    
    uint PercentageRewardFactorPerTimeLevel;    //  This determines the percentage of the reward factor paid for each time level eg 4 means 25%, 5 means 20%
    uint MinimumNumberOfSeconds = 2592000;      //  This determines whether we are checking time level by days, weeks, months or years. It is 30 days(1 month) in seconds by default
    uint MaximumTimeLevel;                      //  This determines how many levels can be derived based on the MinimumNumberOfSeconds that has been set
    
    /*  
        -   Sets the inital threshold value in USD (value in 1e18)
        -   Sets XendToken reward at the initial threshold (value in 1e18)
        -   Sets DepreciationFactor
    */
    function SetRewardParams(uint thresholdValue, uint xendTokenReward, uint depreciationFactor, 
                                uint savingsCategoryRewardFactor, uint groupCategoryRewardFactor, 
                                uint esusuCategoryRewardFactor, uint percentageRewardFactorPerTimeLevel,
                                uint minimumNumberOfSeconds, uint maximumTimeLevel) onlyOwner external{
        require(PercentageRewardFactorPerTimeLevel == MaximumTimeLevel, "Values must be the same to achieve unity at maximum level");
        InitialThresholdValueInUSD = thresholdValue;
        XendTokenRewardAtInitialThreshold = xendTokenReward;
        DepreciationFactor = depreciationFactor;
        SavingsCategoryRewardFactor = savingsCategoryRewardFactor;
        GroupCategoryRewardFactor = groupCategoryRewardFactor;
        EsusuCategoryRewardFactor = esusuCategoryRewardFactor;
        PercentageRewardFactorPerTimeLevel = percentageRewardFactorPerTimeLevel;
        MinimumNumberOfSeconds = minimumNumberOfSeconds;
        MaximumTimeLevel = maximumTimeLevel;
       
    }
    
    /*
        This function calculates XTr for individual savings based on the total cycle time and amountDeposited
    */
    function _calculateIndividualSavingsReward(uint totalCycleTimeInSeconds, uint amountDeposited) external view returns(uint){
        uint Cir = _calculateCategoryFactor(totalCycleTimeInSeconds,SavingsCategoryRewardFactor);
        uint XTf = _calculateRewardFactorForCurrentThresholdLevel();
        uint XTr = XTf.mul(Cir);    // NOTE: this value is in 1e18 
        
        // return XTr * amountdeposited and divided by 1e18 since the amount is already in the wei unit 

        uint individualSavingsReward = XTr.mul(amountDeposited).div(1e36);
        return individualSavingsReward;
    }
    
    /*
        This function calculates XTr for group or cooperative savings based on the total cycle time and amountDeposited
    */
    function _calculateCooperativeSavingsReward(uint totalCycleTimeInSeconds, uint amountDeposited) external view returns(uint){
        uint Cgr = _calculateCategoryFactor(totalCycleTimeInSeconds,GroupCategoryRewardFactor);
        uint XTf = _calculateRewardFactorForCurrentThresholdLevel();
        uint XTr = XTf.mul(Cgr);    // NOTE: this value is in 1e18 which is correct
        
        // return XTr * amountdeposited and divided by 1e18 since the amount is already in the wei unit 

        uint groupSavingsReward = XTr.mul(amountDeposited).div(1e36);
        return groupSavingsReward;
    }
    
    /*
        This function calculates XTr for Esusu based on the total cycle time and amountDeposited
    */
    function _calculateEsusuReward(uint totalCycleTimeInSeconds, uint amountDeposited) external view returns(uint){
        uint Cgr = _calculateCategoryFactor(totalCycleTimeInSeconds,EsusuCategoryRewardFactor);
        uint XTf = _calculateRewardFactorForCurrentThresholdLevel();
        uint XTr = XTf.mul(Cgr);    // NOTE: this value is in 1e18 which is correct
        
        // return XTr * amountdeposited and divided by 1e18 since the amount is already in the wei unit 

        uint groupSavingsReward = XTr.mul(amountDeposited).div(1e36);
        return groupSavingsReward;
    }
    
    /*
        -   Get the RewardTimeLevel based on the totalCycleTimeInSeconds
        -   Get the PercentageRewardFactor based on the RewardTimeLevel : NOTE value is in 1e18
        -   Reward value is multipied by 10 because it is usually a decimal based on the category 
    */
    
    function _calculateCategoryFactor(uint totalCycleTimeInSeconds, uint reward) public view returns(uint){
        
        uint timeLevel = _getRewardTimeLevel(totalCycleTimeInSeconds);
        
        uint percentageRewardFactor = _calculatePercentageRewardFactor(timeLevel);
        
        uint result = percentageRewardFactor.mul(reward).div(10);
        
        return result;
    }
    
    /*
        1. Get the CurrentThresholdLevel
        2. Get reward factor for current threshold level (XTf) => Xend Token Threshold Per Level / Deposit Threshold for that level in USD
        
    */
    function _calculateRewardFactorForCurrentThresholdLevel() public view returns(uint){
        
        uint level = _getCurrentThresholdLevel();
        uint currentDepositThreshold = level.mul(InitialThresholdValueInUSD);
        uint currentXendTokenRewardThreshold = _getCurrentXendTokenRewardThresholdAtCurrentLevel();
        uint XTf = currentXendTokenRewardThreshold.mul(1e18).div(currentDepositThreshold);
        
        return XTf;
    }
    

    
    /*
        - This function gets the total deposits from all XendFinance smart contracts 
    */
    function GetTotalDeposits() public pure  returns(uint){
        
        return 1000000000000000000000000;
    }
    
    function _getCurrentThresholdLevel() public view returns(uint){
        
        uint totalDeposits = GetTotalDeposits();
        uint initialThresholdValue = InitialThresholdValueInUSD;
        
        uint level = totalDeposits.div(initialThresholdValue);
         
         if (level == 0){
             return 1;
         }
         
         return level;
    }
    
    function _getCurrentXendTokenRewardThresholdAtCurrentLevel() public view returns(uint){
        
        uint level = _getCurrentThresholdLevel();
        uint result = XendTokenRewardAtInitialThreshold.div(DepreciationFactor ** level.sub(1));
        
        return result;
    }
    
    
    /*
        - Reward time levels determine the amount of reward you will receive based on the total time of the savings cycle
        - Minimum reward time is 30 days which is 2592000 seconds 
        - If the Timelevel is 0, user does not get any Xend Token reward
        - User gets maximum Xend Token reward from Timelevel 4 since the PercentageRewardFactor will return 100% 
    */
    
    function _getRewardTimeLevel(uint totalCycleTimeInSeconds) public view returns(uint){
        
        
        uint level = totalCycleTimeInSeconds.div(MinimumNumberOfSeconds);
        
        if(level >= MaximumTimeLevel){
            level = MaximumTimeLevel;
        }
        return level;
    }
    
    /*
        -   This function calculates the percentage of the reward factor per time level.
        -   PercentageRewardFactor = TimeLevel / PercentageRewardFactorPerTimeLevel
        -   Value is returned in 1e18 to handle decimals
    */
    function _calculatePercentageRewardFactor(uint rewardTimeLevel) public view returns(uint){
        
        uint result = rewardTimeLevel.mul(1e18).div(PercentageRewardFactorPerTimeLevel);
        
        return result;
    }
}
