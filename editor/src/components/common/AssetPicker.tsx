import { useEffect, useMemo, useRef, useState } from 'react';
import { useEditorStore } from '../../store/editorStore';
import { Image, Music, Pause, Play, Upload } from 'lucide-react';
import './common.css';

function sanitizeFileName(name: string): string {
  return name.replace(/\s+/g, '_').toLowerCase();
}

interface AssetPickerProps {
  /** Полный zipPath значения ("music/theme.mp3", "cg/kiss.png") или ''. */
  value: string;
  onChange: (zipPath: string) => void;
  /** Каталоги, из которых предлагать ассеты: ['music/'] / ['cg/'] / ['sounds/','voice/']. */
  dirs: string[];
  /** Куда загружать новый файл (дефолт — dirs[0]). */
  uploadDir?: string;
  kind: 'audio' | 'image';
  placeholder?: string;
  allowEmpty?: boolean;
  emptyLabel?: string;
  className?: string;
}

/** Пикер ассета из загруженных (по каталогу) + загрузка нового + превью:
 *  для аудио — кнопка прослушивания, для картинок — миниатюра. */
export function AssetPicker({ value, onChange, dirs, uploadDir, kind, placeholder, allowEmpty = true, emptyLabel = '— нет —', className }: AssetPickerProps) {
  const assets = useEditorStore((s) => s.assets);
  const assetUrls = useEditorStore((s) => s.assetUrls);
  const addAsset = useEditorStore((s) => s.addAsset);
  const [playing, setPlaying] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  // Не оставляем превью играть после размонтирования пикера
  useEffect(() => () => audioRef.current?.pause(), []);

  const options = useMemo(() => {
    const list: string[] = [];
    assets.forEach((_, path) => {
      if (dirs.some((d) => path.startsWith(d))) list.push(path);
    });
    list.sort();
    if (value && !list.includes(value)) list.unshift(value);
    return list;
  }, [assets, dirs, value]);

  const url = value ? assetUrls.get(value) : undefined;

  const handleUpload = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = kind === 'audio' ? 'audio/*,.mp3,.ogg,.wav,.m4a' : 'image/*';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (!file) return;
      const dir = uploadDir || dirs[0];
      const zipPath = `${dir}${sanitizeFileName(file.name)}`;
      addAsset(zipPath, file);
      onChange(zipPath);
    };
    input.click();
  };

  const togglePlay = () => {
    if (!url) return;
    if (playing) {
      audioRef.current?.pause();
      audioRef.current = null;
      setPlaying(false);
      return;
    }
    const audio = new Audio(url);
    audioRef.current = audio;
    audio.onended = () => { setPlaying(false); audioRef.current = null; };
    void audio.play();
    setPlaying(true);
  };

  return (
    <div className={`asset-picker ${className || ''}`}>
      {kind === 'image' && (
        <span className="asset-picker-thumb" title={value || undefined}>
          {url ? <img src={url} alt="" /> : <Image size={12} />}
        </span>
      )}
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        title={value || placeholder}
      >
        <option value="" disabled={!allowEmpty}>{value ? emptyLabel : (placeholder || emptyLabel)}</option>
        {options.map((path) => (
          <option key={path} value={path}>{path}</option>
        ))}
      </select>
      {kind === 'audio' && (
        <button
          type="button"
          className="asset-picker-btn"
          onClick={togglePlay}
          disabled={!url}
          title={url ? (playing ? 'Остановить' : 'Прослушать') : 'Файл не загружен'}
        >
          {playing ? <Pause size={12} /> : (url ? <Play size={12} /> : <Music size={12} />)}
        </button>
      )}
      <button type="button" className="asset-picker-btn" onClick={handleUpload} title="Загрузить файл">
        <Upload size={12} />
      </button>
    </div>
  );
}
