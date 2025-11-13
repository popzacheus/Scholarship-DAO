(define-data-var next-id uint u1)

(define-map escrows
  { id: uint }
  {
    donor: principal,
    recipient: principal,
    amount: uint,
    unlock-height: uint,
    released: bool,
    canceled: bool,
  }
)

(define-read-only (get-next-id)
  (var-get next-id)
)

(define-read-only (get-escrow (id uint))
  (map-get? escrows { id: id })
)

(define-public (create-escrow
    (recipient principal)
    (amount uint)
    (unlock-height uint)
  )
  (if (<= amount u0)
    (err u1)
    (if (<= unlock-height burn-block-height)
      (err u2)
      (let (
          (id (var-get next-id))
          (contract-principal (as-contract tx-sender))
        )
        (match (stx-transfer? amount tx-sender contract-principal)
          ok-val (begin
            (map-set escrows { id: id } {
              donor: tx-sender,
              recipient: recipient,
              amount: amount,
              unlock-height: unlock-height,
              released: false,
              canceled: false,
            })
            (var-set next-id (+ id u1))
            (ok id)
          )
          err-val (err u3)
        )
      )
    )
  )
)

(define-public (withdraw (id uint))
  (match (map-get? escrows { id: id })
    escrow (let (
        (rec (get recipient escrow))
        (amt (get amount escrow))
        (unl (get unlock-height escrow))
        (rel (get released escrow))
        (can (get canceled escrow))
      )
      (if (and
          (is-eq rec tx-sender)
          (>= burn-block-height unl)
          (not rel)
          (not can)
        )
        (match (as-contract (stx-transfer? amt tx-sender rec))
          ok-val (begin
            (map-set escrows { id: id } {
              donor: (get donor escrow),
              recipient: rec,
              amount: amt,
              unlock-height: unl,
              released: true,
              canceled: can,
            })
            (ok true)
          )
          err-val (err u5)
        )
        (err u4)
      )
    )
    (err u6)
  )
)

(define-public (cancel (id uint))
  (match (map-get? escrows { id: id })
    escrow (let (
        (don (get donor escrow))
        (amt (get amount escrow))
        (unl (get unlock-height escrow))
        (rel (get released escrow))
        (can (get canceled escrow))
      )
      (if (and
          (is-eq don tx-sender)
          (< burn-block-height unl)
          (not rel)
          (not can)
        )
        (match (as-contract (stx-transfer? amt tx-sender don))
          ok-val (begin
            (map-set escrows { id: id } {
              donor: don,
              recipient: (get recipient escrow),
              amount: amt,
              unlock-height: unl,
              released: rel,
              canceled: true,
            })
            (ok true)
          )
          err-val (err u8)
        )
        (err u7)
      )
    )
    (err u6)
  )
)
