;; Adherence Monitoring Contract
;; Tracks medication usage and adherence patterns

(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_PRESCRIPTION_NOT_FOUND (err u401))
(define-constant ERR_INVALID_ADHERENCE_DATA (err u402))
(define-constant ERR_DUPLICATE_ENTRY (err u403))

;; Adherence record structure
(define-map adherence-records
  { patient-id: principal, prescription-id: uint, date: uint }
  {
    taken: bool,
    time-taken: uint,
    recorded-block: uint,
    notes: (string-ascii 200)
  }
)

;; Adherence summary for prescriptions
(define-map adherence-summary
  { prescription-id: uint }
  {
    total-doses-prescribed: uint,
    total-doses-taken: uint,
    adherence-percentage: uint,
    last-updated: uint
  }
)

;; Record medication adherence
(define-public (record-adherence (prescription-id uint)
                                (date uint)
                                (taken bool)
                                (time-taken uint)
                                (notes (string-ascii 200)))
  (let ((patient-id tx-sender))
    ;; Check if record already exists for this date
    (asserts! (is-none (map-get? adherence-records
                                { patient-id: patient-id, prescription-id: prescription-id, date: date }))
              ERR_DUPLICATE_ENTRY)

    ;; Validate prescription exists and belongs to patient
    ;; In production, verify through prescription-tracking contract
    ;; (asserts! (contract-call? .prescription-tracking get-prescription prescription-id) ERR_PRESCRIPTION_NOT_FOUND)

    ;; Record adherence
    (map-set adherence-records
      { patient-id: patient-id, prescription-id: prescription-id, date: date }
      {
        taken: taken,
        time-taken: time-taken,
        recorded-block: block-height,
        notes: notes
      })

    ;; Update adherence summary
    (update-adherence-summary prescription-id)
    (ok true)))

;; Update adherence summary (internal function)
(define-private (update-adherence-summary (prescription-id uint))
  (let ((current-summary (default-to
                         { total-doses-prescribed: u0, total-doses-taken: u0, adherence-percentage: u0, last-updated: u0 }
                         (map-get? adherence-summary { prescription-id: prescription-id }))))
    ;; Simplified calculation - in production, this would be more sophisticated
    (let ((new-prescribed (+ (get total-doses-prescribed current-summary) u1))
          (new-taken (+ (get total-doses-taken current-summary) u1)))
      (map-set adherence-summary
        { prescription-id: prescription-id }
        {
          total-doses-prescribed: new-prescribed,
          total-doses-taken: new-taken,
          adherence-percentage: (if (> new-prescribed u0) (/ (* new-taken u100) new-prescribed) u0),
          last-updated: block-height
        }))))

;; Get adherence record
(define-read-only (get-adherence-record (patient-id principal) (prescription-id uint) (date uint))
  (map-get? adherence-records { patient-id: patient-id, prescription-id: prescription-id, date: date }))

;; Get adherence summary
(define-read-only (get-adherence-summary (prescription-id uint))
  (map-get? adherence-summary { prescription-id: prescription-id }))

;; Calculate adherence rate for a patient
(define-read-only (calculate-patient-adherence (patient-id principal) (prescription-id uint) (days uint))
  (let ((total-expected days)
        (total-taken u0)) ;; Simplified - would iterate through records in production
    (if (> total-expected u0)
        (/ (* total-taken u100) total-expected)
        u0)))

;; Bulk record adherence (for IoT devices or apps)
(define-public (bulk-record-adherence (records (list 10 { prescription-id: uint, date: uint, taken: bool, time-taken: uint })))
  (ok (map record-single-adherence records)))

(define-private (record-single-adherence (record { prescription-id: uint, date: uint, taken: bool, time-taken: uint }))
  (record-adherence
    (get prescription-id record)
    (get date record)
    (get taken record)
    (get time-taken record)
    ""))
