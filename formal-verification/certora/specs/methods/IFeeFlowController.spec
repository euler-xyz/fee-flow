methods {
	function buy(address[] calldata assets, address assetsReceiver, uint256 deadline, uint256 maxPaymentTokenAmount) external returns(uint256);
	function getInitPrice() external returns(uint256) envfree;
	function getMinInitPrice() external returns (uint256) envfree;
}
