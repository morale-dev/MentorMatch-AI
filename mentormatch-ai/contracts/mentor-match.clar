;; MentorMatch AI - Decentralized mentorship platform
;; Manages session bookings, feedback, and payments

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-status (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-insufficient-balance (err u106))
(define-constant err-mentor-inactive (err u107))
(define-constant err-invalid-rating (err u108))
(define-constant err-session-expired (err u109))
(define-constant min-session-amount u1000000) ;; 1 STX minimum

;; Data vars
(define-data-var session-nonce uint u0)
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee
(define-data-var total-platform-fees uint u0)
(define-data-var min-feedback-score uint u1)
(define-data-var max-feedback-score uint u5)

;; Data maps
(define-map sessions
    { session-id: uint }
    {
        mentor: principal,
        mentee: principal,
        amount: uint,
        status: (string-ascii 20),
        feedback-score: uint,
        created-at: uint,
        completed-at: uint
    }
)

(define-map mentors
    { mentor: principal }
    { 
        active: bool, 
        total-sessions: uint,
        total-earnings: uint,
        average-rating: uint,
        specialization: (string-ascii 50)
    }
)

(define-map mentees
    { mentee: principal }
    {
        total-sessions: uint,
        active-sessions: uint
    }
)

(define-map mentor-ratings
    { mentor: principal, rater: principal }
    { rating: uint, session-id: uint }
)

(define-map dispute-sessions
    { session-id: uint }
    {
        disputed-by: principal,
        reason: (string-ascii 200),
        resolved: bool
    }
)

;; Read-only functions
(define-read-only (get-session (session-id uint))
    (map-get? sessions { session-id: session-id })
)

(define-read-only (get-mentor (mentor principal))
    (map-get? mentors { mentor: mentor })
)

(define-read-only (get-mentee (mentee principal))
    (map-get? mentees { mentee: mentee })
)

(define-read-only (get-session-nonce)
    (ok (var-get session-nonce))
)

(define-read-only (get-platform-fee-percentage)
    (ok (var-get platform-fee-percentage))
)

(define-read-only (get-total-platform-fees)
    (ok (var-get total-platform-fees))
)

(define-read-only (get-mentor-rating (mentor principal) (rater principal))
    (map-get? mentor-ratings { mentor: mentor, rater: rater })
)

(define-read-only (get-dispute (session-id uint))
    (map-get? dispute-sessions { session-id: session-id })
)

(define-read-only (is-mentor-active (mentor principal))
    (match (map-get? mentors { mentor: mentor })
        mentor-data (ok (get active mentor-data))
        (ok false)
    )
)

(define-read-only (calculate-platform-fee (amount uint))
    (ok (/ (* amount (var-get platform-fee-percentage)) u100))
)

(define-read-only (calculate-mentor-payout (amount uint))
    (let
        (
            (fee (/ (* amount (var-get platform-fee-percentage)) u100))
        )
        (ok (- amount fee))
    )
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (register-mentor (specialization (string-ascii 50)))
    (begin
        (asserts! (is-none (map-get? mentors { mentor: tx-sender })) err-already-exists)
        (ok (map-set mentors
            { mentor: tx-sender }
            { 
                active: true, 
                total-sessions: u0,
                total-earnings: u0,
                average-rating: u0,
                specialization: specialization
            }
        ))
    )
)

(define-public (deactivate-mentor)
    (let
        (
            (mentor-data (unwrap! (map-get? mentors { mentor: tx-sender }) err-not-found))
        )
        (ok (map-set mentors
            { mentor: tx-sender }
            (merge mentor-data { active: false })
        ))
    )
)

(define-public (reactivate-mentor)
    (let
        (
            (mentor-data (unwrap! (map-get? mentors { mentor: tx-sender }) err-not-found))
        )
        (ok (map-set mentors
            { mentor: tx-sender }
            (merge mentor-data { active: true })
        ))
    )
)

(define-public (update-specialization (new-specialization (string-ascii 50)))
    (let
        (
            (mentor-data (unwrap! (map-get? mentors { mentor: tx-sender }) err-not-found))
        )
        (ok (map-set mentors
            { mentor: tx-sender }
            (merge mentor-data { specialization: new-specialization })
        ))
    )
)

