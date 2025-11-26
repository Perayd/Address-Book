// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title AddressBook - per-user contact book for EVM networks
/// @author
/// @notice Each account (msg.sender) manages its own contacts. Contacts are lightweight structs and can be listed with pagination.
contract AddressBook {
    struct Contact {
        uint256 id;         // contact id unique per owner (starts at 1)
        address wallet;     // contact Ethereum address (can be zero if none)
        string name;        // name (UTF-8)
        string phone;       // phone number (free-form)
        string email;       // email (free-form)
        bool exists;        // record existence (false when removed)
    }

    // owner => next contact id (starts at 1)
    mapping(address => uint256) private _nextId;

    // owner => contactId => Contact
    mapping(address => mapping(uint256 => Contact)) private _contacts;

    // owner => array of contactIds (keeps insertion order; removed entries remain but have exists == false)
    mapping(address => uint256[]) private _contactIds;

    // owner => contactWallet => contactId (for quick find). If 0 => not set.
    mapping(address => mapping(address => uint256)) private _walletToId;

    // Events
    event ContactAdded(address indexed owner, uint256 indexed contactId, address indexed wallet);
    event ContactUpdated(address indexed owner, uint256 indexed contactId, address indexed wallet);
    event ContactRemoved(address indexed owner, uint256 indexed contactId);

    constructor() {}

    /// @notice Add a new contact to caller's address book
    /// @param wallet contact wallet address (can be address(0) if you want no wallet)
    /// @param name contact name
    /// @param phone contact phone
    /// @param email contact email
    /// @return contactId assigned id (>=1)
    function addContact(
        address wallet,
        string calldata name,
        string calldata phone,
        string calldata email
    ) external returns (uint256) {
        // If wallet is non-zero and already mapped to a contact id for this owner, prevent duplicate
        if (wallet != address(0)) {
            uint256 existingId = _walletToId[msg.sender][wallet];
            require(existingId == 0 || !_contacts[msg.sender][existingId].exists, "wallet already added");
        }

        uint256 id = _nextId[msg.sender] + 1;
        _nextId[msg.sender] = id;

        Contact memory c = Contact({
            id: id,
            wallet: wallet,
            name: name,
            phone: phone,
            email: email,
            exists: true
        });

        _contacts[msg.sender][id] = c;
        _contactIds[msg.sender].push(id);

        if (wallet != address(0)) {
            _walletToId[msg.sender][wallet] = id;
        }

        emit ContactAdded(msg.sender, id, wallet);
        return id;
    }

    /// @notice Update an existing contact owned by caller
    /// @param contactId contact id to update
    /// @param wallet new wallet address (can be address(0))
    /// @param name new name
    /// @param phone new phone
    /// @param email new email
    function updateContact(
        uint256 contactId,
        address wallet,
        string calldata name,
        string calldata phone,
        string calldata email
    ) external {
        Contact storage c = _contacts[msg.sender][contactId];
        require(c.exists, "contact not found");

        // If changing wallet, update wallet -> id mapping
        if (c.wallet != wallet) {
            // remove old mapping if non-zero
            if (c.wallet != address(0)) {
                delete _walletToId[msg.sender][c.wallet];
            }
            // ensure new wallet not colliding with another existing contact
            if (wallet != address(0)) {
                uint256 otherId = _walletToId[msg.sender][wallet];
                require(otherId == 0 || otherId == contactId || !_contacts[msg.sender][otherId].exists, "wallet already in use");
                _walletToId[msg.sender][wallet] = contactId;
            }
            c.wallet = wallet;
        }

        c.name = name;
        c.phone = phone;
        c.email = email;

        emit ContactUpdated(msg.sender, contactId, wallet);
    }

    /// @notice Remove a contact owned by caller (soft delete: clears exists and wallet mapping)
    /// @param contactId id to remove
    function removeContact(uint256 contactId) external {
        Contact storage c = _contacts[msg.sender][contactId];
        require(c.exists, "contact not found");

        // clear wallet mapping
        if (c.wallet != address(0)) {
            delete _walletToId[msg.sender][c.wallet];
        }

        // mark removed
        c.exists = false;

        emit ContactRemoved(msg.sender, contactId);
    }

    /// @notice Return a contact for the calling user by id
    /// @param contactId id of the contact
    /// @return Contact struct
    function getMyContact(uint256 contactId) external view returns (Contact memory) {
        Contact memory c = _contacts[msg.sender][contactId];
        require(c.exists, "contact not found");
        return c;
    }

    /// @notice Get contact id by wallet address for the caller (0 means not found)
    /// @param wallet contact wallet
    /// @return contactId or 0
    function findMyContactIdByWallet(address wallet) external view returns (uint256) {
        uint256 id = _walletToId[msg.sender][wallet];
        if (id == 0) return 0;
        if (!_contacts[msg.sender][id].exists) return 0;
        return id;
    }

    /// @notice List contacts of an owner with pagination (read-only)
    /// @param owner address whose contacts to read
    /// @param start index to start (0-based index into internal id array)
    /// @param limit maximum number of contacts to return
    /// @return contacts slice (only existing contacts)
    function listContacts(address owner, uint256 start, uint256 limit) external view returns (Contact[] memory) {
        uint256[] storage ids = _contactIds[owner];
        if (start >= ids.length || limit == 0) {
            return new Contact;
        }

        uint256 count = 0;
        // first compute how many valid entries we will return (up to limit)
        uint256 idx = start;
        while (idx < ids.length && count < limit) {
            Contact memory c = _contacts[owner][ids[idx]];
