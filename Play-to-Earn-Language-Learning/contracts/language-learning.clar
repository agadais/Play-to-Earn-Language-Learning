;; Play-to-Earn Language Learning Platform
;; A blockchain-based language learning game where players earn tokens for completing lessons and helping others

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_LESSON (err u101))
(define-constant ERR_LESSON_ALREADY_COMPLETED (err u102))
(define-constant ERR_INSUFFICIENT_TOKENS (err u103))
(define-constant ERR_INVALID_DIFFICULTY (err u104))
(define-constant ERR_INVALID_LANGUAGE (err u105))
(define-constant ERR_LESSON_NOT_FOUND (err u106))
(define-constant ERR_ALREADY_RATED (err u107))
(define-constant ERR_INVALID_RATING (err u108))

;; Data Variables
(define-data-var next-lesson-id uint u1)
(define-data-var total-tokens-minted uint u0)
(define-data-var platform-fee-rate uint u5) ;; 5% platform fee

;; Token Settings
(define-data-var base-lesson-reward uint u10) ;; 10 tokens for completing a lesson
(define-data-var help-reward uint u5) ;; 5 tokens for helping others
(define-data-var streak-bonus-multiplier uint u2) ;; 2x multiplier for streaks

;; Maps
(define-map user-profiles
    principal
    {
        total-lessons-completed: uint,
        total-tokens-earned: uint,
        current-streak: uint,
        preferred-language: (string-ascii 20),
        level: uint,
        last-activity: uint
    }
)

(define-map lesson-data
    uint ;; lesson-id
    {
        creator: principal,
        title: (string-ascii 100),
        language: (string-ascii 20),
        difficulty: uint, ;; 1-5 scale
        content-hash: (string-ascii 64),
        reward-amount: uint,
        completion-count: uint,
        average-rating: uint,
        total-ratings: uint,
        is-active: bool
    }
)

(define-map user-lesson-completions
    {user: principal, lesson-id: uint}
    {
        completed-at: uint,
        score: uint, ;; 0-100 score
        time-spent: uint
    }
)

(define-map user-token-balance
    principal
    uint
)

(define-map lesson-ratings
    {user: principal, lesson-id: uint}
    {
        rating: uint, ;; 1-5 stars
        feedback: (string-ascii 200)
    }
)

(define-map daily-streaks
    principal
    {
        current-streak: uint,
        longest-streak: uint,
        last-activity-day: uint
    }
)

(define-map language-stats
    (string-ascii 20)
    {
        total-lessons: uint,
        total-completions: uint,
        active-learners: uint
    }
)

;; Public Functions

;; Initialize user profile
(define-public (create-user-profile (preferred-language (string-ascii 20)))
    (let ((caller tx-sender))
        (if (is-none (map-get? user-profiles caller))
            (begin
                (map-set user-profiles caller {
                    total-lessons-completed: u0,
                    total-tokens-earned: u0,
                    current-streak: u0,
                    preferred-language: preferred-language,
                    level: u1,
                    last-activity: block-height
                })
                (map-set user-token-balance caller u0)
                (ok "Profile created successfully"))
            (err u200))
    )
)

;; Create a new lesson
(define-public (create-lesson 
    (title (string-ascii 100))
    (language (string-ascii 20))
    (difficulty uint)
    (content-hash (string-ascii 64))
    (reward-amount uint))
    (let ((lesson-id (var-get next-lesson-id))
          (caller tx-sender))
        (asserts! (and (> difficulty u0) (<= difficulty u5)) ERR_INVALID_DIFFICULTY)
        (asserts! (> (len title) u0) ERR_INVALID_LESSON)
        
        (map-set lesson-data lesson-id {
            creator: caller,
            title: title,
            language: language,
            difficulty: difficulty,
            content-hash: content-hash,
            reward-amount: reward-amount,
            completion-count: u0,
            average-rating: u0,
            total-ratings: u0,
            is-active: true
        })
        
        (var-set next-lesson-id (+ lesson-id u1))
        
        ;; Update language stats
        (update-language-stats language true)
        
        (ok lesson-id)
    )
)

