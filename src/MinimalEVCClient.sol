// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";

contract MinimalEVCClient {
    IEVC immutable public evc;

    constructor(address evc_) {
        evc = IEVC(evc_);
    }


    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// copied from: https://github.com/euler-xyz/evc-playground/blob/master/src/utils/EVCClient.sol
    /// @return The address of the message sender.
    function _msgSender() internal view returns (address) {
        address sender = msg.sender;

        if (sender == address(evc)) {
            (sender,) = evc.getCurrentOnBehalfOfAccount(address(0));
        }

        return sender;
    }

}