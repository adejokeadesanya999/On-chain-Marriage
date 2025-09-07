;; Comprehensive On-chain Marriage Contract
;; A full-featured Clarity smart contract for couples to mint joint NFTs as symbolic blockchain marriage licenses
;; Includes proposal system, witnesses, divorce, renewal, and comprehensive marriage management

;; Define the NFT
(define-non-fungible-token marriage-certificate uint)

;; Data variables
(define-data-var next-marriage-id uint u1)
(define-data-var contract-admin principal tx-sender)
(define-data-var marriage-fee uint u1000000) ;; 1 STX in microSTX
(define-data-var witness-requirement uint u2)
(define-data-var total-marriages uint u0)
(define-data-var total-divorces uint u0)

;; Data maps
(define-map marriages 
  uint 
  {
    partner1: principal,
    partner2: principal,
    marriage-date: uint,
    metadata-uri: (string-ascii 256),
    status: (string-ascii 20), ;; "active", "divorced", "annulled"
    witnesses: (list 5 principal),
    renewal-date: (optional uint),
    divorce-date: (optional uint)
  }
)

(define-map partner-to-marriage principal uint)

(define-map marriage-proposals
  uint
  {
    proposer: principal,
    proposed-to: principal,
    message: (string-ascii 500),
    proposal-date: uint,
    status: (string-ascii 20), ;; "pending", "accepted", "rejected", "expired"
    metadata-uri: (string-ascii 256)
  }
)

(define-map proposal-witnesses uint (list 5 principal))
(define-map next-proposal-id principal uint)

(define-map emergency-contacts
  principal
  {
    contact1: (optional principal),
    contact2: (optional principal),
    beneficiary: (optional principal)
  }
)

(define-map marriage-anniversaries uint (list 10 uint))

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-already-married (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-marriage-not-found (err u102))
(define-constant err-cannot-marry-self (err u103))
(define-constant err-proposal-not-found (err u104))
(define-constant err-proposal-expired (err u105))
(define-constant err-proposal-already-responded (err u106))
(define-constant err-insufficient-witnesses (err u107))
(define-constant err-invalid-witness (err u108))
(define-constant err-marriage-not-active (err u109))
(define-constant err-insufficient-fee (err u110))
(define-constant err-proposal-to-self (err u111))
(define-constant err-already-has-proposal (err u112))
(define-constant err-not-divorced (err u113))
(define-constant err-too-early-for-renewal (err u114))

;; Proposal expiry (30 days in blocks, assuming ~10 min block time)
(define-constant proposal-expiry-blocks u4320)

;; Read-only functions
(define-read-only (get-marriage-details (marriage-id uint))
  (map-get? marriages marriage-id)
)

(define-read-only (get-partner-marriage (partner principal))
  (map-get? partner-to-marriage partner)
)

(define-read-only (is-married (partner principal))
  (match (map-get? partner-to-marriage partner)
    marriage-id (match (get-marriage-details marriage-id)
      marriage-data (is-eq (get status marriage-data) "active")
      false
    )
    false
  )
)

(define-read-only (get-next-marriage-id)
  (var-get next-marriage-id)
)

(define-read-only (get-marriage-certificate-owner (marriage-id uint))
  (nft-get-owner? marriage-certificate marriage-id)
)

(define-read-only (get-proposal-details (proposal-id uint))
  (map-get? marriage-proposals proposal-id)
)

(define-read-only (get-proposal-witnesses (proposal-id uint))
  (map-get? proposal-witnesses proposal-id)
)

(define-read-only (get-marriage-fee)
  (var-get marriage-fee)
)

(define-read-only (get-marriage-statistics)
  {
    total-marriages: (var-get total-marriages),
    total-divorces: (var-get total-divorces),
    active-marriages: (- (var-get total-marriages) (var-get total-divorces))
  }
)

(define-read-only (get-emergency-contacts (partner principal))
  (map-get? emergency-contacts partner)
)

(define-read-only (get-marriage-anniversaries (marriage-id uint))
  (map-get? marriage-anniversaries marriage-id)
)

(define-read-only (calculate-marriage-duration (marriage-id uint))
  (match (get-marriage-details marriage-id)
    marriage-data 
      (if (is-eq (get status marriage-data) "active")
        (ok (- block-height (get marriage-date marriage-data)))
        (match (get divorce-date marriage-data)
          divorce-date (ok (- divorce-date (get marriage-date marriage-data)))
          (ok u0)
        )
      )
    err-marriage-not-found
  )
)

(define-read-only (is-proposal-expired (proposal-id uint))
  (match (get-proposal-details proposal-id)
    proposal-data 
      (> (- block-height (get proposal-date proposal-data)) proposal-expiry-blocks)
    true
  )
)

