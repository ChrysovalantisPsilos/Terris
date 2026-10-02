// node --test scripts/asc/certificates.test.mjs
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { pemFingerprints, ownCertificates } from './certificates.mjs'

// Fake DER bytes; only identity matters here.
const ours = Buffer.from('terris-run-certificate').toString('base64')
const budgeer = Buffer.from('budgeer-run-certificate').toString('base64')
const person = Buffer.from('owner-own-mac-certificate').toString('base64')
const pem = (b64) => `-----BEGIN CERTIFICATE-----\n${b64.match(/.{1,64}/g).join('\n')}\n-----END CERTIFICATE-----\n`

const cert = (id, content, type = 'DEVELOPMENT', name = 'Created via API') =>
  ({ id, attributes: { certificateContent: content, certificateType: type, name } })

test('only the certificate in this runner\'s keychain is ours', () => {
  const fingerprints = pemFingerprints(pem(ours))
  const all = [cert('a', ours), cert('b', budgeer), cert('c', person, 'DEVELOPMENT', 'Chrysovalantis Psilos')]
  assert.deepEqual(ownCertificates(all, fingerprints).map((c) => c.id), ['a'])
})

test('another pipeline\'s "Created via API" certificate is never ours', () => {
  const fingerprints = pemFingerprints(pem(ours))
  assert.deepEqual(ownCertificates([cert('b', budgeer)], fingerprints), [])
})

test('distribution certificates are never revoked, even if they match', () => {
  const fingerprints = pemFingerprints(pem(ours))
  assert.deepEqual(ownCertificates([cert('d', ours, 'DISTRIBUTION')], fingerprints), [])
})

test('an empty keychain matches nothing', () => {
  assert.equal(pemFingerprints('').size, 0)
  assert.deepEqual(ownCertificates([cert('a', ours)], new Set()), [])
})

test('several certificates in one PEM bundle', () => {
  assert.equal(pemFingerprints(pem(ours) + pem(person)).size, 2)
})
