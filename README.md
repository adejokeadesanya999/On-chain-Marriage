💍 On-Chain Marriage Contract

A Clarity Smart Contract for Symbolic Blockchain Marriages on Stacks

📖 Overview

This smart contract implements a comprehensive on-chain marriage system using the Clarity language
.
Couples can propose, accept, and register marriages directly on-chain, mint a marriage NFT certificate, add witnesses, record anniversaries, and even manage divorces, annulments, and remarriages.

It also supports emergency contacts, renewals, and administrative management.

✨ Features
🔐 Core Marriage System

Marriage Certificate NFT: Each marriage is represented as a unique, non-fungible token (marriage-certificate).

Marriage Proposals: Propose with a message & metadata URI.

Witness Requirement: Minimum witnesses required for a valid marriage.

Direct Marriage: Skip proposals and register directly with mutual consent.

Remarriage: Divorced individuals can remarry with a new partner.

⚖️ Marriage Lifecycle

Proposal Management

Propose, accept, reject marriages.

Proposal expiry (30 days in blocks).

Marriage Management

Register marriage (direct or via proposal).

Record metadata & witnesses.

Renew marriage (after ~1 year in blocks).

Store anniversaries.

Dissolution

Divorce (requested by either partner).

Annulment (admin only).

📊 Data Tracking

Statistics: Track total marriages, divorces, and active marriages.

Duration: Calculate marriage duration (active or until divorce).

Anniversaries: Store up to 10 renewal/anniversary dates.

Emergency Contacts: Store up to 2 contacts + 1 beneficiary.

🛠️ Administrative Controls

Set marriage fees.

Adjust witness requirements (max 5).

Withdraw collected fees to admin account.

📂 Data Structures
Maps

marriages: Stores all marriage records.

partner-to-marriage: Maps each partner to their marriage ID.

marriage-proposals: Stores all proposals with details.

proposal-witnesses: Witnesses for proposals/marriages.

next-proposal-id: Tracks proposal IDs per proposer.

emergency-contacts: Stores optional contacts & beneficiary per partner.

marriage-anniversaries: Stores anniversaries per marriage.

Variables

next-marriage-id: Incremental marriage ID counter.

marriage-fee: Fee required to marry (default: 1 STX).

witness-requirement: Minimum witnesses required (default: 2).

total-marriages: Global counter of marriages.

total-divorces: Global counter of divorces.

contract-admin: Contract administrator.

⚡ Public Functions
Marriage Proposals

propose-marriage(partner, message, metadata-uri)

accept-proposal(proposal-id, witnesses)

reject-proposal(proposal-id)

Direct Registration

register-marriage-direct(partner2, metadata-uri, witnesses)

Marriage Lifecycle

remarry(new-partner, metadata-uri, witnesses)

renew-marriage(marriage-id, new-metadata-uri)

request-divorce(marriage-id)

annul-marriage(marriage-id)

NFT & Transfers

transfer-marriage-certificate(marriage-id, recipient)

Emergency Contacts

set-emergency-contacts(contact1, contact2, beneficiary)

Administration

set-marriage-fee(new-fee)

set-witness-requirement(new-requirement)

withdraw-fees(amount, recipient)

📊 Read-Only Functions

get-marriage-details(marriage-id)

get-partner-marriage(partner)

is-married(partner)

get-next-marriage-id()

get-marriage-certificate-owner(marriage-id)

get-proposal-details(proposal-id)

get-proposal-witnesses(proposal-id)

get-marriage-fee()

get-marriage-statistics()

get-emergency-contacts(partner)

get-marriage-anniversaries(marriage-id)

calculate-marriage-duration(marriage-id)

is-proposal-expired(proposal-id)

get-active-marriages-count()

search-marriages-by-partner(partner)

get-marriage-range(start-id, end-id)

get-marriage-at-index(index)

🔒 Private Helpers

validate-witnesses(witnesses, partners)

validate-unique-witnesses(witnesses)

check-duplicate(witness, acc)

validate-witnesses-not-partners(witnesses, partners)

validate-single-witness(witness, acc)

🚀 Deployment
Requirements

Stacks blockchain

Clarinet
 for local testing

Steps

Clone repo / copy contract.

Initialize Clarinet project:

clarinet new marriage-contract


Replace contracts/marriage-contract.clar with this contract.

Run tests / console:

clarinet console


Deploy on Stacks testnet or mainnet.

💡 Example Flow

Alice proposes to Bob:

(contract-call? .marriage propose-marriage 'SP123... "Will you marry me?" "ipfs://metadata")


Bob accepts with witnesses:

(contract-call? .marriage accept-proposal u1 (list 'SP456... 'SP789...))


Marriage certificate NFT minted for Alice.

Later they renew marriage after 1 year:

(contract-call? .marriage renew-marriage u1 "ipfs://new-anniversary")


If needed, divorce:

(contract-call? .marriage request-divorce u1)

📜 License

MIT License. Free to use, modify, and deploy.