;; Marriage proposal functions
(define-public (propose-marriage (partner principal) (message (string-ascii 500)) (metadata-uri (string-ascii 256)))
  (let 
    (
      (proposer tx-sender)
      (proposal-id (default-to u1 (map-get? next-proposal-id proposer)))
    )
    (asserts! (not (is-eq proposer partner)) err-proposal-to-self)
    (asserts! (not (is-married proposer)) err-already-married)
    (asserts! (not (is-married partner)) err-already-married)
    (asserts! (>= (stx-get-balance tx-sender) (var-get marriage-fee)) err-insufficient-fee)

    (map-set marriage-proposals proposal-id {
      proposer: proposer,
      proposed-to: partner,
      message: message,
      proposal-date: block-height,
      status: "pending",
      metadata-uri: metadata-uri
    })

    (map-set next-proposal-id proposer (+ proposal-id u1))

    (ok proposal-id)
  )
)

(define-public (accept-proposal (proposal-id uint) (witnesses (list 5 principal)))
  (let 
    (
      (proposal-data (unwrap! (get-proposal-details proposal-id) err-proposal-not-found))
      (proposer (get proposer proposal-data))
      (proposed-to (get proposed-to proposal-data))
      (marriage-id (var-get next-marriage-id))
    )
    (asserts! (is-eq tx-sender proposed-to) err-unauthorized)
    (asserts! (is-eq (get status proposal-data) "pending") err-proposal-already-responded)
    (asserts! (not (is-proposal-expired proposal-id)) err-proposal-expired)
    (asserts! (>= (len witnesses) (var-get witness-requirement)) err-insufficient-witnesses)
    (asserts! (not (is-married proposer)) err-already-married)
    (asserts! (not (is-married proposed-to)) err-already-married)

    (try! (validate-witnesses witnesses (list proposer proposed-to)))
    (try! (stx-transfer? (var-get marriage-fee) proposer (as-contract tx-sender)))
    (try! (nft-mint? marriage-certificate marriage-id proposer))

    (map-set marriages marriage-id {
      partner1: proposer,
      partner2: proposed-to,
      marriage-date: block-height,
      metadata-uri: (get metadata-uri proposal-data),
      status: "active",
      witnesses: witnesses,
      renewal-date: none,
      divorce-date: none
    })

    (map-set partner-to-marriage proposer marriage-id)
    (map-set partner-to-marriage proposed-to marriage-id)
    (map-set proposal-witnesses marriage-id witnesses)

    (map-set marriage-proposals proposal-id 
      (merge proposal-data { status: "accepted" })
    )

    (var-set next-marriage-id (+ marriage-id u1))
    (var-set total-marriages (+ (var-get total-marriages) u1))

    (ok marriage-id)
  )
)

(define-public (reject-proposal (proposal-id uint))
  (let 
    (
      (proposal-data (unwrap! (get-proposal-details proposal-id) err-proposal-not-found))
    )
    (asserts! (is-eq tx-sender (get proposed-to proposal-data)) err-unauthorized)
    (asserts! (is-eq (get status proposal-data) "pending") err-proposal-already-responded)

    (map-set marriage-proposals proposal-id 
      (merge proposal-data { status: "rejected" })
    )

    (ok true)
  )
)

;; Divorce and annulment functions
(define-public (request-divorce (marriage-id uint))
  (let 
    (
      (marriage-data (unwrap! (get-marriage-details marriage-id) err-marriage-not-found))
      (partner1 (get partner1 marriage-data))
      (partner2 (get partner2 marriage-data))
    )
    (asserts! (or (is-eq tx-sender partner1) (is-eq tx-sender partner2)) err-unauthorized)
    (asserts! (is-eq (get status marriage-data) "active") err-marriage-not-active)

    (map-set marriages marriage-id 
      (merge marriage-data { 
        status: "divorced",
        divorce-date: (some block-height)
      })
    )

    (map-delete partner-to-marriage partner1)
    (map-delete partner-to-marriage partner2)

    (var-set total-divorces (+ (var-get total-divorces) u1))

    (ok true)
  )
)

(define-public (annul-marriage (marriage-id uint))
  (let 
    (
      (marriage-data (unwrap! (get-marriage-details marriage-id) err-marriage-not-found))
      (partner1 (get partner1 marriage-data))
      (partner2 (get partner2 marriage-data))
    )
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-unauthorized)
    (asserts! (is-eq (get status marriage-data) "active") err-marriage-not-active)

    (map-set marriages marriage-id 
      (merge marriage-data { 
        status: "annulled",
        divorce-date: (some block-height)
      })
    )

    (map-delete partner-to-marriage partner1)
    (map-delete partner-to-marriage partner2)

    (var-set total-divorces (+ (var-get total-divorces) u1))

    (ok true)
  )
)

