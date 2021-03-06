// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract OIOTrust is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    // Data model
    struct TrustDeposit {
        address erc20Token;
        uint256 amount;
        uint256 installmentAmount;
    }
    struct TrustInfo {
        address creator;
        mapping(uint256 => TrustDeposit) deposits;
        Counters.Counter depositsCount;
        bool revokable;
        uint256 startTime;
        uint256 frequencyInDays;
        uint256 installmentsPaid;
    }
    mapping(uint256 => TrustInfo) private trusts;

    uint256 private lastDistribution;

    // Contract
    constructor() ERC721("OIOTrust", "OIO") {}

    event TrustCreated(address creator, uint256 trustId);

    /**
     * Create a new trust
     * @param to Recipient of the trust
     * @param startTime Start time
     * @param frequencyInDays Frequency in days
     */
    function createTrust(
        address to,
        uint256 startTime,
        uint256 frequencyInDays
    ) public returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        TrustInfo storage info = trusts[tokenId];
        info.creator = msg.sender;
        info.startTime = startTime;
        info.frequencyInDays = frequencyInDays;
        info.installmentsPaid = 0;

        emit TrustCreated(msg.sender, tokenId);
        return tokenId;
    }

    /**
     * Update the trust parameters
     * @param trustId ID of the trust
     * @param startTime Start time
     * @param frequencyInDays Frequency in days
     */
    function updateTrust(
        uint256 trustId,
        uint256 startTime,
        uint256 frequencyInDays
    ) public {
        TrustInfo storage info = trusts[trustId];
        require(info.creator == msg.sender, "Not creator");
        info.startTime = startTime;
        info.frequencyInDays = frequencyInDays;
    }

    /**
     * Deposit tokens to trust
     * @param trustId ID of the trust
     * @param erc20Token Token address
     * @param amount Amount
     * @param installmentAmount Installment amount
     */
    function deposit(
        uint256 trustId,
        address erc20Token,
        uint256 amount,
        uint256 installmentAmount
    ) public {
        TrustInfo storage info = trusts[trustId];
        require(info.creator == msg.sender, "Not creator");

        // Transfer token to contract
        IERC20 token = IERC20(erc20Token);
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "Token allowance not enough"
        );
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // Keep track of amount
        for (uint256 i = 0; i < info.depositsCount.current(); i++) {
            // If already exists
            if (info.deposits[i].erc20Token == erc20Token) {
                info.deposits[i].amount += amount;
                info.deposits[i].installmentAmount = installmentAmount;
                return;
            }
        }

        // If not exists alreay
        uint256 depositId = info.depositsCount.current();
        info.depositsCount.increment();
        info.deposits[depositId].erc20Token = erc20Token;
        info.deposits[depositId].amount = amount;
        info.deposits[depositId].installmentAmount = installmentAmount;
    }

    /**
     * Withdraw tokens from the trust
     * @param trustId ID of the trust
     * @param erc20Token Token address
     * @param amount Amount
     */
    function withdraw(
        uint256 trustId,
        address erc20Token,
        uint256 amount
    ) public {
        TrustInfo storage info = trusts[trustId];
        require(info.creator == msg.sender, "Not creator");
        IERC20 token = IERC20(erc20Token);

        // Verify that deposit exists and balance is sufficient

        for (uint256 i = 0; i < info.depositsCount.current(); i++) {
            if (info.deposits[i].erc20Token == erc20Token) {
                // check if the trust has the required amount
                require(
                    info.deposits[i].amount >= amount,
                    "Tried to withdraw a bigger amount than present in the trust"
                );

                // Transfer ERC20 to caller
                require(token.transfer(msg.sender, amount), "Transfer failed");
                info.deposits[i].amount -= amount;
                return;
            }
        }
        revert("Trying to withdraw a non existing token");
    }

    /**
     * Distribute function called every day
     */
    function distribute(uint256 start, uint256 end) public {
        // TODO: fees
        lastDistribution = block.timestamp;

        // For every started trust
        for (
            uint256 trustId = start;
            trustId < Math.min(end, _tokenIdCounter.current());
            trustId++
        ) {
            if (trusts[trustId].startTime <= block.timestamp) {
                uint256 expectedInstallmentsPaid = (block.timestamp -
                    trusts[trustId].startTime) /
                    (trusts[trustId].frequencyInDays * 1 days);
                uint256 differenceInstallmentsPaid = expectedInstallmentsPaid -
                    trusts[trustId].installmentsPaid;

                // Pay out to the NFT holder
                address holder = this.ownerOf(trustId);
                // For every trust deposit transfer the amount to the holder
                for (
                    uint256 depositId = 0;
                    depositId < trusts[trustId].depositsCount.current();
                    depositId++
                ) {
                    uint256 requiredAmount = trusts[trustId]
                        .deposits[depositId]
                        .installmentAmount * differenceInstallmentsPaid;
                    IERC20 token = IERC20(
                        trusts[trustId].deposits[depositId].erc20Token
                    );
                    // Last installment
                    if (
                        requiredAmount >
                        trusts[trustId].deposits[depositId].amount
                    ) {
                        requiredAmount = trusts[trustId]
                            .deposits[depositId]
                            .amount;
                    }

                    token.transfer(holder, requiredAmount);
                }
                trusts[trustId].installmentsPaid += differenceInstallmentsPaid;
            }
        }
    }

    // TODO: getters

    function getTokenAmount(uint256 trustId, address erc20Token)
        public
        view
        returns (uint256)
    {
        TrustInfo storage info = trusts[trustId];
        require(info.creator == msg.sender, "Not creator");
        for (uint256 i = 0; i < info.depositsCount.current(); i++) {
            if (info.deposits[i].erc20Token == erc20Token) {
                return info.deposits[i].amount;
            }
        }
        revert("Trying to access a non existing token");
    }

    // URI generation

    string constant _dataUri = "data:application/json;base64,";

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        address creator = trusts[tokenId].creator;
        bytes memory description = "OIOTrust, tokens held: \\n";
        bytes memory tokensJson = "";
        for (
            uint256 depositId = 0;
            depositId < trusts[tokenId].depositsCount.current();
            depositId++
        ) {
            IERC20Metadata token = IERC20Metadata(
                trusts[tokenId].deposits[depositId].erc20Token
            );
            description = abi.encodePacked(
                description,
                "- ",
                token.name(),
                " amount: ",
                Strings.toString(trusts[tokenId].deposits[depositId].amount),
                " (decimals ",
                Strings.toString(token.decimals()),
                ")\\n"
            );
            if (depositId > 0) {
                tokensJson = abi.encodePacked(tokensJson, ",");
            }
            tokensJson = abi.encodePacked(
                tokensJson,
                '{"name":"',
                token.name(),
                '","symbol":"',
                token.symbol(),
                '","amount":',
                Strings.toString(trusts[tokenId].deposits[depositId].amount),
                ',"installment_amount":',
                Strings.toString(
                    trusts[tokenId].deposits[depositId].installmentAmount
                ),
                ',"decimals":',
                Strings.toString(token.decimals()),
                "}"
            );
        }
        bytes memory json = abi.encodePacked(
            '{"description":"',
            description,
            '","name":"OIOTrust NFT #',
            Strings.toString(tokenId),
            '","image":"https://oiotrust.netlify.app/logo.svg"',
            ',"background_color":"000000"',
            ',"creator":"',
            Strings.toHexString(creator),
            '","start_time":',
            Strings.toString(trusts[tokenId].startTime)
        );
        json = abi.encodePacked(
            json,
            ',"frequency_in_days":',
            Strings.toString(trusts[tokenId].frequencyInDays),
            ',"installments_paid":',
            Strings.toString(trusts[tokenId].installmentsPaid),
            ',"tokens":[',
            tokensJson,
            "]}"
        );
        return string(abi.encodePacked(_dataUri, Base64.encode(json)));
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
