// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "ds-test/test.sol";
import "./CheatCodes.sol";
import "./TestToken.sol";

import "../OIOTrust.sol";

contract OIOTrustTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    OIOTrust trust;
    TestToken token;

    address OwnerAddress = address(1);
    address RecipientAddress = address(1);

    function setUp() public {
        cheats.startPrank(OwnerAddress);
        trust = new OIOTrust();
        token = new TestToken();
        token.mint(OwnerAddress, 10e18);
        cheats.stopPrank();
    }

    function testCreate() public {
        cheats.prank(OwnerAddress);
        trust.createTrust(RecipientAddress, 2 days, 1);

        assertEq(trust.totalSupply(), 1, "Incorrect NFT minted");
        assertEq(trust.ownerOf(0), RecipientAddress, "Isn't owner");
        assertEq(
            trust.tokenURI(0),
            "data:application/json;base64,eyJkZXNjcmlwdGlvbiI6Ik9JT1RydXN0LCB0b2tlbnMgaGVsZDogCiIsIm5hbWUiOiJPSU9UcnVzdCBORlQgIzAiLGltYWdlOiJkYXRhOmltYWdlL3N2ZztiYXNlNjQsUEhOMlp6NDhMM04yWno0PSIsImJhY2tncm91bmRfY29sb3IiOiJmZmZmZmYifQ==",
            "URI is not set"
        );
    }

    function testCreateAndFund() public {
        cheats.startPrank(OwnerAddress);
        trust.createTrust(RecipientAddress, 2 days, 1);
        token.approve(address(trust), 1e18);
        trust.deposit(0, address(token), 1e18, 1 days);
        cheats.stopPrank();

        assertEq(
            trust.tokenURI(0),
            "data:application/json;base64,eyJkZXNjcmlwdGlvbiI6Ik9JT1RydXN0LCB0b2tlbnMgaGVsZDogCi0gTXlUb2tlbiBhbW91bnQ6IDEwMDAwMDAwMDAwMDAwMDAwMDAgKGRlY2ltYWxzIDE4KQoiLCJuYW1lIjoiT0lPVHJ1c3QgTkZUICMwIixpbWFnZToiZGF0YTppbWFnZS9zdmc7YmFzZTY0LFBITjJaejQ4TDNOMlp6ND0iLCJiYWNrZ3JvdW5kX2NvbG9yIjoiZmZmZmZmIn0=",
            "URI is not set"
        );
    }

    function testDistribution() public {
        cheats.startPrank(OwnerAddress);
        trust.createTrust(RecipientAddress, 2 days, 1);
        token.approve(address(trust), 1e18);
        trust.deposit(0, address(token), 1e18, 1e17);
        cheats.stopPrank();

        cheats.warp(3 days + 1 seconds);

        trust.distribute(0, 1);

        assertEq(token.balanceOf(RecipientAddress), 1e17, "Incorrect amount received");
    }
}
