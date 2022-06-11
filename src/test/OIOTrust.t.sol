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
    address RecipientAddress = address(2);

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
            "data:application/json;base64,eyJkZXNjcmlwdGlvbiI6Ik9JT1RydXN0LCB0b2tlbnMgaGVsZDogXG4iLCJuYW1lIjoiT0lPVHJ1c3QgTkZUICMwIiwiaW1hZ2UiOiJkYXRhOmltYWdlL3N2ZztiYXNlNjQsIiwiYmFja2dyb3VuZF9jb2xvciI6ImZmZmZmZiIsImNyZWF0b3IiOiIweDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDEiLCJzdGFydF90aW1lIjoxNzI4MDAsImZyZXF1ZW5jeV9pbl9kYXlzIjoxLCJpbnN0YWxsbWVudHNfcGFpZCI6MCwidG9rZW5zIjpbXX0=",
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
            "data:application/json;base64,eyJkZXNjcmlwdGlvbiI6Ik9JT1RydXN0LCB0b2tlbnMgaGVsZDogXG4tIE15VG9rZW4gYW1vdW50OiAxMDAwMDAwMDAwMDAwMDAwMDAwIChkZWNpbWFscyAxOClcbiIsIm5hbWUiOiJPSU9UcnVzdCBORlQgIzAiLCJpbWFnZSI6ImRhdGE6aW1hZ2Uvc3ZnO2Jhc2U2NCwiLCJiYWNrZ3JvdW5kX2NvbG9yIjoiZmZmZmZmIiwiY3JlYXRvciI6IjB4MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMSIsInN0YXJ0X3RpbWUiOjE3MjgwMCwiZnJlcXVlbmN5X2luX2RheXMiOjEsImluc3RhbGxtZW50c19wYWlkIjowLCJ0b2tlbnMiOlt7Im5hbWUiOiJNeVRva2VuIiwiYW1vdW50IjoxMDAwMDAwMDAwMDAwMDAwMDAwLCJkZWNpbWFscyI6MTh9XX0=",
            "URI is not set"
        );
    }

    function testDistribution() public {
        cheats.startPrank(OwnerAddress);
        uint256 trustId = trust.createTrust(RecipientAddress, 2 days, 1);
        token.approve(address(trust), 1e18);
        trust.deposit(trustId, address(token), 1e18, 1e17);
        cheats.stopPrank();

        cheats.warp(3 days);

        trust.distribute(trustId, 1);

        assertEq(
            token.balanceOf(RecipientAddress),
            1e17,
            "Incorrect amount received"
        );

        cheats.warp(6 days);

        trust.distribute(trustId, 1);

        assertEq(
            token.balanceOf(RecipientAddress),
            4e17,
            "Incorrect amount received"
        );
    }
}
