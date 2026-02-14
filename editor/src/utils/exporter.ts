import JSZip from 'jszip';
import { saveAs } from 'file-saver';
import type { NovelProject } from '../types/novel';

/** Экспортировать проект как ZIP-пакет, готовый для Amoria */
export async function exportAsZip(project: NovelProject): Promise<void> {
  const zip = new JSZip();
  const novelDir = zip.folder(project.meta.id)!;

  // meta.json
  novelDir.file('meta.json', JSON.stringify(project.meta, null, 2));

  // characters.json
  novelDir.file(
    'characters.json',
    JSON.stringify({ characters: project.characters }, null, 2)
  );

  // variables.json
  novelDir.file('variables.json', JSON.stringify(project.variables, null, 2));

  // chapters/
  const chaptersDir = novelDir.folder('chapters')!;
  for (const chapter of project.chapters) {
    chaptersDir.file(
      `${chapter.id}.json`,
      JSON.stringify(chapter, null, 2)
    );
  }

  // assets/ (пустые папки-плейсхолдеры)
  const assetsDir = novelDir.folder('assets')!;
  assetsDir.folder('backgrounds');
  assetsDir.folder('characters');
  assetsDir.folder('audio');

  // Генерируем ZIP
  const blob = await zip.generateAsync({ type: 'blob' });
  saveAs(blob, `${project.meta.id}.zip`);
}

/** Импортировать проект из JSON-файла */
export function importProject(file: File): Promise<NovelProject> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const project = JSON.parse(e.target?.result as string) as NovelProject;
        resolve(project);
      } catch {
        reject(new Error('Невалидный JSON'));
      }
    };
    reader.onerror = () => reject(new Error('Ошибка чтения файла'));
    reader.readAsText(file);
  });
}

/** Экспортировать проект как единый JSON */
export function exportAsJson(project: NovelProject): void {
  const json = JSON.stringify(project, null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  saveAs(blob, `${project.meta.id}.json`);
}
