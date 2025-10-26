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