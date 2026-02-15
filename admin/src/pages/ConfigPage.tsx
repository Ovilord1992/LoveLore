import { useEffect, useState } from 'react';
import { Card, Tabs, Form, InputNumber, Switch, Button, message, Spin, Input, Space, Typography } from 'antd';
import { SaveOutlined, ReloadOutlined } from '@ant-design/icons';
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

  const fetchConfig = async () => {
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
    } catch {
      message.error('Ошибка загрузки конфигурации');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchConfig(); }, []);

  const saveSection = async (section: string, values: unknown) => {
    setSaving(true);
    try {
      await api.put('/admin/config', { [section]: values });
      message.success(`Секция "${section}" сохранена`);
      await fetchConfig();
    } catch {
      message.error('Ошибка сохранения');
    } finally {
      setSaving(false);
    }
  };

  const saveJsonSection = async (section: string) => {
    try {
      const parsed = JSON.parse(jsonSections[section]);
      await saveSection(section, parsed);
    } catch {
      message.error('Невалидный JSON');
    }
  };

  if (loading) return <Spin size="large" style={{ display: 'block', margin: '100px auto' }} />;

  const tabs = [
    {
      key: 'economy',
      label: '💰 Экономика',
      children: (
        <Form form={economyForm} layout="vertical" onFinish={(v) => saveSection('economy', v)}>
          <Form.Item name="maxTickets" label="Макс. билетов (энергия)">
            <InputNumber min={1} max={99} />
          </Form.Item>
          <Form.Item name="ticketRefillMinutes" label="Рефилл билета (мин)">
            <InputNumber min={1} max={1440} />
          </Form.Item>
          <Form.Item name="startDiamonds" label="Стартовые алмазы">
            <InputNumber min={0} max={9999} />
          </Form.Item>
          <Form.Item name="startTickets" label="Стартовые билеты">
            <InputNumber min={0} max={99} />
          </Form.Item>
          <Form.Item name="diamondCostPerTicket" label="Цена билета (алмазы)">
            <InputNumber min={1} max={999} />
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
      key: 'ads',
      label: '📺 Реклама',
      children: (
        <Form form={adsForm} layout="vertical" onFinish={(v) => saveSection('ads', v)}>
          <Form.Item name="maxAdsPerDay" label="Макс. просмотров в день">
            <InputNumber min={0} max={99} />
          </Form.Item>
          <Form.Item name="diamondReward" label="Алмазы за просмотр">
            <InputNumber min={0} max={999} />
          </Form.Item>
          <Form.Item name="ticketReward" label="Билеты за просмотр">
            <InputNumber min={0} max={99} />
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
        <Form form={vipForm} layout="vertical" onFinish={(v) => saveSection('vip', v)}>
          <Form.Item name="dailyDiamonds" label="Ежедневные алмазы VIP">
            <InputNumber min={0} max={999} />
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
            <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={saving}>
              Сохранить
            </Button>
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
            onChange={(e) => setJsonSections({ ...jsonSections, [section]: e.target.value })}
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
        <Button icon={<ReloadOutlined />} onClick={fetchConfig}>Обновить</Button>
      </Space>
      <Card>
        <Tabs items={tabs} />
      </Card>
    </div>
  );
}