;; #[allow(unchecked_data)]
(define-public (create-session (mentor principal) (amount uint))
    (let
        (
            (new-session-id (+ (var-get session-nonce) u1))
            (mentor-data (unwrap! (map-get? mentors { mentor: mentor }) err-not-found))
            (mentee-data (default-to { total-sessions: u0, active-sessions: u0 } 
                (map-get? mentees { mentee: tx-sender })))
        )
        (asserts! (get active mentor-data) err-mentor-inactive)
        (asserts! (>= amount min-session-amount) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set sessions
            { session-id: new-session-id }
            {
                mentor: mentor,
                mentee: tx-sender,
                amount: amount,
                status: "pending",
                feedback-score: u0,
                created-at: stacks-block-height,
                completed-at: u0
            }
        )
        (map-set mentees
            { mentee: tx-sender }
            { 
                total-sessions: (+ (get total-sessions mentee-data) u1),
                active-sessions: (+ (get active-sessions mentee-data) u1)
            }
        )
        (var-set session-nonce new-session-id)
        (ok new-session-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (cancel-session (session-id uint))
    (let
        (
            (session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found))
            (mentee-data (unwrap! (map-get? mentees { mentee: tx-sender }) err-not-found))
        )
        (asserts! (is-eq (get mentee session) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status session) "pending") err-invalid-status)
        (try! (as-contract (stx-transfer? (get amount session) tx-sender (get mentee session))))
        (map-set sessions
            { session-id: session-id }
            (merge session { status: "cancelled" })
        )
        (map-set mentees
            { mentee: tx-sender }
            (merge mentee-data { active-sessions: (- (get active-sessions mentee-data) u1) })
        )
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (complete-session (session-id uint) (feedback-score uint))
    (let
        (
            (session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found))
            (mentor-data (unwrap! (map-get? mentors { mentor: (get mentor session) }) err-not-found))
            (mentee-data (unwrap! (map-get? mentees { mentee: tx-sender }) err-not-found))
            (platform-fee (/ (* (get amount session) (var-get platform-fee-percentage)) u100))
            (mentor-payout (- (get amount session) platform-fee))
        )
        (asserts! (is-eq (get mentee session) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status session) "pending") err-invalid-status)
        (asserts! (and (>= feedback-score (var-get min-feedback-score)) 
                       (<= feedback-score (var-get max-feedback-score))) err-invalid-rating)
        
        ;; Transfer payout to mentor
        (try! (as-contract (stx-transfer? mentor-payout tx-sender (get mentor session))))
        
        ;; Update platform fees
        (var-set total-platform-fees (+ (var-get total-platform-fees) platform-fee))
        
        ;; Update session
        (map-set sessions
            { session-id: session-id }
            (merge session { 
                status: "completed", 
                feedback-score: feedback-score,
                completed-at: stacks-block-height
            })
        )
        
        ;; Update mentor stats
        (map-set mentors
            { mentor: (get mentor session) }
            (merge mentor-data {
                total-sessions: (+ (get total-sessions mentor-data) u1),
                total-earnings: (+ (get total-earnings mentor-data) mentor-payout)
            })
        )
        
        ;; Update mentee stats
        (map-set mentees
            { mentee: tx-sender }
            (merge mentee-data { active-sessions: (- (get active-sessions mentee-data) u1) })
        )
        
        (ok true)
    )
)

;; #[allow(unchecked_data)]
(define-public (rate-mentor (mentor principal) (rating uint) (session-id uint))
    (let
        (
            (session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found))
        )
        (asserts! (is-eq (get mentee session) tx-sender) err-unauthorized)
        (asserts! (is-eq (get mentor session) mentor) err-unauthorized)
        (asserts! (is-eq (get status session) "completed") err-invalid-status)
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
        
        (ok (map-set mentor-ratings
            { mentor: mentor, rater: tx-sender }
            { rating: rating, session-id: session-id }
        ))
    )
)

;; #[allow(unchecked_data)]
(define-public (dispute-session (session-id uint) (reason (string-ascii 200)))
    (let
        (
            (session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found))
        )
        (asserts! (or (is-eq (get mentee session) tx-sender) 
                      (is-eq (get mentor session) tx-sender)) err-unauthorized)
        (asserts! (is-eq (get status session) "pending") err-invalid-status)
        
        (ok (map-set dispute-sessions
            { session-id: session-id }
            {
                disputed-by: tx-sender,
                reason: reason,
                resolved: false
            }
        ))
    )
)

;; #[allow(unchecked_data)]
(define-public (resolve-dispute (session-id uint) (refund-mentee bool))
    (let
        (
            (session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found))
            (dispute (unwrap! (map-get? dispute-sessions { session-id: session-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get resolved dispute)) err-invalid-status)
        
        (if refund-mentee
            (try! (as-contract (stx-transfer? (get amount session) tx-sender (get mentee session))))
            (try! (as-contract (stx-transfer? (get amount session) tx-sender (get mentor session))))
        )
        
        (map-set dispute-sessions
            { session-id: session-id }
            (merge dispute { resolved: true })
        )
        
        (map-set sessions
            { session-id: session-id }
            (merge session { status: "resolved" })
        )
        
        (ok true)
    )
)

;; Admin functions
(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-fee u20) err-invalid-amount) ;; Max 20% fee
        (ok (var-set platform-fee-percentage new-fee))
    )
)

(define-public (withdraw-platform-fees (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= amount (var-get total-platform-fees)) err-insufficient-balance)
        (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
        (var-set total-platform-fees (- (var-get total-platform-fees) amount))
        (ok true)
    )
)

(define-public (update-feedback-range (min-score uint) (max-score uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (< min-score max-score) err-invalid-rating)
        (var-set min-feedback-score min-score)
        (var-set max-feedback-score max-score)
        (ok true)
    )
)

;; Emergency pause function
;; #[allow(unchecked_data)]
(define-public (emergency-refund (session-id uint))
    (let
        (
            (session (unwrap! (map-get? sessions { session-id: session-id }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq (get status session) "pending") err-invalid-status)
        (try! (as-contract (stx-transfer? (get amount session) tx-sender (get mentee session))))
        (map-set sessions
            { session-id: session-id }
            (merge session { status: "refunded" })
        )
        (ok true)
    )
)