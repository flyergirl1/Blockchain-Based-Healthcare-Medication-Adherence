;; Provider Verification Contract
;; Validates healthcare entities and manages their credentials

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_LICENSE (err u103))

;; Provider data structure
(define-map providers
  { provider-id: principal }
  {
    name: (string-ascii 100),
    license-number: (string-ascii 50),
    specialty: (string-ascii 50),
    verified: bool,
    registration-block: uint
  }
)

;; Admin principals who can verify providers
(define-map admins principal bool)

;; Initialize contract owner as admin
(map-set admins CONTRACT_OWNER true)

;; Register a new healthcare provider
(define-public (register-provider (name (string-ascii 100))
                                 (license-number (string-ascii 50))
                                 (specialty (string-ascii 50)))
  (let ((provider-id tx-sender))
    (asserts! (is-none (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_EXISTS)
    (asserts! (> (len license-number) u0) ERR_INVALID_LICENSE)
    (ok (map-set providers
         { provider-id: provider-id }
         {
           name: name,
           license-number: license-number,
           specialty: specialty,
           verified: false,
           registration-block: block-height
         }))))

;; Verify a provider (admin only)
(define-public (verify-provider (provider-id principal))
  (begin
    (asserts! (default-to false (map-get? admins tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_NOT_FOUND)
    (ok (map-set providers
         { provider-id: provider-id }
         (merge (unwrap-panic (map-get? providers { provider-id: provider-id }))
                { verified: true })))))

;; Get provider information
(define-read-only (get-provider (provider-id principal))
  (map-get? providers { provider-id: provider-id }))

;; Check if provider is verified
(define-read-only (is-verified-provider (provider-id principal))
  (match (map-get? providers { provider-id: provider-id })
    provider (get verified provider)
    false))

;; Add admin (owner only)
(define-public (add-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set admins new-admin true))))
