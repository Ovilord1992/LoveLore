-- CreateTable
CREATE TABLE "game_config" (
    "id" TEXT NOT NULL DEFAULT 'singleton',
    "version" INTEGER NOT NULL DEFAULT 1,
    "economy" JSONB NOT NULL DEFAULT '{}',
    "ads" JSONB NOT NULL DEFAULT '{}',
    "iap" JSONB NOT NULL DEFAULT '{}',
    "vip" JSONB NOT NULL DEFAULT '{}',
    "daily" JSONB NOT NULL DEFAULT '{}',
    "achievements" JSONB NOT NULL DEFAULT '[]',
    "localization" JSONB NOT NULL DEFAULT '{}',
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "game_config_pkey" PRIMARY KEY ("id")
);
