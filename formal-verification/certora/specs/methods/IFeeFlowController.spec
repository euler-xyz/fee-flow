methods {
	function buy(address[] calldata assets, address assetsReceiver, uint256 deadline, uint256 maxPaymentTokenAmount) external returns(uint256);
    function getPrice() external returns(uint256);
    // view helpers
    function getPymentTokenAllowance(address spender) external returns (uint256);
    function getPaymentTokenBalanceOf(address account) external returns (uint256);
	function getInitPrice() external returns(uint256) envfree;
	function getMinInitPrice() external returns (uint256) envfree;
	function getInitPrice() external returns (uint256) envfree;
    function getStartTime() external returns (uint256) envfree; 
    function getPaymentReceiver() external returns (address) envfree; 
    function getEpochPeriod() external returns (uint256) envfree; 
    function getPriceMultiplier() external returns (uint256) envfree; 
    function getMinInitPrice() external returns (uint256) envfree; 

    // constants
    function getMIN_EPOCH_PERIOD() external returns (uint256) envfree => CONSTANT; 
    function getMIN_PRICE_MULTIPLIER() external returns (uint256) envfree => CONSTANT; 
    function getMIN_MIN_INIT_PRICE() external returns (uint256) envfree => CONSTANT; 
    function getPRICE_MULTIPLIER_SCALE() external returns (uint256) envfree => CONSTANT; 
}
