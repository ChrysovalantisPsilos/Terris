// Puts Terris's store material on App Store Connect, from the files in
// docs/store: the App Store screenshots (iPhone 6.9" and iPad 13"), the
// listing text (subtitle, promotional text, description, keywords) on the
// version being prepared, and the TestFlight text (the beta description and
// this build's "What to Test").
//
//   node scripts/asc/store.mjs            (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8)
//
// Screenshots replace what's in each set, in file-name order. Nothing is
// submitted for review: that stays a decision for the owner in App Store
// Connect. Nothing here logs a key or a token.
import { createHash } from 'node:crypto'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join, basename } from 'node:path'
import { createClient } from './api.mjs'

export const BUNDLE_ID = 'com.chrysovalantis.Terris'
const STORE = new URL('../../docs/store/', import.meta.url).pathname

// App Store Connect's display types for the sizes Terris ships
// (Apple, "Screenshot specifications").
export const DISPLAY_TYPES = [
  { type: 'APP_IPHONE_67', sizes: [[1290, 2796], [1320, 2868]] },
  { type: 'APP_IPAD_PRO_3GEN_129', sizes: [[2048, 2732], [2064, 2752]] },
]

// Width and height from a PNG's IHDR chunk.
export function pngSize(buffer) {
  if (buffer.readUInt32BE(12) !== 0x49484452) throw new Error('Not a PNG')
  return [buffer.readUInt32BE(16), buffer.readUInt32BE(20)]
}

export function displayTypeFor([w, h]) {
  const hit = DISPLAY_TYPES.find((d) => d.sizes.some(([a, b]) => a === w && b === h))
  if (!hit) throw new Error(`No App Store display type for ${w}×${h}`)
  return hit.type
}

// Screenshot files grouped by display type, each group in file-name order.
export function planScreenshots(files) {
  const groups = {}
  for (const f of [...files].sort((a, b) => basename(a.path).localeCompare(basename(b.path)))) {
    const type = displayTypeFor(f.size)
    ;(groups[type] ??= []).push(f)
  }
  return groups
}

function screenshotFiles() {
  const out = []
  for (const dir of ['iphone', 'ipad']) {
    const root = join(STORE, 'screenshots', dir)
    for (const name of readdirSync(root).filter((n) => n.endsWith('.png'))) {
      const path = join(root, name)
      const data = readFileSync(path)
      out.push({ path, data, size: pngSize(data), bytes: statSync(path).size })
    }
  }
  return out
}

async function upload(api, setId, file) {
  const created = await api.post('/v1/appScreenshots', {
    data: {
      type: 'appScreenshots',
      attributes: { fileName: basename(file.path), fileSize: file.bytes },
      relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: setId } } },
    },
  })
  const shot = created.data
  for (const op of shot.attributes.uploadOperations) {
    const headers = Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value]))
    const res = await fetch(op.url, {
      method: op.method, headers, body: file.data.subarray(op.offset, op.offset + op.length),
    })
    if (!res.ok) throw new Error(`Uploading ${basename(file.path)} failed: ${res.status}`)
  }
  const checksum = createHash('md5').update(file.data).digest('hex')
  await api.patch(`/v1/appScreenshots/${shot.id}`, {
    data: { type: 'appScreenshots', id: shot.id, attributes: { uploaded: true, sourceFileChecksum: checksum } },
  })
}

