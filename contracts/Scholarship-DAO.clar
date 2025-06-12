(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-APPLICATION-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-NOT-ACTIVE (err u104))

(define-data-var dao-owner principal tx-sender)
(define-data-var min-votes uint u3)
(define-data-var treasury-balance uint u0)

(define-map dao-members
    principal
    bool
)
(define-map scholarship-applications
    uint
    {
        applicant: principal,
        amount: uint,
        status: (string-ascii 20),
        votes: uint,
        voters: (list 50 principal),
    }
)

(define-data-var application-counter uint u0)

(define-public (initialize-dao (owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-owner)) ERR-NOT-AUTHORIZED)
        (var-set dao-owner owner)
        (ok true)
    )
)

(define-public (add-member (member principal))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-owner)) ERR-NOT-AUTHORIZED)
        (map-set dao-members member true)
        (ok true)
    )
)

(define-public (remove-member (member principal))
    (begin
        (asserts! (is-eq tx-sender (var-get dao-owner)) ERR-NOT-AUTHORIZED)
        (map-delete dao-members member)
        (ok true)
    )
)

(define-public (submit-application (amount uint))
    (let ((application-id (+ (var-get application-counter) u1)))
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (map-set scholarship-applications application-id {
            applicant: tx-sender,
            amount: amount,
            status: "pending",
            votes: u0,
            voters: (list),
        })
        (var-set application-counter application-id)
        (ok application-id)
    )
)

(define-public (vote-on-application (application-id uint))
    (let (
            (application (unwrap! (map-get? scholarship-applications application-id)
                ERR-APPLICATION-NOT-FOUND
            ))
            (is-member (default-to false (map-get? dao-members tx-sender)))
        )
        (asserts! is-member ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status application) "pending") ERR-NOT-ACTIVE)
        (asserts! (not (is-some (index-of? (get voters application) tx-sender)))
            ERR-ALREADY-VOTED
        )
        (map-set scholarship-applications application-id
            (merge application {
                votes: (+ (get votes application) u1),
                voters: (unwrap-panic (as-max-len? (append (get voters application) tx-sender) u50)),
            })
        )
        (unwrap! (process-application application-id) (err u500))
        (ok true)
    )
)

(define-public (fund-treasury (amount uint))
    (begin
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (ok true)
    )
)

(define-private (process-application (application-id uint))
    (let ((application (unwrap-panic (map-get? scholarship-applications application-id))))
        (if (>= (get votes application) (var-get min-votes))
            (if (<= (get amount application) (var-get treasury-balance))
                (begin
                    (var-set treasury-balance
                        (- (var-get treasury-balance) (get amount application))
                    )
                    (map-set scholarship-applications application-id
                        (merge application { status: "approved" })
                    )
                    (ok true)
                )
                (begin
                    (map-set scholarship-applications application-id
                        (merge application { status: "rejected" })
                    )
                    (ok true)
                )
            )
            (ok true)
        )
    )
)

(define-read-only (get-application (application-id uint))
    (map-get? scholarship-applications application-id)
)

(define-read-only (get-treasury-balance)
    (ok (var-get treasury-balance))
)

(define-read-only (is-dao-member (member principal))
    (default-to false (map-get? dao-members member))
)
