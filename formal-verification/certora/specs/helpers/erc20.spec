/***
 * This spec file adds `DISPATCHER` summaries for the methods in the ERC20
 * specification.  It is useful for writing specifications that work with
 * arbitrary ERC20 contracts; if using it, you should add a variety of ERC20
 * implementations to the scene.
 *
 * See [Using DISPATCHER for ERC20 contracts][guide] in the user guide for more
 * information.
 *
 * [guide]: https://docs.certora.com/en/latest/docs/user-guide/multicontract/index.html#using-dispatcher-for-erc20-contracts
 */

methods {
    function _.name()                                external => DISPATCHER;
    function _.symbol()                              external => DISPATCHER;
    function _.decimals()                            external => DISPATCHER;
    function _.totalSupply()                         external => DISPATCHER;
    function _.balanceOf(address)                    external => DISPATCHER;
    function _.allowance(address,address)            external => DISPATCHER;
    function _.approve(address,uint256)              external => DISPATCHER;
    function _.transfer(address,uint256)             external => DISPATCHER;
    function _.transferFrom(address,address,uint256) external => DISPATCHER;
}
