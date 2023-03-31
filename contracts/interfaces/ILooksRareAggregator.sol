// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

enum CollectionType {
    ERC721,
    ERC1155
}
/**
 * @param signer The order's maker
 * @param collection The address of the ERC721/ERC1155 token to be purchased
 * @param collectionType 0 for ERC721, 1 for ERC1155
 * @param tokenIds The IDs of the tokens to be purchased
 * @param amounts Always 1 when ERC721, can be > 1 if ERC1155
 * @param price The *taker bid* price to pay for the order
 * @param currency The order's currency, address(0) for ETH
 * @param startTime The timestamp when the order starts becoming valid
 * @param endTime The timestamp when the order stops becoming valid
 * @param signature split to v,r,s for LooksRare
 */
struct BasicOrder {
    address signer;
    address collection;
    CollectionType collectionType;
    uint256[] tokenIds;
    uint256[] amounts;
    uint256 price;
    address currency;
    uint256 startTime;
    uint256 endTime;
    bytes signature;
}

/**
 * @param amount ERC20 transfer amount
 * @param currency ERC20 transfer currency
 */
struct TokenTransfer {
    uint256 amount;
    address currency;
}

interface ILooksRareAggregator {
    /**
     * @param proxy The marketplace proxy's address
     * @param selector The marketplace proxy's function selector
     * @param orders Orders to be executed by the marketplace
     * @param ordersExtraData Extra data for each order, specific for each marketplace
     * @param extraData Extra data specific for each marketplace
     */
    struct TradeData {
        address proxy;
        bytes4 selector;
        BasicOrder[] orders;
        bytes[] ordersExtraData;
        bytes extraData;
    }

    /**
     * @notice Execute NFT sweeps in different marketplaces in a
     *         single transaction
     * @param tokenTransfers Aggregated ERC20 token transfers for all markets
     * @param tradeData Data object to be passed downstream to each
     *                  marketplace's proxy for execution
     * @param originator The address that originated the transaction,
     *                   hard coded as msg.sender if it is called directly
     * @param recipient The address to receive the purchased NFTs
     * @param isAtomic Flag to enable atomic trades (all or nothing)
     *                 or partial trades
     */
    function execute(
        TokenTransfer[] calldata tokenTransfers,
        TradeData[] calldata tradeData,
        address originator,
        address recipient,
        bool isAtomic
    ) external payable;

    /**
     * @notice Emitted when a marketplace proxy's function is enabled.
     * @param proxy The marketplace proxy's address
     * @param selector The marketplace proxy's function selector
     */
    event FunctionAdded(address proxy, bytes4 selector);

    /**
     * @notice Emitted when a marketplace proxy's function is disabled.
     * @param proxy The marketplace proxy's address
     * @param selector The marketplace proxy's function selector
     */
    event FunctionRemoved(address proxy, bytes4 selector);

    /**
     * @notice Emitted when execute is complete
     * @param sweeper The address that submitted the transaction
     */
    event Sweep(address sweeper);

    error AlreadySet();
    error ETHTransferFail();
    error InvalidFunction();
    error UseERC20EnabledLooksRareAggregator();
}

interface IERC20EnabledLooksRareAggregator {
    /**
     * @notice Execute NFT sweeps in different marketplaces
     *         in a single transaction
     * @param tokenTransfers Aggregated ERC20 token transfers for all markets
     * @param tradeData Data object to be passed downstream to
     *                  each marketplace's proxy for execution
     * @param recipient The address to receive the purchased NFTs
     * @param isAtomic Flag to enable atomic trades (all or nothing)
     *                 or partial trades
     */
    function execute(
        TokenTransfer[] calldata tokenTransfers,
        ILooksRareAggregator.TradeData[] calldata tradeData,
        address recipient,
        bool isAtomic
    ) external payable;

    error UseLooksRareAggregatorDirectly();
}