;; Renewal and anniversary functions
(define-public (renew-marriage (marriage-id uint) (new-metadata-uri (string-ascii 256)))
  (let 
    (
      (marriage-data (unwrap! (get-marriage-details marriage-id) err-marriage-not-found))
      (partner1 (get partner1 marriage-data))
      (partner2 (get partner2 marriage-data))
      (marriage-date (get marriage-date marriage-data))
      (one-year-blocks u52560) ;; Approximately 1 year in blocks
    )
    (asserts! (or (is-eq tx-sender partner1) (is-eq tx-sender partner2)) err-unauthorized)
    (asserts! (is-eq (get status marriage-data) "active") err-marriage-not-active)
    (asserts! (> (- block-height marriage-date) one-year-blocks) err-too-early-for-renewal)

    (map-set marriages marriage-id 
      (merge marriage-data { 
        renewal-date: (some block-height),
        metadata-uri: new-metadata-uri
      })
    )

    (let 
      (
        (current-anniversaries (default-to (list) (map-get? marriage-anniversaries marriage-id)))
        (new-anniversaries (unwrap-panic (as-max-len? (append current-anniversaries block-height) u10)))
      )
      (map-set marriage-anniversaries marriage-id new-anniversaries)
    )

    (ok true)
  )
)

;; Emergency contact management
(define-public (set-emergency-contacts 
  (contact1 (optional principal)) 
  (contact2 (optional principal)) 
  (beneficiary (optional principal)))
  (begin
    (map-set emergency-contacts tx-sender {
      contact1: contact1,
      contact2: contact2,
      beneficiary: beneficiary
    })
    (ok true)
  )
)

;; Witness validation helper
(define-private (validate-witnesses (witnesses (list 5 principal)) (partners (list 2 principal)))
  (let 
    (
      (witness-count (len witnesses))
      (required-count (var-get witness-requirement))
      (validation-result (validate-witnesses-not-partners witnesses partners))
    )
    (asserts! (>= witness-count required-count) err-insufficient-witnesses)
    (asserts! (validate-unique-witnesses witnesses) err-invalid-witness)
    (asserts! (get valid validation-result) err-invalid-witness)
    (ok true)
  )
)

(define-private (validate-unique-witnesses (witnesses (list 5 principal)))
  (is-eq (len witnesses) (len (fold check-duplicate witnesses (list))))
)

(define-private (check-duplicate (witness principal) (acc (list 5 principal)))
  (if (is-none (index-of acc witness))
    (unwrap-panic (as-max-len? (append acc witness) u5))
    acc
  )
)

(define-private (validate-witnesses-not-partners (witnesses (list 5 principal)) (partners (list 2 principal)))
  (let 
    (
      (partner1 (unwrap-panic (element-at partners u0)))
      (partner2 (unwrap-panic (element-at partners u1)))
    )
    (fold validate-single-witness witnesses { valid: true, partner1: partner1, partner2: partner2 })
  )
)

(define-private (validate-single-witness (witness principal) (acc { valid: bool, partner1: principal, partner2: principal }))
  (merge acc {
    valid: (and (get valid acc)
      (not (is-married witness))
      (not (is-eq witness (get partner1 acc)))
      (not (is-eq witness (get partner2 acc)))
    )
  })
)

;; Administrative functions
(define-public (set-marriage-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-unauthorized)
    (var-set marriage-fee new-fee)
    (ok true)
  )
)

(define-public (set-witness-requirement (new-requirement uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-unauthorized)
    (asserts! (<= new-requirement u5) (err u115)) ;; Max 5 witnesses
    (var-set witness-requirement new-requirement)
    (ok true)
  )
)

(define-public (withdraw-fees (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-admin)) err-unauthorized)
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

;; Legacy direct marriage function (bypasses proposal system)
(define-public (register-marriage-direct (partner2 principal) (metadata-uri (string-ascii 256)) (witnesses (list 5 principal)))
  (let 
    (
      (partner1 tx-sender)
      (marriage-id (var-get next-marriage-id))
    )
    (asserts! (not (is-eq partner1 partner2)) err-cannot-marry-self)
    (asserts! (not (is-married partner1)) err-already-married)
    (asserts! (not (is-married partner2)) err-already-married)
    (asserts! (>= (stx-get-balance tx-sender) (var-get marriage-fee)) err-insufficient-fee)

    (try! (validate-witnesses witnesses (list partner1 partner2)))
    (try! (stx-transfer? (var-get marriage-fee) tx-sender (as-contract tx-sender)))
    (try! (nft-mint? marriage-certificate marriage-id partner1))

    (map-set marriages marriage-id {
      partner1: partner1,
      partner2: partner2,
      marriage-date: block-height,
      metadata-uri: metadata-uri,
      status: "active",
      witnesses: witnesses,
      renewal-date: none,
      divorce-date: none
    })

    (map-set partner-to-marriage partner1 marriage-id)
    (map-set partner-to-marriage partner2 marriage-id)
    (map-set proposal-witnesses marriage-id witnesses)

    (var-set next-marriage-id (+ marriage-id u1))
    (var-set total-marriages (+ (var-get total-marriages) u1))

    (ok marriage-id)
  )
)

