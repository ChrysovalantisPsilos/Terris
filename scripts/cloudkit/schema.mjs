// Keeps Terris's iCloud (CloudKit) schema in step with its Core Data model,
// so a model change never needs Xcode on the owner's Mac.
//
// NSPersistentCloudKitContainer mirrors each entity to a record type
// "CD_<Entity>" and each attribute (and to-one relationship) to a field
// "CD_<name>". CloudKit only accepts new fields in the Development
// environment; Production gets them when the owner taps "Deploy Schema
// Changes" in the CloudKit Console (Apple offers no API for that step).
//
//   node schema.mjs plan  <model dir> <development.ckdb> <out.ckdb>
//        adds the fields the model needs to the Development schema file
//        (written to out.ckdb) and prints what it added
//   node schema.mjs check <model dir> <production.ckdb>
//        prints the fields Production still lacks; exits 1 if any
//
// The .ckdb files come from `xcrun cktool export-schema` (see
// .github/workflows/cloudkit-schema.yml and ios-testflight.yml).
import { readFileSync, writeFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'

// Core Data attribute types → CloudKit field types, as Core Data mirrors them.
export const FIELD_TYPES = {
  String: 'STRING', UUID: 'STRING', URI: 'STRING',
  Date: 'TIMESTAMP',
  'Integer 16': 'INT64', 'Integer 32': 'INT64', 'Integer 64': 'INT64', Boolean: 'INT64',
  Double: 'DOUBLE', Float: 'DOUBLE', Decimal: 'DOUBLE',
  Binary: 'BYTES', Transformable: 'BYTES',
}

// The record types and fields a model needs: { CD_Country: { CD_isoCode: 'STRING', … } }.
export function modelFields(modelXml) {
  const out = {}
  for (const entity of modelXml.matchAll(/<entity\s+([^>]*)>([\s\S]*?)<\/entity>/g)) {
    const name = /name="([^"]+)"/.exec(entity[1])?.[1]
    if (!name) continue
    const fields = {}
    for (const a of entity[2].matchAll(/<attribute\s+([^>]*?)\/?>/g)) {
      const attr = /name="([^"]+)"/.exec(a[1])?.[1]
      const type = FIELD_TYPES[/attributeType="([^"]+)"/.exec(a[1])?.[1]]
      if (attr && type) fields[`CD_${attr}`] = type
    }
    // A to-one relationship is stored as the related record's name.
    for (const r of entity[2].matchAll(/<relationship\s+([^>]*?)\/?>/g)) {
      const rel = /name="([^"]+)"/.exec(r[1])?.[1]
      if (rel && /maxCount="1"/.test(r[1])) fields[`CD_${rel}`] = 'STRING'
    }
    out[`CD_${name}`] = fields
  }
  return out
}

// The current model version's contents, from <name>.xcdatamodeld.
export function currentModel(modelDir) {
  const current = readFileSync(join(modelDir, '.xccurrentversion'), 'utf8')
  const version = /<string>([^<]+\.xcdatamodel)<\/string>/.exec(current)?.[1]
    ?? readdirSync(modelDir).filter((n) => n.endsWith('.xcdatamodel')).sort().at(-1)
  return readFileSync(join(modelDir, version, 'contents'), 'utf8')
}

// The record type blocks of a .ckdb schema: { CD_Country: { start, end, fields: { CD_x: { type, line } } } }.
export function schemaRecordTypes(ckdb) {
  const lines = ckdb.split('\n')
  const out = {}
  let current = null
  lines.forEach((line, i) => {
    const open = /^\s*RECORD TYPE\s+"?([A-Za-z0-9_]+)"?\s*\(/.exec(line)
    if (open) { current = { name: open[1], start: i, end: i, fields: {}, firstGrant: null }; return }
    if (!current) return
    if (/^\s*\);/.test(line)) { current.end = i; out[current.name] = current; current = null; return }
    if (/^\s*GRANT\b/.test(line)) { current.firstGrant ??= i; return }
    const field = /^\s*"?([A-Za-z0-9_]+)"?\s+([A-Z0-9_<>()]+)(.*?),?\s*$/.exec(line)
    if (field) current.fields[field[1]] = { type: field[2], line: i, flags: field[3].replace(/,\s*$/, '').trim() }
  })
  return out
}

