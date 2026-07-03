import { useCallback, useEffect, useState } from 'react';
import { Card, Tabs, Form, InputNumber, Switch, Button, message, Spin, Input, Space, Typography, Modal, Popconfirm } from 'antd';
import { SaveOutlined, ReloadOutlined, ExclamationCircleOutlined } from '@ant-design/icons';
import api from '../services/api';

const { Title, Text } = Typography;
const { TextArea } = Input;

interface GameConfig {
  version: number;
  economy: Record<string, unknown>;
  ads: Record<string, unknown>;
  iap: Record<string, unknown>;
  vip: Record<string, unknown>;
  daily: unknown[];
  achievements: unknown[];
  localization: Record<string, unknown>;
}

export default function ConfigPage() {
  const [config, setConfig] = useState<GameConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [economyForm] = Form.useForm();
  const [adsForm] = Form.useForm();
  const [vipForm] = Form.useForm();
  const [jsonSections, setJsonSections] = useState<Record<string, string>>({});
  const [dirtyTabs, setDirtyTabs] = useState<Record<string, boolean>>({});

  const loadConfigData = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get('/admin/config');
      setConfig(data);
      economyForm.setFieldsValue(data.economy);
      adsForm.setFieldsValue(data.ads);
      vipForm.setFieldsValue(data.vip);
      setJsonSections({
        iap: JSON.stringify(data.iap, null, 2),
        daily: JSON.stringify(data.daily, null, 2),
        achievements: JSON.stringify(data.achievements, null, 2),
        localization: JSON.stringify(data.localization, null, 2),
      });
      setDirtyTabs({});
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки конфигурации');
    } finally {
      setLoading(false);
    }
  }, [economyForm, adsForm, vipForm]);

  const fetchConfig = (skipDirtyCheck = false) => {
    const dirtyList = Object.entries(dirtyTabs)
      .filter(([, v]) => v)
      .map(([k]) => k);
    if (!skipDirtyCheck && dirtyList.length > 0) {
      Modal.confirm({
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
    try {
      const { data } = await api.put('/admin/config', { [section]: values });
      message.success(`Секция "${section}" сохранена`);
      // Обновляем ТОЛЬКО эту секцию в локальном состоянии —
      // не перезагружаем конфиг целиком, чтобы не стереть несохранённые правки
      // в других вкладках.
      setConfig((prev) => (prev ? { ...prev, [section]: values, version: data?.version ?? prev.version } : prev));
      setDirtyTabs((prev) => ({ ...prev, [section]: false }));
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка сохранения');
    } finally {
      setSaving(false);
    }
  };

  const saveJsonSection = async (section: string) => {
    let parsed: unknown;
    try {
      parsed = JSON.parse(jsonSections[section] ?? '');
    } catch (err) {
      message.error(`Невалидный JSON в секции "${section}": ${(err as Error).message}`);
      return;
    }
    await saveSection(section, parsed);
  };

  const markDirty = (section: string) => {
    setDirtyTabs((prev) => (prev[section] ? prev : { ...prev, [section]: true }));
  };

  if (loading) return <Spin size="large" style={{ display: 'block', margin: '100px auto' }} />;

  // Клиент ждёт целые числа: дробь/пустое значение ломают Remote Config.
  // required + type:'integer' блокируют submit (onFinish не сработает при невалидных данных).
  const intRules = [
    { required: true, message: 'Обязательное поле' },
    { type: 'integer' as const, message: 'Только целое число' },
  ];

  const tabs = [
    {
      key: 'economy',
      label: '💰 Экономика',
      children: (
        <Form
          form={economyForm}
          layout="vertical"
          onFinish={(v) => saveSection('economy', v)}
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
      ),
    },
    {
      key: 'ads',
      label: '📺 Реклама',
      children: (
        <Form
          form={adsForm}
          layout="vertical"
          onFinish={(v) => saveSection('ads', v)}
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
          <Form.Item>
            <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={saving}>
              Сохранить
            </Button>
          </Form.Item>
        </Form>
      ),
    },
    {
      key: 'vip',
      label: '👑 VIP',
      children: (
        <Form
          form={vipForm}
          layout="vertical"
          onFinish={(v) => saveSection('vip', v)}
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
      ),
    },
    ...['iap', 'daily', 'achievements', 'localization'].map((section) => ({
      key: section,
      label: section === 'iap' ? '🛒 IAP' : section === 'daily' ? '🎁 Daily' : section === 'achievements' ? '🏆 Достижения' : '🌍 Локализация',
      children: (
        <Space direction="vertical" style={{ width: '100%' }}>
          <TextArea
            rows={16}
            value={jsonSections[section] || '{}'}
            onChange={(e) => {
              setJsonSections({ ...jsonSections, [section]: e.target.value });
              markDirty(section);
            }}
            style={{ fontFamily: 'monospace', fontSize: 13 }}
          />
          <Button type="primary" icon={<SaveOutlined />} loading={saving} onClick={() => saveJsonSection(section)}>
            Сохранить
          </Button>
        </Space>
      ),
    })),
  ];

  return (
    <div>
      <Space style={{ marginBottom: 16, display: 'flex', justifyContent: 'space-between' }}>
        <div>
          <Title level={4} style={{ margin: 0 }}>⚙️ Конфигурация игры</Title>
          <Text type="secondary">Версия: {config?.version ?? 0}</Text>
        </div>
        <Button icon={<ReloadOutlined />} onClick={() => fetchConfig()}>Обновить</Button>
      </Space>
      <Card>
        <Tabs items={tabs} />
      </Card>
    </div>
  );
}
