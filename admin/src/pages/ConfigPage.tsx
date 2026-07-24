import { useCallback, useEffect, useState } from 'react';
import { Alert, App as AntApp, Button, Card, Form, Input, InputNumber, Popconfirm, Space, Spin, Switch, Tabs, Typography } from 'antd';
import { ExclamationCircleOutlined, HistoryOutlined, ReloadOutlined, SaveOutlined } from '@ant-design/icons';
import api from '../services/api';
import JsonModeSection from '../components/config/JsonModeSection';
import IapEditor, { type IapSection } from '../components/config/IapEditor';
import DailyEditor from '../components/config/DailyEditor';
import AchievementsEditor from '../components/config/AchievementsEditor';
import LocalizationEditor, { type LocalizationSection } from '../components/config/LocalizationEditor';
import ExperimentsEditor from '../components/config/ExperimentsEditor';
import SegmentsEditor from '../components/config/SegmentsEditor';
import ConfigHistoryDrawer from '../components/config/ConfigHistoryDrawer';

const { Title, Text } = Typography;

interface GameConfig {
  version: number;
  economy: Record<string, unknown>;
  ads: Record<string, unknown>;
  iap: IapSection;
  vip: Record<string, unknown>;
  daily: unknown[];
  achievements: unknown[];
  localization: LocalizationSection;
  experiments: unknown[];
  segments: unknown[];
  links?: Record<string, unknown>;
}

/** Данные секций с типизированными (не Form) редакторами */
interface EditorSections {
  iap: IapSection;
  daily: unknown[];
  achievements: unknown[];
  localization: LocalizationSection;
  experiments: unknown[];
  segments: unknown[];
}

type EditorSectionKey = keyof EditorSections;

const isPlainObject = (v: unknown): v is Record<string, unknown> =>
  !!v && typeof v === 'object' && !Array.isArray(v);

