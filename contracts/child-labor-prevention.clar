;; Child Labor Prevention Contract
;; Monitors and prevents use of underage workers in supply chains

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-WORKER-NOT-FOUND (err u301))
(define-constant ERR-INVALID-AGE (err u302))
(define-constant ERR-UNDERAGE-WORKER (err u303))
(define-constant MINIMUM-WORK-AGE u16)
(define-constant HAZARDOUS-WORK-AGE u18)

;; Data Variables
(define-data-var next-verification-id uint u1)
(define-data-var next-violation-id uint u1)

;; Data Maps
(define-map age-verifications
  { verification-id: uint }
  {
    worker-id: uint,
    factory-id: uint,
    birth-date-hash: (buff 32),
    document-type: (string-ascii 30),
    document-hash: (buff 32),
    verified-age: uint,
    verification-date: uint,
    verified-by: principal,
    status: (string-ascii 20)
  }
)

(define-map worker-profiles
  { worker-id: uint }
  {
    verification-id: uint,
    current-age: uint,
    work-type: (string-ascii 50),
    is-hazardous: bool,
    employment-status: (string-ascii 20),
    guardian-consent: bool
  }
)

(define-map violations
  { violation-id: uint }
  {
    factory-id: uint,
    worker-id: uint,
    violation-type: (string-ascii 50),
    severity: (string-ascii 20),
    detected-date: uint,
    reported-by: principal,
    status: (string-ascii 20),
    remediation-plan: (string-ascii 200)
  }
)

(define-map remediation-actions
  { violation-id: uint }
  {
    action-taken: (string-ascii 200),
    completion-date: uint,
    verified-by: principal,
    follow-up-required: bool
  }
)

;; Public Functions

;; Verify worker age
(define-public (verify-worker-age
  (worker-id uint)
  (factory-id uint)
  (birth-date-hash (buff 32))
  (document-type (string-ascii 30))
  (document-hash (buff 32))
  (verified-age uint))
  (let ((verification-id (var-get next-verification-id)))
    (asserts! (>= verified-age MINIMUM-WORK-AGE) ERR-UNDERAGE-WORKER)
    (asserts! (> (len document-type) u0) ERR-INVALID-AGE)
    (map-set age-verifications
      { verification-id: verification-id }
      {
        worker-id: worker-id,
        factory-id: factory-id,
        birth-date-hash: birth-date-hash,
        document-type: document-type,
        document-hash: document-hash,
        verified-age: verified-age,
        verification-date: block-height,
        verified-by: tx-sender,
        status: "verified"
      }
    )
    (var-set next-verification-id (+ verification-id u1))
    (ok verification-id)
  )
)

;; Register worker profile
(define-public (register-worker-profile
  (worker-id uint)
  (verification-id uint)
  (work-type (string-ascii 50))
  (is-hazardous bool)
  (guardian-consent bool))
  (let ((verification (unwrap! (map-get? age-verifications { verification-id: verification-id }) ERR-WORKER-NOT-FOUND)))
    (asserts! (is-eq (get worker-id verification) worker-id) ERR-WORKER-NOT-FOUND)
    (if is-hazardous
      (asserts! (>= (get verified-age verification) HAZARDOUS-WORK-AGE) ERR-UNDERAGE-WORKER)
      true
    )
    (map-set worker-profiles
      { worker-id: worker-id }
      {
        verification-id: verification-id,
        current-age: (get verified-age verification),
        work-type: work-type,
        is-hazardous: is-hazardous,
        employment-status: "active",
        guardian-consent: guardian-consent
      }
    )
    (ok true)
  )
)

;; Report violation
(define-public (report-violation
  (factory-id uint)
  (worker-id uint)
  (violation-type (string-ascii 50))
  (severity (string-ascii 20))
  (remediation-plan (string-ascii 200)))
  (let ((violation-id (var-get next-violation-id)))
    (asserts! (> (len violation-type) u0) ERR-INVALID-AGE)
    (asserts! (> (len severity) u0) ERR-INVALID-AGE)
    (map-set violations
      { violation-id: violation-id }
      {
        factory-id: factory-id,
        worker-id: worker-id,
        violation-type: violation-type,
        severity: severity,
        detected-date: block-height,
        reported-by: tx-sender,
        status: "open",
        remediation-plan: remediation-plan
      }
    )
    (var-set next-violation-id (+ violation-id u1))
    (ok violation-id)
  )
)

;; Record remediation action
(define-public (record-remediation
  (violation-id uint)
  (action-taken (string-ascii 200))
  (follow-up-required bool))
  (begin
    (asserts! (is-some (map-get? violations { violation-id: violation-id })) ERR-WORKER-NOT-FOUND)
    (asserts! (> (len action-taken) u0) ERR-INVALID-AGE)
    (map-set remediation-actions
      { violation-id: violation-id }
      {
        action-taken: action-taken,
        completion-date: block-height,
        verified-by: tx-sender,
        follow-up-required: follow-up-required
      }
    )
    (let ((violation (unwrap! (map-get? violations { violation-id: violation-id }) ERR-WORKER-NOT-FOUND)))
      (map-set violations
        { violation-id: violation-id }
        (merge violation { status: "resolved" })
      )
    )
    (ok true)
  )
)

;; Update worker employment status
(define-public (update-employment-status (worker-id uint) (status (string-ascii 20)))
  (let ((profile (unwrap! (map-get? worker-profiles { worker-id: worker-id }) ERR-WORKER-NOT-FOUND)))
    (map-set worker-profiles
      { worker-id: worker-id }
      (merge profile { employment-status: status })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get age verification
(define-read-only (get-age-verification (verification-id uint))
  (map-get? age-verifications { verification-id: verification-id })
)

;; Get worker profile
(define-read-only (get-worker-profile (worker-id uint))
  (map-get? worker-profiles { worker-id: worker-id })
)

;; Get violation details
(define-read-only (get-violation (violation-id uint))
  (map-get? violations { violation-id: violation-id })
)

;; Get remediation action
(define-read-only (get-remediation (violation-id uint))
  (map-get? remediation-actions { violation-id: violation-id })
)

;; Check if worker is eligible for work type
(define-read-only (check-work-eligibility (worker-id uint) (is-hazardous bool))
  (match (map-get? worker-profiles { worker-id: worker-id })
    profile
    (let ((age (get current-age profile)))
      (if is-hazardous
        (ok (>= age HAZARDOUS-WORK-AGE))
        (ok (>= age MINIMUM-WORK-AGE))
      )
    )
    (err u404)
  )
)

;; Get minimum ages
(define-read-only (get-minimum-ages)
  {
    minimum-work-age: MINIMUM-WORK-AGE,
    hazardous-work-age: HAZARDOUS-WORK-AGE
  }
)
