// ----------- daniel -------------
// Fork-only migration: re-adds the asset.deviceId column that upstream dropped in
// 1776263790468-DropDeviceIdAndDeviceAssetId.ts. It powers the storage template
// `{{device}}` variable (per-device upload folders). Nullable — pre-existing
// assets keep NULL, so only new uploads carry a device identifier.
// ---------------------------------
import { Kysely, sql } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  await sql`ALTER TABLE "asset" ADD "deviceId" character varying;`.execute(db);
}

export async function down(db: Kysely<any>): Promise<void> {
  await sql`ALTER TABLE "asset" DROP COLUMN "deviceId";`.execute(db);
}