;; Complete a lesson
(define-public (complete-lesson (lesson-id uint) (score uint) (time-spent uint))
    (let ((caller tx-sender)
          (lesson (unwrap! (map-get? lesson-data lesson-id) ERR_LESSON_NOT_FOUND))
          (user-profile (unwrap! (map-get? user-profiles caller) ERR_UNAUTHORIZED)))
        
        (asserts! (get is-active lesson) ERR_INVALID_LESSON)
        (asserts! (and (>= score u0) (<= score u100)) ERR_INVALID_RATING)
        (asserts! (is-none (map-get? user-lesson-completions {user: caller, lesson-id: lesson-id})) 
                 ERR_LESSON_ALREADY_COMPLETED)
        
        ;; Record lesson completion
        (map-set user-lesson-completions {user: caller, lesson-id: lesson-id} {
            completed-at: block-height,
            score: score,
            time-spent: time-spent
        })
        
        ;; Calculate rewards
        (let ((base-reward (get reward-amount lesson))
              (difficulty-bonus (* (get difficulty lesson) u2))
              (score-bonus (/ (* score u10) u100))
              (streak-multiplier (calculate-streak-multiplier caller))
              (total-reward (* (+ base-reward difficulty-bonus score-bonus) streak-multiplier)))
            
            ;; Update user profile
            (map-set user-profiles caller (merge user-profile {
                total-lessons-completed: (+ (get total-lessons-completed user-profile) u1),
                total-tokens-earned: (+ (get total-tokens-earned user-profile) total-reward),
                last-activity: block-height,
                level: (calculate-user-level (+ (get total-lessons-completed user-profile) u1))
            }))
            
            ;; Update token balance
            (update-token-balance caller total-reward)
            
            ;; Update lesson stats
            (map-set lesson-data lesson-id (merge lesson {
                completion-count: (+ (get completion-count lesson) u1)
            }))
            
            ;; Update streak
            (update-user-streak caller)
            
            (var-set total-tokens-minted (+ (var-get total-tokens-minted) total-reward))
            
            (ok total-reward)
        )
    )
)

;; Rate a completed lesson
(define-public (rate-lesson (lesson-id uint) (rating uint) (feedback (string-ascii 200)))
    (let ((caller tx-sender)
          (lesson (unwrap! (map-get? lesson-data lesson-id) ERR_LESSON_NOT_FOUND)))
        
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
        (asserts! (is-some (map-get? user-lesson-completions {user: caller, lesson-id: lesson-id})) 
                 ERR_LESSON_NOT_FOUND)
        (asserts! (is-none (map-get? lesson-ratings {user: caller, lesson-id: lesson-id})) 
                 ERR_ALREADY_RATED)
        
        ;; Record rating
        (map-set lesson-ratings {user: caller, lesson-id: lesson-id} {
            rating: rating,
            feedback: feedback
        })
        
        ;; Update lesson average rating
        (let ((current-ratings (get total-ratings lesson))
              (current-average (get average-rating lesson))
              (new-total-ratings (+ current-ratings u1))
              (new-average (/ (+ (* current-average current-ratings) rating) new-total-ratings)))
            
            (map-set lesson-data lesson-id (merge lesson {
                average-rating: new-average,
                total-ratings: new-total-ratings
            }))
        )
        
        ;; Reward lesson creator for good ratings
        (if (>= rating u4)
            (update-token-balance (get creator lesson) (var-get help-reward))
            (ok u0))
        
        (ok rating)
    )
)

;; Help another user (mentor system)
(define-public (help-user (helped-user principal) (lesson-id uint))
    (let ((caller tx-sender)
          (helper-profile (unwrap! (map-get? user-profiles caller) ERR_UNAUTHORIZED)))
        
        (asserts! (not (is-eq caller helped-user)) ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? lesson-data lesson-id)) ERR_LESSON_NOT_FOUND)
        
        ;; Reward helper
        (let ((help-reward-amount (var-get help-reward)))
            (update-token-balance caller help-reward-amount)
            
            (map-set user-profiles caller (merge helper-profile {
                total-tokens-earned: (+ (get total-tokens-earned helper-profile) help-reward-amount)
            }))
            
            (var-set total-tokens-minted (+ (var-get total-tokens-minted) help-reward-amount))
            
            (ok help-reward-amount)
        )
    )
)

