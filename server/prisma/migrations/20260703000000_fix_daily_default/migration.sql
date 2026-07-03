-- Приводим дефолт game_config.daily к массиву ([]), т.к. код ожидает массив,
-- а не объект ({}). Затрагивает только будущие вставки; существующие строки
-- при необходимости мигрируются вручную (UPDATE game_config SET daily = '[]'
-- WHERE daily = '{}').

-- AlterTable
ALTER TABLE "game_config" ALTER COLUMN "daily" SET DEFAULT '[]';
