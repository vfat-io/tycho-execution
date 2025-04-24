// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import "@src/executors/UniswapV4Executor.sol";
import {TychoRouter} from "@src/TychoRouter.sol";
import "./TychoRouterTestSetup.sol";
import "./executors/UniswapV4Utils.sol";
import {SafeCallback} from "@uniswap/v4-periphery/src/base/SafeCallback.sol";

contract TychoRouterSingleSwapTest is TychoRouterTestSetup {
    function testSingleSwapPermit2() public {
        // Trade 1 WETH for DAI with 1 swap on Uniswap V2 using Permit2
        // 1 WETH   ->   DAI
        //       (USV2)
        vm.startPrank(ALICE);

        uint256 amountIn = 1 ether;
        deal(WETH_ADDR, ALICE, amountIn);
        (
            IAllowanceTransfer.PermitSingle memory permitSingle,
            bytes memory signature
        ) = handlePermit2Approval(WETH_ADDR, tychoRouterAddr, amountIn);

        bytes memory protocolData = encodeUniswapV2Swap(
            WETH_ADDR,
            WETH_DAI_POOL,
            ALICE,
            false,
            TokenTransfer.TransferType.TRANSFER_PERMIT2_TO_PROTOCOL
        );

        bytes memory swap =
            encodeSingleSwap(address(usv2Executor), protocolData);

        tychoRouter.singleSwapPermit2(
            amountIn,
            WETH_ADDR,
            DAI_ADDR,
            2008817438608734439722,
            false,
            false,
            ALICE,
            permitSingle,
            signature,
            swap
        );

        uint256 daiBalance = IERC20(DAI_ADDR).balanceOf(ALICE);
        assertEq(daiBalance, 2018817438608734439722);
        assertEq(IERC20(WETH_ADDR).balanceOf(ALICE), 0);

        vm.stopPrank();
    }

    function testSingleSwapNoPermit2() public {
        // Trade 1 WETH for DAI with 1 swap on Uniswap V2
        // Checks amount out at the end
        uint256 amountIn = 1 ether;

        deal(WETH_ADDR, ALICE, amountIn);
        vm.startPrank(ALICE);
        // Approve the tokenIn to be transferred to the router
        IERC20(WETH_ADDR).approve(address(tychoRouterAddr), amountIn);

        bytes memory protocolData = encodeUniswapV2Swap(
            WETH_ADDR,
            WETH_DAI_POOL,
            ALICE,
            false,
            TokenTransfer.TransferType.TRANSFER_FROM_TO_PROTOCOL
        );

        bytes memory swap =
            encodeSingleSwap(address(usv2Executor), protocolData);

        uint256 minAmountOut = 2000 * 1e18;
        uint256 amountOut = tychoRouter.singleSwap(
            amountIn,
            WETH_ADDR,
            DAI_ADDR,
            minAmountOut,
            false,
            false,
            ALICE,
            swap
        );

        uint256 expectedAmount = 2018817438608734439722;
        assertEq(amountOut, expectedAmount);
        uint256 daiBalance = IERC20(DAI_ADDR).balanceOf(ALICE);
        assertEq(daiBalance, expectedAmount);
        assertEq(IERC20(WETH_ADDR).balanceOf(ALICE), 0);

        vm.stopPrank();
    }

    function testSingleSwapUndefinedMinAmount() public {
        // Trade 1 WETH for DAI with 1 swap on Uniswap V2
        // Checks amount out at the end
        uint256 amountIn = 1 ether;

        deal(WETH_ADDR, ALICE, amountIn);
        vm.startPrank(ALICE);
        IERC20(WETH_ADDR).approve(address(tychoRouterAddr), amountIn);

        bytes memory protocolData = encodeUniswapV2Swap(
            WETH_ADDR,
            WETH_DAI_POOL,
            ALICE,
            false,
            TokenTransfer.TransferType.TRANSFER_FROM_TO_PROTOCOL
        );

        bytes memory swap =
            encodeSingleSwap(address(usv2Executor), protocolData);

        vm.expectRevert(TychoRouter__UndefinedMinAmountOut.selector);
        tychoRouter.singleSwap(
            amountIn, WETH_ADDR, DAI_ADDR, 0, false, false, ALICE, swap
        );
    }

    function testSingleSwapInsufficientApproval() public {
        // Trade 1 WETH for DAI with 1 swap on Uniswap V2
        // Checks amount out at the end
        uint256 amountIn = 1 ether;

        deal(WETH_ADDR, ALICE, amountIn);
        vm.startPrank(ALICE);
        IERC20(WETH_ADDR).approve(address(tychoRouterAddr), amountIn - 1);

        bytes memory protocolData = encodeUniswapV2Swap(
            WETH_ADDR,
            WETH_DAI_POOL,
            ALICE,
            false,
            TokenTransfer.TransferType.TRANSFER_FROM_TO_PROTOCOL
        );

        bytes memory swap =
            encodeSingleSwap(address(usv2Executor), protocolData);

        uint256 minAmountOut = 2600 * 1e18;
        vm.expectRevert();
        tychoRouter.singleSwap(
            amountIn,
            WETH_ADDR,
            DAI_ADDR,
            minAmountOut,
            false,
            false,
            ALICE,
            swap
        );
    }

    function testSingleSwapNegativeSlippageFailure() public {
        // Trade 1 WETH for DAI with 1 swap on Uniswap V2
        // Checks amount out at the end
        uint256 amountIn = 1 ether;

        deal(WETH_ADDR, ALICE, amountIn);
        vm.startPrank(ALICE);
        // Approve the tokenIn to be transferred to the router
        IERC20(WETH_ADDR).approve(address(tychoRouterAddr), amountIn);

        bytes memory protocolData = encodeUniswapV2Swap(
            WETH_ADDR,
            WETH_DAI_POOL,
            ALICE,
            false,
            TokenTransfer.TransferType.TRANSFER_FROM_TO_PROTOCOL
        );

        bytes memory swap =
            encodeSingleSwap(address(usv2Executor), protocolData);

        uint256 minAmountOut = 5600 * 1e18;

        vm.expectRevert(
            abi.encodeWithSelector(
                TychoRouter__NegativeSlippage.selector,
                2018817438608734439722, // actual amountOut
                minAmountOut
            )
        );
        tychoRouter.singleSwap(
            amountIn,
            WETH_ADDR,
            DAI_ADDR,
            minAmountOut,
            false,
            false,
            ALICE,
            swap
        );
    }

    function testSingleSwapWrapETH() public {
        uint256 amountIn = 1 ether;
        deal(ALICE, amountIn);
        vm.startPrank(ALICE);

        IAllowanceTransfer.PermitSingle memory emptyPermitSingle =
        IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: address(0),
                amount: 0,
                expiration: 0,
                nonce: 0
            }),
            spender: address(0),
            sigDeadline: 0
        });

        bytes memory protocolData = encodeUniswapV2Swap(
            WETH_ADDR,
            WETH_DAI_POOL,
            ALICE,
            false,
            TokenTransfer.TransferType.TRANSFER_TO_PROTOCOL
        );

        bytes memory swap =
            encodeSingleSwap(address(usv2Executor), protocolData);

        uint256 amountOut = tychoRouter.singleSwapPermit2{value: amountIn}(
            amountIn,
            address(0),
            DAI_ADDR,
            1000_000000,
            true,
            false,
            ALICE,
            emptyPermitSingle,
            "",
            swap
        );
        uint256 expectedAmount = 2018817438608734439722;
        assertEq(amountOut, expectedAmount);
        uint256 daiBalance = IERC20(DAI_ADDR).balanceOf(ALICE);
        assertEq(daiBalance, expectedAmount);
        assertEq(ALICE.balance, 0);

        vm.stopPrank();
    }

    function testSingleSwapUnwrapETH() public {
        // DAI -> WETH with unwrapping to ETH
        uint256 amountIn = 3000 ether;
        deal(DAI_ADDR, ALICE, amountIn);

        vm.startPrank(ALICE);
        (
            IAllowanceTransfer.PermitSingle memory permitSingle,
            bytes memory signature
        ) = handlePermit2Approval(DAI_ADDR, tychoRouterAddr, amountIn);

        bytes memory protocolData = encodeUniswapV2Swap(
            DAI_ADDR,
            WETH_DAI_POOL,
            tychoRouterAddr,
            true,
            TokenTransfer.TransferType.TRANSFER_PERMIT2_TO_PROTOCOL
        );

        bytes memory swap =
            encodeSingleSwap(address(usv2Executor), protocolData);

        uint256 amountOut = tychoRouter.singleSwapPermit2(
            amountIn,
            DAI_ADDR,
            address(0),
            1000_000000,
            false,
            true,
            ALICE,
            permitSingle,
            signature,
            swap
        );

        uint256 expectedAmount = 1475644707225677606;
        assertEq(amountOut, expectedAmount);
        assertEq(ALICE.balance, expectedAmount);

        vm.stopPrank();
    }

    function testSingleSwapIntegration() public {
        // Tests swapping WETH -> DAI on a USV2 pool with regular approvals
        deal(WETH_ADDR, ALICE, 1 ether);
        uint256 balanceBefore = IERC20(DAI_ADDR).balanceOf(ALICE);

        vm.startPrank(ALICE);
        IERC20(WETH_ADDR).approve(tychoRouterAddr, type(uint256).max);
        // Encoded solution generated using `test_single_swap_strategy_encoder_no_permit2`
        (bool success,) = tychoRouterAddr.call(
            hex"20144a070000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000058e7926ee858a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cd09f75e2bf2a4d11f3ab23f1389fcc1621c0cc2000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000525615deb798bb3e4dfa0139dfa1b3d433cc23b72fc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2a478c2975ab1ea89e8196811f51a7b7ade33eb11cd09f75e2bf2a4d11f3ab23f1389fcc1621c0cc200010000000000000000000000000000"
        );

        vm.stopPrank();

        uint256 balanceAfter = IERC20(DAI_ADDR).balanceOf(ALICE);
        assertTrue(success, "Call Failed");
        assertEq(balanceAfter - balanceBefore, 2018817438608734439722);
    }

    function testSingleSwapIntegrationPermit2() public {
        // Tests swapping WETH -> DAI on a USV2 pool with permit2
        deal(WETH_ADDR, ALICE, 1 ether);
        uint256 balanceBefore = IERC20(DAI_ADDR).balanceOf(ALICE);

        vm.startPrank(ALICE);
        IERC20(WETH_ADDR).approve(PERMIT2_ADDRESS, type(uint256).max);
        // Encoded solution generated using `test_single_swap_strategy_encoder`
        (bool success,) = tychoRouterAddr.call(
            hex"30ace1b10000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000000000000000000006b56051582a970000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cd09f75e2bf2a4d11f3ab23f1389fcc1621c0cc2000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000682f946a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003ede3eca2a72b3aecc820e955b36f38437d013950000000000000000000000000000000000000000000000000000000068080e7200000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000041c0ace69971589bd5136c309c83a06d60a7a54a49a2f1cecdf51cc5aecd4f7cce07a1b4a152d758fb6c3e4a73f8cf96ca3b3e8ab82b402733b7979a67021e99a51c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000525615deb798bb3e4dfa0139dfa1b3d433cc23b72fc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2a478c2975ab1ea89e8196811f51a7b7ade33eb11cd09f75e2bf2a4d11f3ab23f1389fcc1621c0cc200020000000000000000000000000000"
        );

        vm.stopPrank();

        uint256 balanceAfter = IERC20(DAI_ADDR).balanceOf(ALICE);
        assertTrue(success, "Call Failed");
        assertEq(balanceAfter - balanceBefore, 2018817438608734439722);
    }

    function testSingleSwapWithWrapIntegration() public {
        // Tests swapping WETH -> DAI on a USV2 pool, but ETH is received from the user
        // and wrapped before the swap
        deal(ALICE, 1 ether);
        uint256 balanceBefore = IERC20(DAI_ADDR).balanceOf(ALICE);

        // Approve permit2
        vm.startPrank(ALICE);
        // Encoded solution generated using `test_single_swap_strategy_encoder_wrap`
        (bool success,) = tychoRouterAddr.call{value: 1 ether}(
            hex"30ace1b10000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000059fb7d3830e6fc064b00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cd09f75e2bf2a4d11f3ab23f1389fcc1621c0cc200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000682f965f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003ede3eca2a72b3aecc820e955b36f38437d01395000000000000000000000000000000000000000000000000000000006808106700000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000041cdef1c27d45a13adde80b5d93c8786741b69ddbe7684c4356f3dc7d4aa8029cb3cba0aac801787a7993ba0be72a6b459fa2a5c18a8e4938a0ccd3503d1be81841c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000525615deb798bb3e4dfa0139dfa1b3d433cc23b72fc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2a478c2975ab1ea89e8196811f51a7b7ade33eb11cd09f75e2bf2a4d11f3ab23f1389fcc1621c0cc200000000000000000000000000000000"
        );

        vm.stopPrank();

        uint256 balanceAfter = IERC20(DAI_ADDR).balanceOf(ALICE);

        assertTrue(success, "Call Failed");
        assertEq(balanceAfter - balanceBefore, 2018817438608734439722);
    }

    function testSingleSwapWithUnwrapIntegration() public {
        // Tests swapping DAI -> WETH on a USV2 pool, and WETH is unwrapped to ETH
        // before sending back to the user
        deal(DAI_ADDR, ALICE, 3000 ether);
        uint256 balanceBefore = ALICE.balance;

        // Approve permit2
        vm.startPrank(ALICE);
        IERC20(DAI_ADDR).approve(PERMIT2_ADDRESS, type(uint256).max);
        // Encoded solution generated using `test_single_swap_strategy_encoder_unwrap`
        (bool success,) = tychoRouterAddr.call(
            hex"30ace1b10000000000000000000000000000000000000000000000a2a15d09519be000000000000000000000000000006b175474e89094c44da98b954eedeac495271d0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000cd09f75e2bf2a4d11f3ab23f1389fcc1621c0cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f0000000000000000000000000000000000000000000000a2a15d09519be0000000000000000000000000000000000000000000000000000000000000682db45d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000003ede3eca2a72b3aecc820e955b36f38437d013950000000000000000000000000000000000000000000000000000000068062e6500000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000041de45f1a73e8a22fc958af300f93cff06b49e74667bb29b810aed4254fef0dae6340ceb95265d81f5b158bcade2b5a2e3efa8bfa521a6466c0b1ce0bcfddc19d21c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000525615deb798bb3e4dfa0139dfa1b3d433cc23b72f6b175474e89094c44da98b954eedeac495271d0fa478c2975ab1ea89e8196811f51a7b7ade33eb113ede3eca2a72b3aecc820e955b36f38437d0139501020000000000000000000000000000"
        );

        vm.stopPrank();

        uint256 balanceAfter = ALICE.balance;

        assertTrue(success, "Call Failed");
        assertEq(balanceAfter - balanceBefore, 1475644707225677606);
    }

    function testSingleSwapIntegrationNoTransferIn() public {
        // Tests swapping WETH -> DAI on a USV2 pool assuming that the tokens are already inside the router
        deal(WETH_ADDR, tychoRouterAddr, 1 ether);
        uint256 balanceBefore = IERC20(DAI_ADDR).balanceOf(ALICE);

        vm.startPrank(ALICE);
        // Encoded solution generated using `test_single_swap_strategy_encoder_no_transfer_in`
        (bool success,) = tychoRouterAddr.call(
            hex"20144a070000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000006b175474e89094c44da98b954eedeac495271d0f000000000000000000000000000000000000000000000058e7926ee858a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cd09f75e2bf2a4d11f3ab23f1389fcc1621c0cc2000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000525615deb798bb3e4dfa0139dfa1b3d433cc23b72fc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2a478c2975ab1ea89e8196811f51a7b7ade33eb11cd09f75e2bf2a4d11f3ab23f1389fcc1621c0cc200000000000000000000000000000000"
        );

        vm.stopPrank();

        uint256 balanceAfter = IERC20(DAI_ADDR).balanceOf(ALICE);
        assertTrue(success, "Call Failed");
        assertEq(balanceAfter - balanceBefore, 2018817438608734439722);
    }
}
