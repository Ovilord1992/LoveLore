import { useEffect, useState, useCallback, useRef } from 'react';
import { Table, Input, Button, Space, Switch, Typography, App as AntApp, Popconfirm, Upload, Modal, Tag, Tooltip, DatePicker } from 'antd';
import { SearchOutlined, UploadOutlined, DeleteOutlined, GlobalOutlined, ProfileOutlined } from '@ant-design/icons';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import type { UploadProps } from 'antd';
import dayjs, { type Dayjs } from 'dayjs';
import api from '../services/api';

const { Title } = Typography;

interface NovelRow {
  id: string;
  title: string;
  author: string;
  version: number;
  chaptersCount: number;
  downloads: number;
  isPublished: boolean;
  fileSize: number;
  updatedAt: string;
}

interface ChapterRow {
  id: string;
  number: number;
  title: string;
  isReleased: boolean;
  releasedAt: string | null;
}

export default function NovelsPage() {
  const [novels, setNovels] = useState<NovelRow[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [translationModal, setTranslationModal] = useState<{ novelId: string; title: string } | null>(null);
  const [languages, setLanguages] = useState<{ sourceLanguage: string; translations: string[] }>({ sourceLanguage: 'ru', translations: [] });
  const [translationJson, setTranslationJson] = useState('');
  const [uploadLang, setUploadLang] = useState('en');
  const [chaptersModal, setChaptersModal] = useState<{ novelId: string; title: string } | null>(null);
  const [chapters, setChapters] = useState<ChapterRow[]>([]);
  const [chaptersLoading, setChaptersLoading] = useState(false);
  const [chaptersSaving, setChaptersSaving] = useState<number | null>(null);
  const [chapterUploading, setChapterUploading] = useState(false);
  const reqId = useRef(0);
  const { message } = AntApp.useApp();

  // Debounce поля поиска: не шлём запрос на каждый символ
  useEffect(() => {
    const t = setTimeout(() => { setDebouncedSearch(search); setPage(1); }, 350);
    return () => clearTimeout(t);
  }, [search]);

  const fetchNovels = useCallback(async () => {
    const myId = ++reqId.current; // защита от гонок: применяем только последний ответ
    setLoading(true);
    try {
      const { data } = await api.get('/admin/novels', { params: { page, limit: 20, search: debouncedSearch } });
      if (myId !== reqId.current) return;
      setNovels(data.novels);
      setTotal(data.total);
    } catch (err: unknown) {
      if (myId !== reqId.current) return;
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки новелл');
    } finally {
      if (myId === reqId.current) setLoading(false);
    }
  }, [page, debouncedSearch, message]);

  useEffect(() => { fetchNovels(); }, [fetchNovels]);

  const togglePublish = async (id: string, current: boolean) => {
    try {
      await api.patch(`/admin/novels/${id}`, { isPublished: !current });
      message.success(!current ? 'Новелла опубликована' : 'Новелла скрыта');
      fetchNovels();
    } catch {
      message.error('Ошибка обновления');
    }
  };

  const deleteNovel = async (id: string) => {
    try {
      await api.delete(`/novels/${id}`);
      message.success('Новелла удалена');
      fetchNovels();
    } catch {
      message.error('Ошибка удаления');
    }
  };

  const openTranslations = async (novelId: string, title: string) => {
    setTranslationModal({ novelId, title });
    setTranslationJson('');
    setLanguages({ sourceLanguage: 'ru', translations: [] });
    try {
      const { data } = await api.get(`/novels/${novelId}/languages`);
      setLanguages({ sourceLanguage: data.sourceLanguage, translations: data.translations });
    } catch {
      setLanguages({ sourceLanguage: 'ru', translations: [] });
    }
  };

  const downloadTranslation = async (novelId: string, lang: string) => {
    try {
      const { data } = await api.get(`/novels/${novelId}/translations/${lang}`);
      setTranslationJson(JSON.stringify(data, null, 2));
      message.success(`Перевод (${lang}) загружен`);
    } catch {
      message.error('Перевод не найден');
    }
  };

  const uploadTranslation = async (novelId: string, lang: string) => {
    let parsed: unknown;
    try {
      parsed = JSON.parse(translationJson);
    } catch (err) {
      message.error(`Невалидный JSON: ${(err as Error).message}`);
      return;
    }
    try {
      await api.post(`/novels/${novelId}/translations/${lang}`, parsed);
      message.success(`Перевод (${lang}) загружен на сервер`);
      openTranslations(novelId, translationModal?.title || '');
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки перевода');
    }
  };

  // ─── Управление главами (релиз/расписание/загрузка) ──────────────────────
  const loadChapters = async (novelId: string) => {
    setChaptersLoading(true);
    try {
      const { data } = await api.get(`/admin/novels/${novelId}/chapters`);
      setChapters(data.chapters);
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки глав');
    } finally {
      setChaptersLoading(false);
    }
  };

  const openChapters = (novelId: string, title: string) => {
    setChaptersModal({ novelId, title });
    setChapters([]);
    loadChapters(novelId);
  };

  const patchChapter = async (number: number, body: Record<string, unknown>, okMsg: string) => {
    if (!chaptersModal) return;
    setChaptersSaving(number);
    try {
      const { data } = await api.patch(`/admin/novels/${chaptersModal.novelId}/chapters/${number}`, body);
      setChapters((prev) => prev.map((c) => (c.number === number ? { ...c, ...data.chapter } : c)));
      message.success(okMsg);
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка обновления главы');
    } finally {
      setChaptersSaving(null);
    }
  };

  const toggleChapterRelease = (chapter: ChapterRow) => {
    const releasing = !chapter.isReleased;
    patchChapter(chapter.number, { isReleased: releasing }, releasing ? 'Глава выпущена' : 'Глава скрыта');
    if (!releasing && chapter.releasedAt && !dayjs(chapter.releasedAt).isAfter(dayjs())) {
      // Серверный планировщик релизит главы с isReleased=false и прошедшей releasedAt —
      // скрытие ранее выпущенной главы он отменит на ближайшем тике (~60 с).
      message.warning(
        'У главы дата выпуска в прошлом: серверный планировщик снова выпустит её в течение ~1 минуты. ' +
        'Чтобы скрыть надолго, задайте будущую дату в расписании.',
        8,
      );
    }
  };

  const updateChapterDate = (chapter: ChapterRow, d: Dayjs | null) => {
    if (!d) return;
    if (!chapter.isReleased) {
      // Планирование: для невыпущенной главы дата обязана быть в будущем,
      // иначе серверный планировщик зарелизит её в ближайшие 60 секунд.
      if (!d.isAfter(dayjs())) {
        message.error('Дата планирования должна быть в будущем — прошедшая дата немедленно выпустит главу');
        return;
      }
      patchChapter(
        chapter.number,
        { isReleased: false, releasedAt: d.toISOString() },
        `Глава запланирована на ${d.format('DD.MM.YYYY HH:mm')}`,
      );
      return;
    }
    patchChapter(chapter.number, { releasedAt: d.toISOString() }, 'Дата выпуска обновлена');
  };

  // Загрузка одной главы JSON-файлом → POST /admin/novels/:id/chapters
  const uploadChapterJson = async (file: File) => {
    if (!chaptersModal) return;
    let parsed: unknown;
    try {
      parsed = JSON.parse(await file.text());
    } catch (err) {
      message.error(`Невалидный JSON: ${(err as Error).message}`);
      return;
    }
    let chapter = (parsed ?? {}) as Record<string, unknown>;
    // Допускаем файл-обёртку { "chapter": {...} } — как в теле запроса
    if (chapter.chapter && typeof chapter.chapter === 'object' && !Array.isArray(chapter.chapter)) {
      chapter = chapter.chapter as Record<string, unknown>;
    }
    const problems: string[] = [];
    if (typeof chapter.id !== 'string' || !chapter.id) problems.push('id');
    if (typeof chapter.title !== 'string' || !chapter.title) problems.push('title');
    if (!Number.isInteger(chapter.number) || (chapter.number as number) < 1) problems.push('number (целое ≥ 1)');
    if (typeof chapter.firstSceneId !== 'string' || !chapter.firstSceneId) problems.push('firstSceneId');
    if (!Array.isArray(chapter.scenes) || chapter.scenes.length === 0) problems.push('scenes (непустой массив)');
    if (problems.length > 0) {
      message.error(`Файл не похож на главу — некорректные поля: ${problems.join(', ')}`);
      return;
    }

    setChapterUploading(true);
    try {
      const { data } = await api.post(`/admin/novels/${chaptersModal.novelId}/chapters`, { chapter });
      const created = data.message === 'Chapter created';
      message.success(
        `${created ? 'Глава добавлена' : 'Глава обновлена'} (№${chapter.number}). ` +
        `Глав: ${data.novel.chaptersCount}, выпущено: ${data.novel.releasedChapters}, версия: v${data.novel.version}`,
      );
      loadChapters(chaptersModal.novelId); // обновить список глав
      fetchNovels(); // обновить счётчики в основной таблице
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки главы');
    } finally {
      setChapterUploading(false);
    }
  };

  const uploadProps: UploadProps = {
    name: 'file',
    action: `${api.defaults.baseURL}/novels/upload`,
    headers: { Authorization: `Bearer ${localStorage.getItem('admin_token') || ''}` },
    accept: '.zip',
    showUploadList: false,
    onChange(info) {
      if (info.file.status === 'uploading') {
        setUploading(true);
      } else if (info.file.status === 'done') {
        setUploading(false);
        message.success(`${info.file.response?.novel?.title || 'Новелла'} загружена`);
        fetchNovels();
      } else if (info.file.status === 'error') {
        setUploading(false);
        // Сервер отдаёт осмысленный текст («Invalid novel pack…»/413)
        const serverMsg = info.file.response?.error || info.file.error?.message;
        message.error(serverMsg ? `Ошибка загрузки: ${serverMsg}` : 'Ошибка загрузки новеллы');
      }
    },
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const columns: ColumnsType<NovelRow> = [
    { title: 'Название', dataIndex: 'title', key: 'title' },
    { title: 'Автор', dataIndex: 'author', key: 'author' },
    { title: 'v', dataIndex: 'version', key: 'version', width: 50 },
    { title: 'Глав', dataIndex: 'chaptersCount', key: 'chapters', width: 60 },
    { title: 'Загрузок', dataIndex: 'downloads', key: 'downloads', width: 90 },
    {
      title: 'Размер', dataIndex: 'fileSize', key: 'fileSize', width: 90,
      render: (s: number) => formatSize(s),
    },
    {
      title: 'Статус', key: 'published', width: 100,
      render: (_: unknown, r: NovelRow) => (
        <Switch
          checked={r.isPublished}
          checkedChildren="Pub"
          unCheckedChildren="Off"
          onChange={() => togglePublish(r.id, r.isPublished)}
        />
      ),
    },
    {
      title: 'Обновлена', dataIndex: 'updatedAt', key: 'updatedAt',
      render: (d: string) => new Date(d).toLocaleDateString('ru'),
    },
    {
      title: '', key: 'actions', width: 140,
      render: (_: unknown, r: NovelRow) => (
        <Space>
          <Tooltip title="Главы">
            <Button icon={<ProfileOutlined />} size="small" onClick={() => openChapters(r.id, r.title)} />
          </Tooltip>
          <Tooltip title="Переводы">
            <Button icon={<GlobalOutlined />} size="small" onClick={() => openTranslations(r.id, r.title)} />
          </Tooltip>
          <Popconfirm title="Удалить новеллу?" onConfirm={() => deleteNovel(r.id)}>
            <Button icon={<DeleteOutlined />} size="small" danger />
          </Popconfirm>
        </Space>
      ),
    },
  ];

  const chapterColumns: ColumnsType<ChapterRow> = [
    { title: '№', dataIndex: 'number', key: 'number', width: 50 },
    { title: 'Заголовок', dataIndex: 'title', key: 'title' },
    {
      title: 'Статус', key: 'status', width: 210,
      render: (_: unknown, r: ChapterRow) => {
        if (r.isReleased) return <Tag color="green">Выпущена</Tag>;
        if (r.releasedAt && dayjs(r.releasedAt).isAfter(dayjs())) {
          return <Tag color="orange">Запланирована на {dayjs(r.releasedAt).format('DD.MM.YYYY HH:mm')}</Tag>;
        }
        return <Tag>Не выпущена</Tag>;
      },
    },
    {
      title: 'Выпущена', key: 'isReleased', width: 100,
      render: (_: unknown, r: ChapterRow) => (
        <Switch
          checked={r.isReleased}
          checkedChildren="Да"
          unCheckedChildren="Нет"
          loading={chaptersSaving === r.number}
          onChange={() => toggleChapterRelease(r)}
        />
      ),
    },
    {
      title: 'Дата выпуска / расписание', key: 'releasedAt', width: 215,
      render: (_: unknown, r: ChapterRow) => (
        <Tooltip title={r.isReleased ? 'Дата фактического выпуска' : 'Будущая дата — сервер выпустит главу автоматически (интервал ~60 с)'}>
          <DatePicker
            value={r.releasedAt ? dayjs(r.releasedAt) : null}
            onChange={(d) => updateChapterDate(r, d)}
            showTime
            format="DD.MM.YYYY HH:mm"
            allowClear={false}
            size="small"
            disabled={chaptersSaving === r.number}
            disabledDate={r.isReleased ? undefined : (d) => d.isBefore(dayjs().startOf('day'))}
            placeholder={r.isReleased ? '—' : 'Запланировать…'}
          />
        </Tooltip>
      ),
    },
  ];

  const handleTableChange = (pagination: TablePaginationConfig) => {
    setPage(pagination.current || 1);
  };

  return (
    <div>
      <Space style={{ marginBottom: 16, width: '100%', justifyContent: 'space-between' }}>
        <Title level={3} style={{ margin: 0 }}>Новеллы</Title>
        <Upload {...uploadProps}>
          <Button icon={<UploadOutlined />} type="primary" loading={uploading}>
            {uploading ? 'Загрузка…' : 'Загрузить ZIP'}
          </Button>
        </Upload>
      </Space>
      <Input
        prefix={<SearchOutlined />}
        placeholder="Поиск по названию или автору..."
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        style={{ marginBottom: 16, maxWidth: 400 }}
        allowClear
      />
      <Table
        columns={columns}
        dataSource={novels}
        rowKey="id"
        loading={loading}
        pagination={{ current: page, total, pageSize: 20 }}
        onChange={handleTableChange}
      />

      {/* Модалка переводов */}
      <Modal
        title={`🌍 Переводы — ${translationModal?.title || ''}`}
        open={!!translationModal}
        onCancel={() => { setTranslationModal(null); setTranslationJson(''); }}
        footer={null}
        width={700}
      >
        {translationModal && (
          <div>
            <p><strong>Язык оригинала:</strong> {languages.sourceLanguage}</p>
            <p><strong>Доступные переводы:</strong>{' '}
              {languages.translations.length > 0
                ? languages.translations.map((l) => (
                    <Tag key={l} color="blue" style={{ cursor: 'pointer' }} onClick={() => downloadTranslation(translationModal.novelId, l)}>
                      {l}
                    </Tag>
                  ))
                : <span style={{ color: '#999' }}>нет переводов</span>
              }
            </p>
            <hr style={{ border: '1px solid #222', margin: '16px 0' }} />
            <p><strong>Загрузить перевод:</strong></p>
            <Space style={{ marginBottom: 8 }}>
              <select value={uploadLang} onChange={(e) => setUploadLang(e.target.value)} style={{ padding: '4px 8px' }}>
                {['en','ru','es','fr','de','it','pt','tr','ko','ja','zh'].map((l) => (
                  <option key={l} value={l}>{l}</option>
                ))}
              </select>
              <Button type="primary" onClick={() => uploadTranslation(translationModal.novelId, uploadLang)} disabled={!translationJson.trim()}>
                Загрузить
              </Button>
            </Space>
            <textarea
              value={translationJson}
              onChange={(e) => setTranslationJson(e.target.value)}
              placeholder='{"meta":{"language":"en","sourceLanguage":"ru","novelId":"...","version":1},"texts":{"Оригинал":"Translation"}}'
              rows={15}
              style={{ width: '100%', fontFamily: 'monospace', fontSize: 12, background: '#111', color: '#ccc', border: '1px solid #333', padding: 8, borderRadius: 4 }}
            />
          </div>
        )}
      </Modal>

      {/* Модалка управления главами */}
      <Modal
        title={`📖 Главы — ${chaptersModal?.title || ''}`}
        open={!!chaptersModal}
        onCancel={() => { setChaptersModal(null); setChapters([]); }}
        footer={null}
        width={860}
      >
        {chaptersModal && (
          <>
            <div style={{ marginBottom: 12, textAlign: 'right' }}>
              <Upload
                accept=".json,application/json"
                showUploadList={false}
                beforeUpload={(file) => {
                  void uploadChapterJson(file);
                  return false; // не отправляем через встроенный аплоадер — шлём JSON сами
                }}
              >
                <Button icon={<UploadOutlined />} loading={chapterUploading}>
                  Загрузить главу (JSON-файл)
                </Button>
              </Upload>
            </div>
            <Table
              columns={chapterColumns}
              dataSource={chapters}
              rowKey="id"
              loading={chaptersLoading}
              pagination={false}
              size="small"
              locale={{ emptyText: 'Нет глав' }}
            />
          </>
        )}
      </Modal>
    </div>
  );
}
