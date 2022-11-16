// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;
import "./xtokens.sol";
import "./ERC20.sol";
import "./batch.sol";


contract xcUnitBridge {

    Xtokens public xTokens;
    IERC20 public xcUnit;
    Batch public batch;
    address public constant xtokensPrecompileAddress = 0x0000000000000000000000000000000000000804;
    address public constant xcUnitERC20Address = 0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080;
    address public constant batchAddress = 0x0000000000000000000000000000000000000808;
    bytes4 approve = bytes4(keccak256("approve(address,uint256)"));
    bytes4 sendToken = bytes4(keccak256("send_tokens(Xtokens.Multilocation,uint256)"));

    constructor() {
        // Initializes the xTokens precompile
        xTokens = Xtokens(xtokensPrecompileAddress);
        xcUnit = IERC20(xcUnitERC20Address);
        batch = Batch(batchAddress);
    }

    function send_tokens(Xtokens.Multilocation memory destination, uint256 amount) external {
        //The user needs to approve the appropriate allowance separately
        xcUnit.transferFrom(msg.sender, address(this), amount);
        xTokens.transfer(xcUnitERC20Address, amount, destination, 4000000000);
    }

    function send_tokensBatch(Xtokens.Multilocation memory destination, uint256 amount) external {
        bytes memory approveCallData = abi.encodeWithSelector(approve, address(this), amount);
        bytes memory sendTokenCallData = abi.encodeWithSelector(sendToken, destination, amount);
        bytes[] memory callData = new bytes[](2);
        callData[0] = approveCallData;
        callData[1] = sendTokenCallData;
        address[] memory callBatchAddress = new address[](2);
        callBatchAddress[0]=xcUnitERC20Address;
        callBatchAddress[1]=address(this);
        uint256[] memory value = new uint256[](2);
        value[0] = 0;
        value[1] = 0;
        uint64[] memory gasLimit = new uint64[](2);
        gasLimit[0] = 0;
        gasLimit[1] = 1;
        batch.batchAll(
            callBatchAddress,
            value,
            callData,
            gasLimit
        );
    }

    
}
