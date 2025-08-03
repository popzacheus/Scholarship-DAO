(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-APPLICATION-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-NOT-ACTIVE (err u104))
(define-constant ERR-DEADLINE-PASSED (err u105))
(define-constant ERR-INVALID-DEADLINE (err u106))
(define-constant ERR-MILESTONE-NOT-FOUND (err u107))
(define-constant ERR-MILESTONE-COMPLETED (err u108))
(define-constant ERR-INSUFFICIENT-FUNDS (err u109))

(define-data-var dao-owner principal tx-sender)
(define-data-var min-votes uint u3)
(define-data-var treasury-balance uint u0)
(define-data-var milestone-counter uint u0)

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
        deadline: uint,
        total-disbursed: uint,
    }
)

(define-map scholarship-milestones
    uint
    {
        application-id: uint,
        description: (string-ascii 100),
        amount: uint,
        completed: bool,
        completion-votes: uint,
        completion-voters: (list 50 principal),
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

(define-public (submit-application
        (amount uint)
        (deadline uint)
    )
    (let ((application-id (+ (var-get application-counter) u1)))
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (> deadline burn-block-height) ERR-INVALID-DEADLINE)
        (map-set scholarship-applications application-id {
            applicant: tx-sender,
            amount: amount,
            status: "pending",
            votes: u0,
            voters: (list),
            deadline: deadline,
            total-disbursed: u0,
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
        (asserts! (<= burn-block-height (get deadline application))
            ERR-DEADLINE-PASSED
        )
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

(define-public (close-expired-application (application-id uint))
    (let (
            (application (unwrap! (map-get? scholarship-applications application-id)
                ERR-APPLICATION-NOT-FOUND
            ))
            (is-member (default-to false (map-get? dao-members tx-sender)))
        )
        (asserts! is-member ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status application) "pending") ERR-NOT-ACTIVE)
        (asserts! (> burn-block-height (get deadline application)) ERR-NOT-ACTIVE)
        (map-set scholarship-applications application-id
            (merge application { status: "expired" })
        )
        (ok true)
    )
)

(define-read-only (is-application-expired (application-id uint))
    (let ((application (unwrap! (map-get? scholarship-applications application-id)
            ERR-APPLICATION-NOT-FOUND
        )))
        (ok (> burn-block-height (get deadline application)))
    )
)

(define-public (create-milestone
        (application-id uint)
        (description (string-ascii 100))
        (amount uint)
    )
    (let (
            (application (unwrap! (map-get? scholarship-applications application-id)
                ERR-APPLICATION-NOT-FOUND
            ))
            (milestone-id (+ (var-get milestone-counter) u1))
            (is-member (default-to false (map-get? dao-members tx-sender)))
        )
        (asserts! is-member ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get status application) "approved") ERR-NOT-ACTIVE)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (map-set scholarship-milestones milestone-id {
            application-id: application-id,
            description: description,
            amount: amount,
            completed: false,
            completion-votes: u0,
            completion-voters: (list),
        })
        (var-set milestone-counter milestone-id)
        (ok milestone-id)
    )
)

(define-public (vote-milestone-completion (milestone-id uint))
    (let (
            (milestone (unwrap! (map-get? scholarship-milestones milestone-id)
                ERR-MILESTONE-NOT-FOUND
            ))
            (is-member (default-to false (map-get? dao-members tx-sender)))
        )
        (asserts! is-member ERR-NOT-AUTHORIZED)
        (asserts! (not (get completed milestone)) ERR-MILESTONE-COMPLETED)
        (asserts!
            (not (is-some (index-of? (get completion-voters milestone) tx-sender)))
            ERR-ALREADY-VOTED
        )
        (map-set scholarship-milestones milestone-id
            (merge milestone {
                completion-votes: (+ (get completion-votes milestone) u1),
                completion-voters: (unwrap-panic (as-max-len? (append (get completion-voters milestone) tx-sender)
                    u50
                )),
            })
        )
        (unwrap! (process-milestone-completion milestone-id) (err u500))
        (ok true)
    )
)

(define-private (process-milestone-completion (milestone-id uint))
    (let (
            (milestone (unwrap-panic (map-get? scholarship-milestones milestone-id)))
            (application-id (get application-id milestone))
            (application (unwrap-panic (map-get? scholarship-applications application-id)))
        )
        (if (>= (get completion-votes milestone) (var-get min-votes))
            (if (<= (get amount milestone) (var-get treasury-balance))
                (begin
                    (var-set treasury-balance
                        (- (var-get treasury-balance) (get amount milestone))
                    )
                    (map-set scholarship-milestones milestone-id
                        (merge milestone { completed: true })
                    )
                    (map-set scholarship-applications application-id
                        (merge application { total-disbursed: (+ (get total-disbursed application)
                            (get amount milestone)
                        ) }
                        ))
                    (ok true)
                )
                (err ERR-INSUFFICIENT-FUNDS)
            )
            (ok true)
        )
    )
)

(define-read-only (get-milestone (milestone-id uint))
    (map-get? scholarship-milestones milestone-id)
)

(define-read-only (get-application-progress (application-id uint))
    (let ((application (unwrap! (map-get? scholarship-applications application-id)
            ERR-APPLICATION-NOT-FOUND
        )))
        (ok {
            total-amount: (get amount application),
            total-disbursed: (get total-disbursed application),
            remaining: (- (get amount application) (get total-disbursed application)),
        })
    )
)