// Fields the model needs that a schema lacks: [{ recordType, field, type }].
export function missingFields(ckdb, needed) {
  const types = schemaRecordTypes(ckdb)
  const out = []
  for (const [recordType, fields] of Object.entries(needed)) {
    for (const [field, type] of Object.entries(fields)) {
      if (!types[recordType]?.fields[field]) out.push({ recordType, field, type })
    }
  }
  return out
}

// The schema with the missing fields added, each copying the flags (and
// _ckAsset sibling) of an existing field of the same type, as Core Data
// would have created it. Record types that don't exist yet are left alone:
// a brand-new entity still needs one run of initializeCloudKitSchema.
export function addMissingFields(ckdb, needed) {
  const types = schemaRecordTypes(ckdb)
  const missing = missingFields(ckdb, needed).filter((m) => types[m.recordType])
  const newRecordTypes = missingFields(ckdb, needed).filter((m) => !types[m.recordType]).map((m) => m.recordType)
  // A template per CloudKit type: an existing CD_ field and its flags.
  const template = {}
  for (const rt of Object.values(types)) {
    for (const [name, f] of Object.entries(rt.fields)) {
      if (!name.startsWith('CD_') || name.endsWith('_ckAsset')) continue
      template[f.type] ??= { flags: f.flags, asset: rt.fields[`${name}_ckAsset`] }
    }
  }
  const lines = ckdb.split('\n')
  const inserts = {} // line index → lines to insert before it
  for (const m of missing) {
    const rt = types[m.recordType]
    const at = rt.firstGrant ?? rt.end
    const t = template[m.type]
    const indent = '        '
    const add = [`${indent}${m.field} ${m.type}${t?.flags ? ` ${t.flags}` : ''},`]
    if (t?.asset) add.push(`${indent}${m.field}_ckAsset ${t.asset.type}${t.asset.flags ? ` ${t.asset.flags}` : ''},`)
    ;(inserts[at] ??= []).push(...add)
  }
  const out = []
  lines.forEach((line, i) => { if (inserts[i]) out.push(...inserts[i]); out.push(line) })
  return { text: out.join('\n'), added: missing, newRecordTypes: [...new Set(newRecordTypes)] }
}

function main([command, modelDir, schemaFile, outFile]) {
  const needed = modelFields(currentModel(modelDir))
  const ckdb = readFileSync(schemaFile, 'utf8')
  if (command === 'plan') {
    const { text, added, newRecordTypes } = addMissingFields(ckdb, needed)
    writeFileSync(outFile, text)
    for (const a of added) console.log(`add ${a.recordType}.${a.field} (${a.type})`)
    for (const r of newRecordTypes) console.log(`::warning::${r} is a new record type: run the app once with -initCloudKitSchema to create it`)
    if (!added.length) console.log('Development already has every field the model needs.')
    return 0
  }
  if (command === 'check') {
    const missing = missingFields(ckdb, needed)
    for (const m of missing) console.log(`missing in Production: ${m.recordType}.${m.field} (${m.type})`)
    if (missing.length) {
      console.log('::error::iCloud Production lacks fields this build uses. In the CloudKit Console (works on a phone): iCloud.com.chrysovalantis.Terris → Development → Deploy Schema Changes. Then re-run this job.')
      return 1
    }
    console.log('Production has every field the model needs.')
    return 0
  }
  console.error('usage: schema.mjs plan|check <model dir> <schema.ckdb> [out.ckdb]')
  return 2
}

if (import.meta.url === `file://${process.argv[1]}`) process.exit(main(process.argv.slice(2)))
