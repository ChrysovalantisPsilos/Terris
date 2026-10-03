// node --test scripts/cloudkit/schema.test.mjs
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { modelFields, missingFields, addMissingFields, schemaRecordTypes, currentModel } from './schema.mjs'

const MODEL = `<model>
  <entity name="Country" representedClassName="Country" syncable="YES">
    <attribute name="isoCode" optional="YES" attributeType="String"/>
    <attribute name="status" optional="YES" attributeType="Integer 16" defaultValueString="0"/>
    <attribute name="coverPhoto" optional="YES" attributeType="String"/>
    <relationship name="photos" optional="YES" toMany="YES" destinationEntity="TravelPhoto"/>
  </entity>
  <entity name="TravelPhoto" representedClassName="TravelPhoto" syncable="YES">
    <attribute name="takenDate" optional="YES" attributeType="Date"/>
    <relationship name="country" optional="YES" maxCount="1" destinationEntity="Country"/>
  </entity>
</model>`

const SCHEMA = `DEFINE SCHEMA

    RECORD TYPE CD_Country (
        "___createTime" TIMESTAMP,
        "___recordID"   REFERENCE QUERYABLE,
        CD_isoCode      STRING QUERYABLE SEARCHABLE SORTABLE,
        CD_isoCode_ckAsset ASSET,
        CD_status       INT64 QUERYABLE SORTABLE,
        GRANT WRITE TO "_creator",
        GRANT READ TO "_world"
    );

    RECORD TYPE CD_TravelPhoto (
        "___createTime" TIMESTAMP,
        CD_takenDate    TIMESTAMP QUERYABLE SORTABLE,
        CD_country      STRING QUERYABLE SEARCHABLE SORTABLE,
        GRANT WRITE TO "_creator"
    );
`

test('reads the fields a model needs, including to-one relationships', () => {
  assert.deepEqual(modelFields(MODEL), {
    CD_Country: { CD_isoCode: 'STRING', CD_status: 'INT64', CD_coverPhoto: 'STRING' },
    CD_TravelPhoto: { CD_takenDate: 'TIMESTAMP', CD_country: 'STRING' },
  })
})

test('finds what a schema lacks', () => {
  assert.deepEqual(missingFields(SCHEMA, modelFields(MODEL)),
    [{ recordType: 'CD_Country', field: 'CD_coverPhoto', type: 'STRING' }])
})

test('adds a missing field like its siblings, before the grants', () => {
  const { text, added } = addMissingFields(SCHEMA, modelFields(MODEL))
  assert.equal(added.length, 1)
  assert.match(text, /CD_coverPhoto STRING QUERYABLE SEARCHABLE SORTABLE,\n\s+CD_coverPhoto_ckAsset ASSET,\n\s+GRANT WRITE TO "_creator",/)
  // Once added, nothing is missing and a second pass changes nothing.
  assert.deepEqual(missingFields(text, modelFields(MODEL)), [])
  assert.equal(addMissingFields(text, modelFields(MODEL)).text, text)
  assert.ok(schemaRecordTypes(text).CD_Country.fields.CD_coverPhoto)
})

test('leaves brand-new record types to initializeCloudKitSchema', () => {
  const model = MODEL.replace('</model>', '<entity name="Trip"><attribute name="name" attributeType="String"/></entity></model>')
  const { newRecordTypes } = addMissingFields(SCHEMA, modelFields(model))
  assert.deepEqual(newRecordTypes, ['CD_Trip'])
})

test("Terris's own model reads cleanly", () => {
  const model = currentModel(new URL('../../Terris/Terris/Terris.xcdatamodeld/', import.meta.url).pathname)
  const fields = modelFields(model)
  assert.equal(fields.CD_Country.CD_coverPhoto, 'STRING')
  assert.equal(fields.CD_TravelPhoto.CD_assetIdentifier, 'STRING')
  assert.equal(fields.CD_TravelPhoto.CD_country, 'STRING')
})
