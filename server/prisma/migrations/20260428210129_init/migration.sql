-- AlterTable
ALTER TABLE "users" ADD COLUMN     "vip_expires_at" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "iap_transactions" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "platform" TEXT NOT NULL,
    "product_id" TEXT NOT NULL,
    "transaction_id" TEXT NOT NULL,
    "receipt_hash" TEXT NOT NULL,
    "verified" BOOLEAN NOT NULL DEFAULT false,
    "reward_claimed" BOOLEAN NOT NULL DEFAULT false,
    "raw_response_log" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "iap_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "iap_transactions_user_id_idx" ON "iap_transactions"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "iap_transactions_platform_transaction_id_key" ON "iap_transactions"("platform", "transaction_id");

-- AddForeignKey
ALTER TABLE "iap_transactions" ADD CONSTRAINT "iap_transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
