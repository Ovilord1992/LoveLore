-- AlterTable
ALTER TABLE "iap_transactions" ADD COLUMN     "revoked_at" TIMESTAMP(3),
ADD COLUMN     "usd_cents" INTEGER;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "last_active_at" TIMESTAMP(3),
ADD COLUMN     "token_version" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "currency_ledger" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "currency" TEXT NOT NULL,
    "delta" INTEGER NOT NULL,
    "reason" TEXT NOT NULL,
    "ref_id" TEXT,
    "idempotency_key" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "currency_ledger_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_tokens" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "token_hash" TEXT NOT NULL,
    "family_id" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "revoked_at" TIMESTAMP(3),
    "replaced_by_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "analytics_events" (
    "id" TEXT NOT NULL,
    "user_id" TEXT,
    "device_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "params" JSONB,
    "ts" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "analytics_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "config_history" (
    "id" TEXT NOT NULL,
    "version" INTEGER NOT NULL,
    "data" JSONB NOT NULL,
    "changed_by" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "config_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "store_notifications" (
    "id" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "message_id" TEXT,
    "type" TEXT,
    "transaction_id" TEXT,
    "payload" JSONB NOT NULL,
    "processed" BOOLEAN NOT NULL DEFAULT false,
    "error" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "store_notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "currency_ledger_user_id_created_at_idx" ON "currency_ledger"("user_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "currency_ledger_user_id_idempotency_key_key" ON "currency_ledger"("user_id", "idempotency_key");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_tokens_token_hash_key" ON "refresh_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "refresh_tokens_user_id_idx" ON "refresh_tokens"("user_id");

-- CreateIndex
CREATE INDEX "refresh_tokens_family_id_idx" ON "refresh_tokens"("family_id");

-- CreateIndex
CREATE INDEX "analytics_events_name_ts_idx" ON "analytics_events"("name", "ts");

-- CreateIndex
CREATE INDEX "analytics_events_user_id_ts_idx" ON "analytics_events"("user_id", "ts");

-- CreateIndex
CREATE UNIQUE INDEX "config_history_version_key" ON "config_history"("version");

-- CreateIndex
CREATE UNIQUE INDEX "store_notifications_platform_message_id_key" ON "store_notifications"("platform", "message_id");

-- CreateIndex
CREATE INDEX "chapters_novel_id_is_released_idx" ON "chapters"("novel_id", "is_released");

-- CreateIndex
CREATE INDEX "novels_is_published_updated_at_idx" ON "novels"("is_published", "updated_at");

-- CreateIndex
CREATE INDEX "reviews_novel_id_status_idx" ON "reviews"("novel_id", "status");

-- AddForeignKey
ALTER TABLE "currency_ledger" ADD CONSTRAINT "currency_ledger_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
