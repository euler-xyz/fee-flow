methods {
	function buy(address[] assets, address assetsReceiver, uint256 epochId, uint256 deadline, uint256 maxPaymentTokenAmount) external returns(uint256) => HAVOC_ECF; // nonReentrant summary
    function getPrice() external returns(uint256);
    function paymentReceiver() external returns(address) envfree => CONSTANT;
    function reentrancyMock() external envfree;

    // view helpers
    function getTokenBalanceOf(address _token, address _account) external returns (uint256);  
    function getAddressThis() external returns (address);
    function getPaymentTokenAllowance(address owner) external returns (uint256);
    function getPaymentTokenBalanceOf(address account) external returns (uint256);
	function getMinInitPrice() external returns (uint256) envfree;
	function getInitPrice() external returns (uint256) envfree;
    function getStartTime() external returns (uint256) envfree; 
    function getEpochId() external returns (uint256) envfree;
    function getPaymentReceiver() external returns (address) envfree; 
    function getPaymentToken() external returns (address) envfree;
    function getEpochPeriod() external returns (uint256) envfree; 
    function getPriceMultiplier() external returns (uint256) envfree; 
    // function getMsgSender() external returns (address) envfree;

    // constants
    function getMAX_EPOCH_PERIOD() external returns (uint256) envfree => CONSTANT;
    function getMIN_EPOCH_PERIOD() external returns (uint256) envfree => CONSTANT; 
    function getMIN_PRICE_MULTIPLIER() external returns (uint256) envfree => CONSTANT; 
    function getABS_MIN_INIT_PRICE() external returns (uint256) envfree => CONSTANT; 
    function getABS_MAX_INIT_PRICE() external returns (uint256) envfree => CONSTANT;
    function getPRICE_MULTIPLIER_SCALE() external returns (uint256) envfree => CONSTANT; 
    function getMAX_PRICE_MULTIPLIER() external returns (uint256) envfree => CONSTANT;
}