;; Transfer tokens between users
(define-public (transfer-tokens (recipient principal) (amount uint))
    (let ((caller tx-sender)
          (sender-balance (default-to u0 (map-get? user-token-balance caller)))
          (recipient-balance (default-to u0 (map-get? user-token-balance recipient))))
        
        (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_TOKENS)
        
        (map-set user-token-balance caller (- sender-balance amount))
        (map-set user-token-balance recipient (+ recipient-balance amount))
        
        (ok amount)
    )
)

;; Admin function to deactivate lessons
(define-public (deactivate-lesson (lesson-id uint))
    (let ((lesson (unwrap! (map-get? lesson-data lesson-id) ERR_LESSON_NOT_FOUND)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        
        (map-set lesson-data lesson-id (merge lesson {is-active: false}))
        (ok lesson-id)
    )
)

;; Private Functions

;; Calculate streak multiplier
(define-private (calculate-streak-multiplier (user principal))
    (let ((streak-info (default-to {current-streak: u0, longest-streak: u0, last-activity-day: u0}
                                  (map-get? daily-streaks user))))
        (if (> (get current-streak streak-info) u0)
            (var-get streak-bonus-multiplier)
            u1)
    )
)

;; Update user streak
(define-private (update-user-streak (user principal))
    (let ((today (/ block-height u144)) ;; Approximate blocks per day
          (streak-info (default-to {current-streak: u0, longest-streak: u0, last-activity-day: u0}
                                  (map-get? daily-streaks user))))
        
        (let ((last-day (get last-activity-day streak-info))
              (current-streak (get current-streak streak-info))
              (longest-streak (get longest-streak streak-info)))
            
            (if (is-eq today (+ last-day u1))
                ;; Consecutive day
                (let ((new-streak (+ current-streak u1)))
                    (map-set daily-streaks user {
                        current-streak: new-streak,
                        longest-streak: (if (> new-streak longest-streak) new-streak longest-streak),
                        last-activity-day: today
                    }))
                ;; New streak or same day
                (map-set daily-streaks user {
                    current-streak: u1,
                    longest-streak: longest-streak,
                    last-activity-day: today
                })
            )
        )
        (ok true)
    )
)

;; Calculate user level based on completed lessons
(define-private (calculate-user-level (lessons-completed uint))
    (cond
        ((< lessons-completed u10) u1)
        ((< lessons-completed u25) u2)
        ((< lessons-completed u50) u3)
        ((< lessons-completed u100) u4)
        (true u5)
    )
)

;; Update token balance
(define-private (update-token-balance (user principal) (amount uint))
    (let ((current-balance (default-to u0 (map-get? user-token-balance user))))
        (map-set user-token-balance user (+ current-balance amount))
        (ok amount)
    )
)

;; Update language statistics
(define-private (update-language-stats (language (string-ascii 20)) (new-lesson bool))
    (let ((current-stats (default-to {total-lessons: u0, total-completions: u0, active-learners: u0}
                                    (map-get? language-stats language))))
        (if new-lesson
            (map-set language-stats language (merge current-stats {
                total-lessons: (+ (get total-lessons current-stats) u1)
            }))
            (map-set language-stats language (merge current-stats {
                total-completions: (+ (get total-completions current-stats) u1)
            }))
        )
        (ok true)
    )
)

;; Read-only Functions

;; Get user profile
(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user)
)

;; Get user token balance
(define-read-only (get-token-balance (user principal))
    (default-to u0 (map-get? user-token-balance user))
)

;; Get lesson details
(define-read-only (get-lesson (lesson-id uint))
    (map-get? lesson-data lesson-id)
)

;; Get user lesson completion
(define-read-only (get-lesson-completion (user principal) (lesson-id uint))
    (map-get? user-lesson-completions {user: user, lesson-id: lesson-id})
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    {
        total-tokens-minted: (var-get total-tokens-minted),
        next-lesson-id: (var-get next-lesson-id),
        base-reward: (var-get base-lesson-reward)
    }
)

;; Get language statistics
(define-read-only (get-language-stats (language (string-ascii 20)))
    (map-get? language-stats language)
)