;; Patient Verification Contract
;; Manages patient identities and privacy-preserving verification

(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PATIENT_EXISTS (err u201))
(define-constant ERR_PATIENT_NOT_FOUND (err u202))
(define-constant ERR_INVALID_DATA (err u203))

;; Patient data structure (privacy-preserving)
(define-map patients
  { patient-id: principal }
  {
    encrypted-data-hash: (buff 32),
    age-range: uint, ;; 1=18-30, 2=31-50, 3=51-70, 4=70+
    verified: bool,
    registration-block: uint,
    consent-given: bool
  }
)

;; Healthcare providers who can verify patients
(define-map authorized-verifiers principal bool)

;; Register a new patient
(define-public (register-patient (encrypted-data-hash (buff 32))
                                (age-range uint))
  (let ((patient-id tx-sender))
    (asserts! (is-none (map-get? patients { patient-id: patient-id })) ERR_PATIENT_EXISTS)
    (asserts! (and (>= age-range u1) (<= age-range u4)) ERR_INVALID_DATA)
    (ok (map-set patients
         { patient-id: patient-id }
         {
           encrypted-data-hash: encrypted-data-hash,
           age-range: age-range,
           verified: false,
           registration-block: block-height,
           consent-given: false
         }))))

;; Give consent for data usage
(define-public (give-consent)
  (let ((patient-id tx-sender))
    (asserts! (is-some (map-get? patients { patient-id: patient-id })) ERR_PATIENT_NOT_FOUND)
    (ok (map-set patients
         { patient-id: patient-id }
         (merge (unwrap-panic (map-get? patients { patient-id: patient-id }))
                { consent-given: true })))))

;; Verify patient (authorized verifier only)
(define-public (verify-patient (patient-id principal))
  (begin
    (asserts! (default-to false (map-get? authorized-verifiers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? patients { patient-id: patient-id })) ERR_PATIENT_NOT_FOUND)
    (ok (map-set patients
         { patient-id: patient-id }
         (merge (unwrap-panic (map-get? patients { patient-id: patient-id }))
                { verified: true })))))

;; Get patient information (privacy-preserving)
(define-read-only (get-patient (patient-id principal))
  (map-get? patients { patient-id: patient-id }))

;; Check if patient is verified and consented
(define-read-only (is-verified-patient (patient-id principal))
  (match (map-get? patients { patient-id: patient-id })
    patient (and (get verified patient) (get consent-given patient))
    false))

;; Authorize verifier
(define-public (authorize-verifier (verifier principal))
  (begin
    ;; In production, this should check against provider verification contract
    (ok (map-set authorized-verifiers verifier true))))
