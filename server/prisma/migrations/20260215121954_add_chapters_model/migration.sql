-- AlterTable
ALTER TABLE "novels" ADD COLUMN     "released_chapters" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "chapters" (
    "id" TEXT NOT NULL,
    "novel_id" TEXT NOT NULL,
    "number" INTEGER NOT NULL,
    "title" TEXT NOT NULL DEFAULT '',
    "is_released" BOOLEAN NOT NULL DEFAULT true,
    "released_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "chapters_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "chapters_novel_id_number_key" ON "chapters"("novel_id", "number");

-- AddForeignKey
ALTER TABLE "chapters" ADD CONSTRAINT "chapters_novel_id_fkey" FOREIGN KEY ("novel_id") REFERENCES "novels"("id") ON DELETE CASCADE ON UPDATE CASCADE;