(define-public (transfer-marriage-certificate (marriage-id uint) (recipient principal))
  (let 
    (
      (marriage-details (unwrap! (get-marriage-details marriage-id) err-marriage-not-found))
      (partner1 (get partner1 marriage-details))
      (partner2 (get partner2 marriage-details))
    )
    (asserts! (or (is-eq tx-sender partner1) (is-eq tx-sender partner2)) err-unauthorized)
    (asserts! (is-eq (get status marriage-details) "active") err-marriage-not-active)
    (nft-transfer? marriage-certificate marriage-id tx-sender recipient)
  )
)

;; Marriage registry and search functions
(define-read-only (get-active-marriages-count)
  (- (var-get total-marriages) (var-get total-divorces))
)

(define-read-only (search-marriages-by-partner (partner principal))
  (map-get? partner-to-marriage partner)
)

(define-read-only (get-marriage-range (start-id uint) (end-id uint))
  (let 
    (
      (max-id (var-get next-marriage-id))
      (safe-end (if (< end-id max-id) end-id max-id))
    )
    {
      start-id: start-id,
      end-id: safe-end,
      total-in-range: (if (> safe-end start-id) (- safe-end start-id) u0)
    }
  )
)

(define-read-only (get-marriage-at-index (index uint))
  (if (< index (var-get next-marriage-id))
    (get-marriage-details index)
    none
  )
)

;; Remarriage function for divorced individuals
(define-public (remarry (new-partner principal) (metadata-uri (string-ascii 256)) (witnesses (list 5 principal)))
  (let 
    (
      (partner1 tx-sender)
      (marriage-id (var-get next-marriage-id))
    )
    (asserts! (not (is-eq partner1 new-partner)) err-cannot-marry-self)
    (asserts! (not (is-married partner1)) err-already-married)
    (asserts! (not (is-married new-partner)) err-already-married)
    (asserts! (>= (stx-get-balance tx-sender) (var-get marriage-fee)) err-insufficient-fee)

    (try! (validate-witnesses witnesses (list partner1 new-partner)))
    (try! (stx-transfer? (var-get marriage-fee) tx-sender (as-contract tx-sender)))
    (try! (nft-mint? marriage-certificate marriage-id partner1))

    (map-set marriages marriage-id {
      partner1: partner1,
      partner2: new-partner,
      marriage-date: block-height,
      metadata-uri: metadata-uri,
      status: "active",
      witnesses: witnesses,
      renewal-date: none,
      divorce-date: none
    })

    (map-set partner-to-marriage partner1 marriage-id)
    (map-set partner-to-marriage new-partner marriage-id)
    (map-set proposal-witnesses marriage-id witnesses)

    (var-set next-marriage-id (+ marriage-id u1))
    (var-set total-marriages (+ (var-get total-marriages) u1))

    (ok marriage-id)
  )
)

;; Advanced read-only functions
(define-read-only (get-marriage-by-partners (partner1 principal) (partner2 principal))
  (match (map-get? partner-to-marriage partner1)
    marriage-id1 
      (match (get-marriage-details marriage-id1)
        marriage-data
          (if (or (and (is-eq (get partner1 marriage-data) partner1) 
                       (is-eq (get partner2 marriage-data) partner2))
                  (and (is-eq (get partner1 marriage-data) partner2) 
                       (is-eq (get partner2 marriage-data) partner1)))
            (some marriage-id1)
            none
          )
        none
      )
    none
  )
)

(define-read-only (get-partner-history (partner principal))
  (let 
    (
      (current-marriage (map-get? partner-to-marriage partner))
    )
    {
      current-marriage: current-marriage,
      is-currently-married: (is-married partner),
      emergency-contacts: (map-get? emergency-contacts partner)
    }
  )
)

;; Get marriage certificate URI
(define-read-only (get-token-uri (marriage-id uint))
  (match (get-marriage-details marriage-id)
    marriage-data (ok (some (get metadata-uri marriage-data)))
    (ok none)
  )
)