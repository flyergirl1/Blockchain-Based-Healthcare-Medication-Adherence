;; Prescription Tracking Contract
;; Records and manages medication prescriptions

(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_PRESCRIPTION_EXISTS (err u301))
(define-constant ERR_PRESCRIPTION_NOT_FOUND (err u302))
(define-constant ERR_INVALID_PRESCRIPTION (err u303))
(define-constant ERR_PATIENT_NOT_VERIFIED (err u304))

;; Prescription data structure
(define-map prescriptions
  { prescription-id: uint }
  {
    patient-id: principal,
    provider-id: principal,
    medication-name: (string-ascii 100),
    dosage: (string-ascii 50),
    frequency: uint, ;; times per day
    duration-days: uint,
    prescribed-block: uint,
    active: bool
  }
)

;; Counter for prescription IDs
(define-data-var prescription-counter uint u0)

;; Patient to prescriptions mapping
(define-map patient-prescriptions
  { patient-id: principal }
  { prescription-ids: (list 100 uint) }
)

;; Create a new prescription
(define-public (create-prescription (patient-id principal)
                                   (medication-name (string-ascii 100))
                                   (dosage (string-ascii 50))
                                   (frequency uint)
                                   (duration-days uint))
  (let ((prescription-id (+ (var-get prescription-counter) u1))
        (provider-id tx-sender))
    ;; Validate inputs
    (asserts! (> (len medication-name) u0) ERR_INVALID_PRESCRIPTION)
    (asserts! (> frequency u0) ERR_INVALID_PRESCRIPTION)
    (asserts! (> duration-days u0) ERR_INVALID_PRESCRIPTION)

    ;; In production, verify provider and patient through other contracts
    ;; (asserts! (contract-call? .provider-verification is-verified-provider provider-id) ERR_UNAUTHORIZED)
    ;; (asserts! (contract-call? .patient-verification is-verified-patient patient-id) ERR_PATIENT_NOT_VERIFIED)

    ;; Create prescription
    (map-set prescriptions
      { prescription-id: prescription-id }
      {
        patient-id: patient-id,
        provider-id: provider-id,
        medication-name: medication-name,
        dosage: dosage,
        frequency: frequency,
        duration-days: duration-days,
        prescribed-block: block-height,
        active: true
      })

    ;; Update patient prescriptions list
    (let ((current-prescriptions (default-to { prescription-ids: (list) }
                                            (map-get? patient-prescriptions { patient-id: patient-id }))))
      (map-set patient-prescriptions
        { patient-id: patient-id }
        { prescription-ids: (unwrap-panic (as-max-len?
                                          (append (get prescription-ids current-prescriptions) prescription-id)
                                          u100)) }))

    ;; Update counter
    (var-set prescription-counter prescription-id)
    (ok prescription-id)))

;; Get prescription details
(define-read-only (get-prescription (prescription-id uint))
  (map-get? prescriptions { prescription-id: prescription-id }))

;; Get patient prescriptions
(define-read-only (get-patient-prescriptions (patient-id principal))
  (map-get? patient-prescriptions { patient-id: patient-id }))

;; Deactivate prescription
(define-public (deactivate-prescription (prescription-id uint))
  (let ((prescription (unwrap! (map-get? prescriptions { prescription-id: prescription-id }) ERR_PRESCRIPTION_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get provider-id prescription)) ERR_UNAUTHORIZED)
    (ok (map-set prescriptions
         { prescription-id: prescription-id }
         (merge prescription { active: false })))))

;; Get current prescription counter
(define-read-only (get-prescription-counter)
  (var-get prescription-counter))
