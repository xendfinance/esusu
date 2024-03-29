pragma solidity >=0.6.6;

interface ITreasury {
    function depositToken(address token) external;

    function getEtherBalance() external view returns (uint256);

    function getTokenBalance(address token) external view returns (uint256);

    function withdrawEthers(uint256 amount) external;

    function withdrawTokens(address tokenAddress, uint256 amount) external;
}