async function main() {
  const api = createClient({
    keyId: (process.env.ASC_KEY_ID ?? '').trim(),
    issuerId: (process.env.ASC_ISSUER_ID ?? '').trim(),
    privateKey: process.env.ASC_KEY_P8 ?? '',
  })
  const listing = JSON.parse(readFileSync(join(STORE, 'listing.json'), 'utf8'))

  const apps = await api.get(`/v1/apps?filter[bundleId]=${BUNDLE_ID}`)
  const app = apps.data?.[0]
  if (!app) throw new Error(`No app with bundle id ${BUNDLE_ID} in App Store Connect`)

  // The version being prepared (created with the app record).
  const editable = ['PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED']
  const versions = await api.all(`/v1/apps/${app.id}/appStoreVersions?filter[platform]=IOS`)
  const version = versions.find((v) => editable.includes(v.attributes.appStoreState))
  if (!version) throw new Error('No App Store version open for editing (Prepare for Submission)')
  console.log(`Version ${version.attributes.versionString} (${version.attributes.appStoreState})`)

  const locs = await api.all(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)
  const loc = locs.find((l) => l.attributes.locale.startsWith('en')) ?? locs[0]
  if (!loc) throw new Error('The version has no localization')

  await api.patch(`/v1/appStoreVersionLocalizations/${loc.id}`, {
    data: {
      type: 'appStoreVersionLocalizations', id: loc.id,
      attributes: {
        description: listing.description, keywords: listing.keywords,
        promotionalText: listing.promotionalText,
      },
    },
  })
  console.log(`Listing text set (${loc.attributes.locale})`)

  // Subtitle lives on the app info, not the version.
  const infos = await api.all(`/v1/apps/${app.id}/appInfos`)
  const info = infos.find((i) => i.attributes.appStoreState !== 'READY_FOR_SALE') ?? infos[0]
  if (info) {
    const infoLocs = await api.all(`/v1/appInfos/${info.id}/appInfoLocalizations`)
    const infoLoc = infoLocs.find((l) => l.attributes.locale === loc.attributes.locale) ?? infoLocs[0]
    if (infoLoc) {
      await api.patch(`/v1/appInfoLocalizations/${infoLoc.id}`, {
        data: { type: 'appInfoLocalizations', id: infoLoc.id, attributes: { subtitle: listing.subtitle } },
      })
      console.log('Subtitle set')
    }
  }

  // Screenshots: replace each set's contents.
  const plan = planScreenshots(screenshotFiles())
  const sets = await api.all(`/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets`)
  for (const [type, files] of Object.entries(plan)) {
    let set = sets.find((s) => s.attributes.screenshotDisplayType === type)
    if (!set) {
      set = (await api.post('/v1/appScreenshotSets', {
        data: {
          type: 'appScreenshotSets', attributes: { screenshotDisplayType: type },
          relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: loc.id } } },
        },
      })).data
    }
    for (const old of await api.all(`/v1/appScreenshotSets/${set.id}/appScreenshots`)) {
      await api.delete(`/v1/appScreenshots/${old.id}`)
    }
    for (const file of files) await upload(api, set.id, file)
    console.log(`${type}: ${files.length} screenshots`)
  }

  // TestFlight: the beta description, and "What to Test" on the newest build.
  const betaLocs = await api.all(`/v1/apps/${app.id}/betaAppLocalizations`)
  const betaLoc = betaLocs.find((l) => l.attributes.locale.startsWith('en')) ?? betaLocs[0]
  if (betaLoc) {
    await api.patch(`/v1/betaAppLocalizations/${betaLoc.id}`, {
      data: { type: 'betaAppLocalizations', id: betaLoc.id, attributes: { description: listing.testflight.description } },
    })
  } else {
    await api.post('/v1/betaAppLocalizations', {
      data: {
        type: 'betaAppLocalizations', attributes: { locale: 'en-US', description: listing.testflight.description },
        relationships: { app: { data: { type: 'apps', id: app.id } } },
      },
    })
  }
  console.log('TestFlight description set')

  const builds = await api.get(`/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=1`)
  const build = builds.data?.[0]
  if (build) {
    const bLocs = await api.all(`/v1/builds/${build.id}/betaBuildLocalizations`)
    const bLoc = bLocs.find((l) => l.attributes.locale.startsWith('en')) ?? bLocs[0]
    const attributes = { whatsNew: listing.testflight.whatToTest }
    if (bLoc) {
      await api.patch(`/v1/betaBuildLocalizations/${bLoc.id}`, { data: { type: 'betaBuildLocalizations', id: bLoc.id, attributes } })
    } else {
      await api.post('/v1/betaBuildLocalizations', {
        data: {
          type: 'betaBuildLocalizations', attributes: { ...attributes, locale: 'en-US' },
          relationships: { build: { data: { type: 'builds', id: build.id } } },
        },
      })
    }
    console.log(`What to Test set on build ${build.attributes.version}`)
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((e) => { console.error(e.message); process.exit(1) })
}
