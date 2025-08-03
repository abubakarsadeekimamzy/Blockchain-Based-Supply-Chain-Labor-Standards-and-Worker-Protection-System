;; Factory Working Conditions Monitoring Contract
;; Tracks workplace safety, hours, and conditions in manufacturing facilities

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-FACTORY-NOT-FOUND (err u101))
(define-constant ERR-INVALID-INPUT (err u102))
(define-constant ERR-ALREADY-EXISTS (err u103))

;; Data Variables
(define-data-var next-factory-id uint u1)

;; Data Maps
(define-map factories
  { factory-id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 200),
    owner: principal,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-map working-conditions
  { factory-id: uint, timestamp: uint }
  {
    temperature: uint,
    humidity: uint,
    noise-level: uint,
    air-quality: uint,
    safety-score: uint,
    recorded-by: principal
  }
)

(define-map working-hours
  { factory-id: uint, worker-id: uint, date: uint }
  {
    regular-hours: uint,
    overtime-hours: uint,
    break-time: uint,
    shift-type: (string-ascii 20)
  }
)

(define-map compliance-status
  { factory-id: uint }
  {
    overall-score: uint,
    last-inspection: uint,
    violations: uint,
    status: (string-ascii 20),
    next-inspection: uint
  }
)

;; Public Functions

;; Register a new factory
(define-public (register-factory (name (string-ascii 100)) (location (string-ascii 200)))
  (let ((factory-id (var-get next-factory-id)))
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> (len location) u0) ERR-INVALID-INPUT)
    (map-set factories
      { factory-id: factory-id }
      {
        name: name,
        location: location,
        owner: tx-sender,
        status: "active",
        created-at: block-height
      }
    )
    (var-set next-factory-id (+ factory-id u1))
    (ok factory-id)
  )
)

;; Record working conditions
(define-public (record-conditions
  (factory-id uint)
  (temperature uint)
  (humidity uint)
  (noise-level uint)
  (air-quality uint)
  (safety-score uint))
  (let ((factory (map-get? factories { factory-id: factory-id })))
    (asserts! (is-some factory) ERR-FACTORY-NOT-FOUND)
    (asserts! (<= temperature u50) ERR-INVALID-INPUT)
    (asserts! (<= humidity u100) ERR-INVALID-INPUT)
    (asserts! (<= noise-level u120) ERR-INVALID-INPUT)
    (asserts! (<= air-quality u500) ERR-INVALID-INPUT)
    (asserts! (<= safety-score u100) ERR-INVALID-INPUT)
    (map-set working-conditions
      { factory-id: factory-id, timestamp: block-height }
      {
        temperature: temperature,
        humidity: humidity,
        noise-level: noise-level,
        air-quality: air-quality,
        safety-score: safety-score,
        recorded-by: tx-sender
      }
    )
    (ok true)
  )
)

;; Record worker hours
(define-public (record-worker-hours
  (factory-id uint)
  (worker-id uint)
  (date uint)
  (regular-hours uint)
  (overtime-hours uint)
  (break-time uint)
  (shift-type (string-ascii 20)))
  (let ((factory (map-get? factories { factory-id: factory-id })))
    (asserts! (is-some factory) ERR-FACTORY-NOT-FOUND)
    (asserts! (<= regular-hours u12) ERR-INVALID-INPUT)
    (asserts! (<= overtime-hours u8) ERR-INVALID-INPUT)
    (asserts! (>= break-time u30) ERR-INVALID-INPUT)
    (map-set working-hours
      { factory-id: factory-id, worker-id: worker-id, date: date }
      {
        regular-hours: regular-hours,
        overtime-hours: overtime-hours,
        break-time: break-time,
        shift-type: shift-type
      }
    )
    (ok true)
  )
)

;; Update compliance status
(define-public (update-compliance
  (factory-id uint)
  (overall-score uint)
  (violations uint)
  (status (string-ascii 20)))
  (let ((factory (map-get? factories { factory-id: factory-id })))
    (asserts! (is-some factory) ERR-FACTORY-NOT-FOUND)
    (asserts! (<= overall-score u100) ERR-INVALID-INPUT)
    (map-set compliance-status
      { factory-id: factory-id }
      {
        overall-score: overall-score,
        last-inspection: block-height,
        violations: violations,
        status: status,
        next-inspection: (+ block-height u4320)
      }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get factory details
(define-read-only (get-factory (factory-id uint))
  (map-get? factories { factory-id: factory-id })
)

;; Get working conditions
(define-read-only (get-conditions (factory-id uint) (timestamp uint))
  (map-get? working-conditions { factory-id: factory-id, timestamp: timestamp })
)

;; Get worker hours
(define-read-only (get-worker-hours (factory-id uint) (worker-id uint) (date uint))
  (map-get? working-hours { factory-id: factory-id, worker-id: worker-id, date: date })
)

;; Get compliance status
(define-read-only (get-compliance (factory-id uint))
  (map-get? compliance-status { factory-id: factory-id })
)

;; Get next factory ID
(define-read-only (get-next-factory-id)
  (var-get next-factory-id)
)
