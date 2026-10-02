// Revokes the development certificate THIS TestFlight run created, and no
// other. Automatic signing on a fresh CI machine makes a new "Apple
// Development" certificate each run; left behind, they'd fill the team's
// slots. The team is shared with the expense tracker (Budgeer), whose CI
// makes the same kind of certificates, so the only safe test is identity:
// a certificate is ours only if it is in this runner's keychain (that's where
// the private key the run generated lives). Matched by SHA-256 of the DER.
// Never a person's own certificate, never a distribution one, never another
// pipeline's.
//
// Run by .github/workflows/ios-testflight.yml at the end of the job:
//   security find-certificate -a -c "Apple Development" -p > runner-certs.pem
//   node scripts/asc/certificates.mjs runner-certs.pem
import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import { createClient } from './api.mjs'

const DEVELOPMENT = new Set(['DEVELOPMENT', 'IOS_DEVELOPMENT'])

const sha256 = (der) => createHash('sha256').update(der).digest('hex')

// Fingerprints of every certificate in a PEM bundle.
export function pemFingerprints(pem) {
  const blocks = String(pem).match(/-----BEGIN CERTIFICATE-----[\s\S]*?-----END CERTIFICATE-----/g) ?? []
  return new Set(blocks.map((block) => {
    const body = block.replace(/-----(BEGIN|END) CERTIFICATE-----/g, '').replace(/\s+/g, '')
    return sha256(Buffer.from(body, 'base64'))
  }))
}

// The team's development certificates that are this runner's own.
export function ownCertificates(certificates, fingerprints) {
  return certificates.filter((c) => {
    const content = c.attributes?.certificateContent
    return DEVELOPMENT.has(c.attributes?.certificateType)
      && typeof content === 'string'
      && fingerprints.has(sha256(Buffer.from(content, 'base64')))
  })
}

async function main() {
  const pemPath = process.argv[2]
  const fingerprints = pemPath ? pemFingerprints(readFileSync(pemPath, 'utf8')) : new Set()
  if (fingerprints.size === 0) {
    console.log('No certificates in this runner\'s keychain: nothing to revoke.')
    return
  }
  const client = createClient({
    keyId: process.env.ASC_KEY_ID.trim(),
    issuerId: process.env.ASC_ISSUER_ID.trim(),
    privateKey: process.env.ASC_KEY_P8,
  })
  const mine = ownCertificates(await client.all('/v1/certificates?limit=200'), fingerprints)
  for (const c of mine) await client.delete(`/v1/certificates/${c.id}`)
  console.log(`This run's development certificates revoked: ${mine.length}`)
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  main().catch((e) => {
    console.log(`::error::${e.message}`)
    process.exit(1)
  })
}
