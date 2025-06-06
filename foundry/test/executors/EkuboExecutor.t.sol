// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {EkuboExecutor, TokenTransfer} from "@src/executors/EkuboExecutor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Constants} from "../Constants.sol";
import {Test, console} from "forge-std/Test.sol";
import {NATIVE_TOKEN_ADDRESS} from "@ekubo/math/constants.sol";
import {ICore} from "@ekubo/interfaces/ICore.sol";

contract EkuboExecutorTest is Test, Constants {
    address constant EXECUTOR_ADDRESS =
        0xcA4F73Fe97D0B987a0D12B39BBD562c779BAb6f6; // Same address as in swap_encoder.rs tests
    EkuboExecutor executor;

    IERC20 USDC = IERC20(USDC_ADDR);
    IERC20 USDT = IERC20(USDT_ADDR);

    address constant CORE_ADDRESS = 0xe0e0e08A6A4b9Dc7bD67BCB7aadE5cF48157d444;

    bytes32 constant ORACLE_CONFIG =
        0x51d02a5948496a67827242eabc5725531342527c000000000000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 22082754);

        deployCodeTo(
            "executors/EkuboExecutor.sol",
            abi.encode(CORE_ADDRESS, PERMIT2_ADDRESS),
            EXECUTOR_ADDRESS
        );
        executor = EkuboExecutor(payable(EXECUTOR_ADDRESS));
    }

    function testSingleSwapEth() public {
        uint256 amountIn = 1 ether;

        deal(address(executor), amountIn);

        uint256 ethBalanceBeforeCore = CORE_ADDRESS.balance;
        uint256 ethBalanceBeforeExecutor = address(executor).balance;

        uint256 usdcBalanceBeforeCore = USDC.balanceOf(CORE_ADDRESS);
        uint256 usdcBalanceBeforeExecutor = USDC.balanceOf(address(executor));

        bytes memory data = abi.encodePacked(
            uint8(TokenTransfer.TransferType.TRANSFER_TO_PROTOCOL), // transferType (transfer from executor to core)
            address(executor), // receiver
            NATIVE_TOKEN_ADDRESS, // tokenIn
            USDC_ADDR, // tokenOut
            ORACLE_CONFIG // poolConfig
        );

        uint256 gasBefore = gasleft();
        uint256 amountOut = executor.swap(amountIn, data);
        console.log(gasBefore - gasleft());

        console.log(amountOut);

        assertEq(CORE_ADDRESS.balance, ethBalanceBeforeCore + amountIn);
        assertEq(address(executor).balance, ethBalanceBeforeExecutor - amountIn);

        assertEq(
            USDC.balanceOf(CORE_ADDRESS), usdcBalanceBeforeCore - amountOut
        );
        assertEq(
            USDC.balanceOf(address(executor)),
            usdcBalanceBeforeExecutor + amountOut
        );
    }

    function testSingleSwapERC20() public {
        uint256 amountIn = 1_000_000_000;

        deal(USDC_ADDR, address(executor), amountIn);

        uint256 usdcBalanceBeforeCore = USDC.balanceOf(CORE_ADDRESS);
        uint256 usdcBalanceBeforeExecutor = USDC.balanceOf(address(executor));

        uint256 ethBalanceBeforeCore = CORE_ADDRESS.balance;
        uint256 ethBalanceBeforeExecutor = address(executor).balance;

        bytes memory data = abi.encodePacked(
            uint8(TokenTransfer.TransferType.TRANSFER_TO_PROTOCOL), // transferType (transfer from executor to core)
            address(executor), // receiver
            USDC_ADDR, // tokenIn
            NATIVE_TOKEN_ADDRESS, // tokenOut
            ORACLE_CONFIG // config
        );

        uint256 gasBefore = gasleft();
        uint256 amountOut = executor.swap(amountIn, data);
        console.log(gasBefore - gasleft());

        console.log(amountOut);

        assertEq(USDC.balanceOf(CORE_ADDRESS), usdcBalanceBeforeCore + amountIn);
        assertEq(
            USDC.balanceOf(address(executor)),
            usdcBalanceBeforeExecutor - amountIn
        );

        assertEq(CORE_ADDRESS.balance, ethBalanceBeforeCore - amountOut);
        assertEq(
            address(executor).balance, ethBalanceBeforeExecutor + amountOut
        );
    }

    // Expects input that encodes the same test case as swap_encoder::tests::ekubo::test_encode_swap_multi
    function multiHopSwap(bytes memory data) internal {
        uint256 amountIn = 1 ether;

        deal(address(executor), amountIn);

        uint256 ethBalanceBeforeCore = CORE_ADDRESS.balance;
        uint256 ethBalanceBeforeExecutor = address(executor).balance;

        uint256 usdtBalanceBeforeCore = USDT.balanceOf(CORE_ADDRESS);
        uint256 usdtBalanceBeforeExecutor = USDT.balanceOf(address(executor));

        uint256 gasBefore = gasleft();
        uint256 amountOut = executor.swap(amountIn, data);
        console.log(gasBefore - gasleft());

        console.log(amountOut);

        assertEq(CORE_ADDRESS.balance, ethBalanceBeforeCore + amountIn);
        assertEq(address(executor).balance, ethBalanceBeforeExecutor - amountIn);

        assertEq(
            USDT.balanceOf(CORE_ADDRESS), usdtBalanceBeforeCore - amountOut
        );
        assertEq(
            USDT.balanceOf(address(executor)),
            usdtBalanceBeforeExecutor + amountOut
        );
    }

    // Same test case as in swap_encoder::tests::ekubo::test_encode_swap_multi
    function testMultiHopSwap() public {
        bytes memory data = abi.encodePacked(
            uint8(TokenTransfer.TransferType.TRANSFER_TO_PROTOCOL), // transferType
            address(executor), // receiver
            NATIVE_TOKEN_ADDRESS, // tokenIn
            USDC_ADDR, // tokenOut of 1st swap
            ORACLE_CONFIG, // config of 1st swap
            USDT_ADDR, // tokenOut of 2nd swap
            bytes32(
                0x00000000000000000000000000000000000000000001a36e2eb1c43200000032
            ) // config of 2nd swap (0.0025% fee & 0.005% base pool)
        );
        multiHopSwap(data);
    }

    // Data is generated by test case in swap_encoder::tests::ekubo::test_encode_swap_multi
    function testMultiHopSwapIntegration() public {
        multiHopSwap(
            hex"00ca4f73fe97d0b987a0d12b39bbd562c779bab6f60000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4851d02a5948496a67827242eabc5725531342527c000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000001a36e2eb1c43200000032"
        );
    }
}