export default function ConfigPage() {
  const [config, setConfig] = useState<GameConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [economyForm] = Form.useForm();
  const [adsForm] = Form.useForm();
  const [vipForm] = Form.useForm();
  const [linksForm] = Form.useForm();
  const [sections, setSections] = useState<EditorSections>({
    iap: {}, daily: [], achievements: [], localization: {}, experiments: [], segments: [],
  });
  // Инкремент → remount типизированных редакторов (их локальное состояние переинициализируется)
  const [revision, setRevision] = useState(0);
  const [dirtyTabs, setDirtyTabs] = useState<Record<string, boolean>>({});
  const [sectionErrors, setSectionErrors] = useState<Record<string, string[]>>({});
  const [historyOpen, setHistoryOpen] = useState(false);
  const { message, modal } = AntApp.useApp();

  const loadConfigData = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get('/admin/config');
      setConfig(data);
      economyForm.setFieldsValue(data.economy);
      adsForm.setFieldsValue(data.ads);
      vipForm.setFieldsValue(data.vip);
      linksForm.setFieldsValue(data.links ?? {});
      setSections({
        iap: isPlainObject(data.iap) ? data.iap : {},
        daily: Array.isArray(data.daily) ? data.daily : [],
        achievements: Array.isArray(data.achievements) ? data.achievements : [],
        localization: isPlainObject(data.localization) ? (data.localization as LocalizationSection) : {},
        experiments: Array.isArray(data.experiments) ? data.experiments : [],
        segments: Array.isArray(data.segments) ? data.segments : [],
      });
      setRevision((r) => r + 1);
      setDirtyTabs({});
      setSectionErrors({});
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки конфигурации');
    } finally {
      setLoading(false);
    }
  }, [economyForm, adsForm, vipForm, linksForm, message]);

  const fetchConfig = (skipDirtyCheck = false) => {
    const dirtyList = Object.entries(dirtyTabs)
      .filter(([, v]) => v)
      .map(([k]) => k);
    if (!skipDirtyCheck && dirtyList.length > 0) {
      modal.confirm({
        title: 'Несохранённые изменения',
        icon: <ExclamationCircleOutlined />,
        content: `Несохранённые изменения в [${dirtyList.join(', ')}] будут потеряны. Продолжить?`,
        okText: 'Продолжить',
        cancelText: 'Отмена',
        onOk: () => loadConfigData(),
      });
      return;
    }
    loadConfigData();
  };

  useEffect(() => { loadConfigData(); }, [loadConfigData]);

  const saveSection = async (section: string, values: unknown) => {
    setSaving(true);
    setSectionErrors((prev) => ({ ...prev, [section]: [] }));
    try {
      const { data } = await api.put('/admin/config', { [section]: values });
      message.success(`Секция "${section}" сохранена (v${data?.version ?? '?'})`);
      const warnings: string[] = Array.isArray(data?.warnings) ? data.warnings : [];
      if (warnings.length > 0) {
        message.warning(`Предупреждения: ${warnings.join('; ')}`, 7);
      }
      // Обновляем ТОЛЬКО эту секцию в локальном состоянии —
      // не перезагружаем конфиг целиком, чтобы не стереть несохранённые правки
      // в других вкладках.
      setConfig((prev) => (prev ? { ...prev, [section]: values, version: data?.version ?? prev.version } : prev));
      setDirtyTabs((prev) => ({ ...prev, [section]: false }));
    } catch (err: unknown) {
      const e = err as {
        response?: { status?: number; data?: { error?: string; details?: { section: string; message: string }[] } };
      };
      const details = e.response?.data?.details;
      if (e.response?.status === 400 && Array.isArray(details) && details.length > 0) {
        const grouped: Record<string, string[]> = {};
        for (const d of details) (grouped[d.section] ??= []).push(d.message);
        setSectionErrors((prev) => ({ ...prev, ...grouped }));
        message.error('Конфиг не прошёл валидацию — ошибки показаны в секции');
      } else {
        message.error(e.response?.data?.error || 'Ошибка сохранения');
      }
    } finally {
      setSaving(false);
    }
  };

  const markDirty = (section: string) => {
    setDirtyTabs((prev) => (prev[section] ? prev : { ...prev, [section]: true }));
  };

  /** Правка из типизированного редактора */
  const updateSection = <K extends EditorSectionKey>(section: K, next: EditorSections[K]) => {
    setSections((prev) => ({ ...prev, [section]: next }));
    markDirty(section);
  };

  /** Применение значения из JSON-режима: лёгкая проверка формы + remount редактора */
  const applyExternal = (section: EditorSectionKey, next: unknown): boolean => {
    if ((section === 'iap' || section === 'localization') && !isPlainObject(next)) {
      message.error(`Секция "${section}" должна быть объектом`);
      return false;
    }
    if ((section === 'daily' || section === 'achievements' || section === 'experiments' || section === 'segments') && !Array.isArray(next)) {
      message.error(`Секция "${section}" должна быть массивом`);
      return false;
    }
    setSections((prev) => ({ ...prev, [section]: next as EditorSections[typeof section] }));
    setRevision((r) => r + 1);
    markDirty(section);
    return true;
  };

  if (loading) return <Spin size="large" style={{ display: 'block', margin: '100px auto' }} />;

  // Клиент ждёт целые числа: дробь/пустое значение ломают Remote Config.
  // required + type:'integer' блокируют submit (onFinish не сработает при невалидных данных).
  const intRules = [
    { required: true, message: 'Обязательное поле' },
    { type: 'integer' as const, message: 'Только целое число' },
  ];

  const sectionErrorAlert = (section: string) =>
    sectionErrors[section]?.length ? (
      <Alert
        type="error"
        showIcon
        style={{ marginBottom: 16 }}
        message="Сервер отклонил секцию (Invalid config)"
        description={<ul style={{ margin: 0, paddingLeft: 18 }}>{sectionErrors[section].map((e, i) => <li key={i}>{e}</li>)}</ul>}
      />
    ) : null;

  /** Обёртка секции с типизированным редактором + JSON-фолбэком */
  const editorTab = (section: EditorSectionKey, editor: React.ReactNode) => (
    <JsonModeSection
      sectionKey={section}
      value={sections[section]}
      saving={saving}
      errors={sectionErrors[section]}
      onApply={(next) => applyExternal(section, next)}
      onSave={(v) => saveSection(section, v)}
      onDirty={() => markDirty(section)}
    >
      {editor}
    </JsonModeSection>
  );

  const tabs = [
    {
      key: 'economy',
      label: '💰 Экономика',
      children: (
        <>
          {sectionErrorAlert('economy')}
          <Form
            form={economyForm}
            layout="vertical"
            onFinish={(v) => saveSection('economy', { ...config?.economy, ...v })}
            onValuesChange={() => markDirty('economy')}
          >
            <Form.Item name="maxTickets" label="Макс. билетов (энергия)" rules={intRules}>
              <InputNumber min={1} max={99} precision={0} />
            </Form.Item>
            <Form.Item name="ticketRefillMinutes" label="Рефилл билета (мин)" rules={intRules}>
              <InputNumber min={1} max={1440} precision={0} />
            </Form.Item>
            <Form.Item name="startDiamonds" label="Стартовые алмазы" rules={intRules}>
              <InputNumber min={0} max={9999} precision={0} />
            </Form.Item>
            <Form.Item name="startTickets" label="Стартовые билеты" rules={intRules}>
              <InputNumber min={0} max={99} precision={0} />
            </Form.Item>
            <Form.Item name="diamondCostPerTicket" label="Цена билета (алмазы)" rules={intRules}>
              <InputNumber min={1} max={999} precision={0} />
            </Form.Item>
            <Form.Item
              name="legacySyncCap"
              label="Кап миграции легаси-баланса (алмазы)"
              tooltip="Максимум, который одна учётка может занести через legacy_sync (однократная миграция старых локальных балансов)"
              rules={intRules}
            >
              <InputNumber min={0} max={100000} precision={0} />
            </Form.Item>
            <Form.Item>
              <Popconfirm
                title="Изменения экономики применятся ко всем игрокам. Сохранить?"
                okText="Сохранить"
                cancelText="Отмена"
                onConfirm={() => economyForm.submit()}
              >
                <Button type="primary" icon={<SaveOutlined />} loading={saving}>
                  Сохранить
                </Button>
              </Popconfirm>
            </Form.Item>
          </Form>
        </>
      ),
    },
    {
      key: 'ads',
      label: '📺 Реклама',
      children: (
        <>
          {sectionErrorAlert('ads')}
          <Form
            form={adsForm}
            layout="vertical"
            onFinish={(v) => saveSection('ads', { ...config?.ads, ...v })}
            onValuesChange={() => markDirty('ads')}
          >
            <Form.Item name="maxAdsPerDay" label="Макс. просмотров в день" rules={intRules}>
              <InputNumber min={0} max={99} precision={0} />
            </Form.Item>
            <Form.Item name="diamondReward" label="Алмазы за просмотр" rules={intRules}>
              <InputNumber min={0} max={999} precision={0} />
            </Form.Item>
            <Form.Item name="ticketReward" label="Билеты за просмотр" rules={intRules}>
              <InputNumber min={0} max={99} precision={0} />
            </Form.Item>
            <Form.Item
              name="rewardAmount"
              label="Награда ad_reward (алмазы, серверный леджер)"
              tooltip="Сумма, которую сервер начисляет за подтверждённый просмотр rewarded-рекламы"
              rules={intRules}
            >
              <InputNumber min={0} max={999} precision={0} />
            </Form.Item>
            <Form.Item
              name="rewardedAdUnitIdAndroid"
              label="Rewarded Ad Unit ID (Android)"
              tooltip="Пусто — реклама отключена в release-сборке (в debug клиент использует тестовые ID Google)"
            >
              <Input placeholder="ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN" style={{ maxWidth: 420 }} />
            </Form.Item>
            <Form.Item
              name="rewardedAdUnitIdIos"
              label="Rewarded Ad Unit ID (iOS)"
              tooltip="Пусто — реклама отключена в release-сборке (в debug клиент использует тестовые ID Google)"
            >
              <Input placeholder="ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN" style={{ maxWidth: 420 }} />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={saving}>
                Сохранить
              </Button>
            </Form.Item>
          </Form>
        </>
      ),
    },
    {
      key: 'vip',
      label: '👑 VIP',
      children: (
        <>
          {sectionErrorAlert('vip')}
          <Form
            form={vipForm}
            layout="vertical"
            onFinish={(v) => saveSection('vip', { ...config?.vip, ...v })}
            onValuesChange={() => markDirty('vip')}
          >
            <Form.Item name="dailyDiamonds" label="Ежедневные алмазы VIP" rules={intRules}>
              <InputNumber min={0} max={999} precision={0} />
            </Form.Item>
            <Form.Item name="unlimitedTickets" label="Безлимитные билеты" valuePropName="checked">
              <Switch />
            </Form.Item>
            <Form.Item name="earlyAccess" label="Ранний доступ" valuePropName="checked">
              <Switch />
            </Form.Item>
            <Form.Item name="noAds" label="Без рекламы" valuePropName="checked">
              <Switch />
            </Form.Item>
            <Form.Item name="exclusiveFrame" label="Эксклюзивная рамка" valuePropName="checked">
              <Switch />
            </Form.Item>
            <Form.Item>
              <Popconfirm
                title="Изменения VIP применятся ко всем игрокам. Сохранить?"
                okText="Сохранить"
                cancelText="Отмена"
                onConfirm={() => vipForm.submit()}
              >
                <Button type="primary" icon={<SaveOutlined />} loading={saving}>
                  Сохранить
                </Button>
              </Popconfirm>
            </Form.Item>
          </Form>
        </>
      ),
    },
    {
      key: 'iap',
      label: '🛒 IAP',
      children: editorTab('iap', (
        <IapEditor key={`iap-${revision}`} value={sections.iap} onChange={(n) => updateSection('iap', n)} />
      )),
    },
    {
      key: 'daily',
      label: '🎁 Daily',
      children: editorTab('daily', (
        <DailyEditor key={`daily-${revision}`} value={sections.daily} onChange={(n) => updateSection('daily', n)} />
      )),
    },
    {
      key: 'achievements',
      label: '🏆 Достижения',
      children: editorTab('achievements', (
        <AchievementsEditor key={`ach-${revision}`} value={sections.achievements} onChange={(n) => updateSection('achievements', n)} />
      )),
    },
    {
      key: 'localization',
      label: '🌍 Локализация',
      children: editorTab('localization', (
        <LocalizationEditor key={`loc-${revision}`} value={sections.localization} onChange={(n) => updateSection('localization', n)} />
      )),
    },
    {
      key: 'experiments',
      label: '🧪 Эксперименты',
      children: editorTab('experiments', (
        <ExperimentsEditor key={`exp-${revision}`} value={sections.experiments} onChange={(n) => updateSection('experiments', n)} />
      )),
    },
    {
      key: 'links',
      label: '🔗 Ссылки',
      children: (
        <>
          {sectionErrorAlert('links')}
          <Form
            form={linksForm}
            layout="vertical"
            onFinish={(v) => saveSection('links', { ...config?.links, ...v })}
            onValuesChange={() => markDirty('links')}
          >
            <Form.Item
              name="privacyPolicyUrl"
              label="Privacy Policy URL"
              tooltip="Показывается в экране согласий клиента; пусто — ссылка скрыта"
              rules={[{ type: 'url', message: 'Некорректный URL' }]}
            >
              <Input placeholder="https://amoria.app/privacy" allowClear />
            </Form.Item>
            <Form.Item
              name="termsUrl"
              label="Terms of Service URL"
              rules={[{ type: 'url', message: 'Некорректный URL' }]}
            >
              <Input placeholder="https://amoria.app/terms" allowClear />
            </Form.Item>
            <Form.Item>
              <Button type="primary" icon={<SaveOutlined />} loading={saving} htmlType="submit">
                Сохранить
              </Button>
            </Form.Item>
          </Form>
        </>
      ),
    },
    {
      key: 'segments',
      label: '🎯 Сегменты',
      children: editorTab('segments', (
        <SegmentsEditor key={`seg-${revision}`} value={sections.segments} onChange={(n) => updateSection('segments', n)} />
      )),
    },
  ];

  return (
    <div>
      <Space style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between' }}>
        <div>
          <Title level={4} style={{ margin: 0 }}>⚙️ Конфигурация игры</Title>
          <Text type="secondary">Версия: {config?.version ?? 0}</Text>
        </div>
        <Space>
          <Button icon={<HistoryOutlined />} onClick={() => setHistoryOpen(true)}>История</Button>
          <Button icon={<ReloadOutlined />} onClick={() => fetchConfig()}>Обновить</Button>
        </Space>
      </Space>
      <Card>
        <Tabs items={tabs} />
      </Card>
      <ConfigHistoryDrawer
        open={historyOpen}
        onClose={() => setHistoryOpen(false)}
        onRolledBack={() => loadConfigData()}
      />
    </div>
  );
}
