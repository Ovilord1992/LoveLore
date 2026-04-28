import { defineConfig } from 'vitest/config';

/**
 * Запускаем тесты только из src/, исключая собранный dist/.
 *
 * tsc собирает .test.ts → dist/__tests__/*.js, а vitest по умолчанию
 * матчит и .ts, и .js — это давало "Vitest cannot be imported in CommonJS"
 * ошибку при попытке загрузить уже скомпилированный CJS-тест.
 */
export default defineConfig({
  test: {
    include: ['src/**/*.{test,spec}.ts'],
    exclude: ['node_modules', 'dist'],
  },
});
