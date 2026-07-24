import { useCallback, useEffect, useState } from 'react';
import {
  App as AntApp, Button, DatePicker, Form, Input, InputNumber, Modal, Space, Switch, Table, Tag, Tooltip, Typography,
} from 'antd';
import { EditOutlined, PlusOutlined, ReloadOutlined } from '@ant-design/icons';
import type { ColumnsType } from 'antd/es/table';
import dayjs, { type Dayjs } from 'dayjs';
import api from '../services/api';

const { Title, Text } = Typography;

interface PromoRow {
  id: string;
  code: string;
  diamonds: number;
  tickets: number;
  vipDays: number;
  maxRedemptions: number;
  redemptionsCount: number;
  expiresAt: string | null;
  isActive: boolean;
  createdAt: string;
}

interface CreateFormValues {
  code: string;
  diamonds?: number;
  tickets?: number;
  vipDays?: number;
  maxRedemptions?: number;
  expiresAt?: Dayjs | null;
  isActive?: boolean;
}

interface EditFormValues {
  maxRedemptions?: number;
  expiresAt?: Dayjs | null;
}

// Формат кода как на сервере (нормализация в UPPER — до проверки)
const CODE_RE = /^[A-Z0-9_-]{3,64}$/;

const fmtDateTime = (iso: string) => dayjs(iso).format('DD.MM.YYYY HH:mm');

export default function PromoPage() {
  const [codes, setCodes] = useState<PromoRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [createOpen, setCreateOpen] = useState(false);
  const [creating, setCreating] = useState(false);
  const [editRow, setEditRow] = useState<PromoRow | null>(null);
  const [editSaving, setEditSaving] = useState(false);
  const [togglingId, setTogglingId] = useState<string | null>(null);
  const [createForm] = Form.useForm<CreateFormValues>();
  const [editForm] = Form.useForm<EditFormValues>();
  const { message } = AntApp.useApp();

  const fetchCodes = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get('/admin/promo');
      setCodes(data.codes);
    } catch (err: unknown) {
      const e = err as { response?: { data?: { error?: string } } };
      message.error(e.response?.data?.error || 'Ошибка загрузки промокодов');
    } finally {
      setLoading(false);
    }
  }, [message]);

  useEffect(() => { fetchCodes(); }, [fetchCodes]);

  /** PATCH одного поля/набора полей с локальным обновлением строки из ответа */
  const patchPromo = async (id: string, body: Record<string, unknown>): Promise<boolean> => {
    try {
      const { data } = await api.patch(`/admin/promo/${id}`, body);
      setCodes((prev) => prev.map((c) => (c.id === id ? { ...c, ...data.code } : c)));
      return true;
    } catch (err: unknown) {
      const e = err as { response?: { status?: number; data?: { error?: string } } };
      if (e.response?.status === 404) {
        message.error('Промокод не найден — возможно, удалён. Список обновлён.');
        fetchCodes();
      } else {
        message.error(e.response?.data?.error || 'Ошибка обновления промокода');
      }
      return false;
    }
  };

  const toggleActive = async (row: PromoRow) => {
    setTogglingId(row.id);
    const ok = await patchPromo(row.id, { isActive: !row.isActive });
    if (ok) message.success(!row.isActive ? `Промокод ${row.code} активирован` : `Промокод ${row.code} деактивирован`);
    setTogglingId(null);
  };

  const handleCreate = async (v: CreateFormValues) => {
    setCreating(true);
    const normalized = v.code.trim().toUpperCase();
    try {
      await api.post('/admin/promo', {
        code: normalized,
        diamonds: v.diamonds ?? 0,
        tickets: v.tickets ?? 0,
        vipDays: v.vipDays ?? 0,
        maxRedemptions: v.maxRedemptions ?? 0,
        expiresAt: v.expiresAt ? v.expiresAt.toISOString() : null,
        isActive: v.isActive ?? true,
      });
      message.success(`Промокод ${normalized} создан`);
      setCreateOpen(false);
      createForm.resetFields();
      fetchCodes();
    } catch (err: unknown) {
      const e = err as { response?: { status?: number; data?: { error?: string } } };
      if (e.response?.status === 409) {
        message.error(`Промокод «${normalized}» уже существует — коды уникальны (без учёта регистра). Выберите другой код.`);
      } else {
        message.error(e.response?.data?.error || 'Ошибка создания промокода');
      }
    } finally {
      setCreating(false);
    }
  };

  const openEdit = (row: PromoRow) => {
    setEditRow(row);
    editForm.setFieldsValue({
      maxRedemptions: row.maxRedemptions,
      expiresAt: row.expiresAt ? dayjs(row.expiresAt) : null,
    });
  };

  const handleEdit = async (v: EditFormValues) => {
    if (!editRow) return;
    setEditSaving(true);
    const ok = await patchPromo(editRow.id, {
      maxRedemptions: v.maxRedemptions ?? 0,
      expiresAt: v.expiresAt ? v.expiresAt.toISOString() : null,
    });
    if (ok) {
      message.success(`Промокод ${editRow.code} обновлён`);
      setEditRow(null);
    }
    setEditSaving(false);
  };

  const columns: ColumnsType<PromoRow> = [
    {
      title: 'Код',
      dataIndex: 'code',
      key: 'code',
      width: 200,
      render: (code: string) => <Text code copyable>{code}</Text>,
    },
    {
      title: 'Награда',
      key: 'reward',
      render: (_: unknown, r: PromoRow) => {
        const parts: React.ReactNode[] = [];
        if (r.diamonds > 0) parts.push(<Tag key="d" color="blue">💎 {r.diamonds}</Tag>);
        if (r.tickets > 0) parts.push(<Tag key="t" color="purple">🎟 {r.tickets}</Tag>);
        if (r.vipDays > 0) parts.push(<Tag key="v" color="gold">VIP {r.vipDays} дн.</Tag>);
        return parts.length > 0 ? <>{parts}</> : <Text type="secondary">—</Text>;
      },
    },
    {
      title: 'Погашений',
      key: 'redemptions',
      width: 130,
      render: (_: unknown, r: PromoRow) => {
        const exhausted = r.maxRedemptions > 0 && r.redemptionsCount >= r.maxRedemptions;
        return (
          <Space size={4}>
            <span>{r.redemptionsCount} из {r.maxRedemptions === 0 ? '∞' : r.maxRedemptions}</span>
            {exhausted && <Tag color="red">исчерпан</Tag>}
          </Space>
        );
      },
    },
    {
      title: 'Срок действия',
      key: 'expiresAt',
      width: 190,
      render: (_: unknown, r: PromoRow) => {
        if (!r.expiresAt) return <Text type="secondary">бессрочно</Text>;
        const expired = dayjs(r.expiresAt).isBefore(dayjs());
        return (
          <Space size={4}>
            <span>{fmtDateTime(r.expiresAt)}</span>
            {expired && <Tag color="red">истёк</Tag>}
          </Space>
        );
      },
    },
    {
      title: 'Активен',
      key: 'isActive',
      width: 90,
      render: (_: unknown, r: PromoRow) => (
        <Switch
          checked={r.isActive}
          checkedChildren="Да"
          unCheckedChildren="Нет"
          loading={togglingId === r.id}
          onChange={() => toggleActive(r)}
        />
      ),
    },
    {
      title: 'Создан',
      dataIndex: 'createdAt',
      key: 'createdAt',
      width: 150,
      render: (d: string) => fmtDateTime(d),
    },
    {
      title: '',
      key: 'actions',
      width: 50,
      render: (_: unknown, r: PromoRow) => (
        <Tooltip title="Лимит погашений и срок действия">
          <Button icon={<EditOutlined />} size="small" onClick={() => openEdit(r)} />
        </Tooltip>
      ),
    },
  ];

  return (
    <div>
      <Space style={{ marginBottom: 16, width: '100%', justifyContent: 'space-between' }}>
        <Title level={3} style={{ margin: 0 }}>Промокоды</Title>
        <Space>
          <Button icon={<ReloadOutlined />} onClick={fetchCodes}>Обновить</Button>
          <Button icon={<PlusOutlined />} type="primary" onClick={() => setCreateOpen(true)}>
            Создать промокод
          </Button>
        </Space>
      </Space>
      <Table
        columns={columns}
        dataSource={codes}
        rowKey="id"
        loading={loading}
        pagination={{ pageSize: 20, hideOnSinglePage: true }}
        locale={{ emptyText: 'Промокодов нет — создайте первый' }}
      />

      {/* Модалка создания */}
      <Modal
        title="Новый промокод"
        open={createOpen}
        onCancel={() => setCreateOpen(false)}
        onOk={() => createForm.submit()}
        okText="Создать"
        cancelText="Отмена"
        confirmLoading={creating}
        destroyOnHidden
      >
        <Form form={createForm} layout="vertical" onFinish={handleCreate} initialValues={{ isActive: true }}>
          <Form.Item
            name="code"
            label="Код"
            normalize={(v: string) => (v || '').toUpperCase()}
            rules={[
              { required: true, message: 'Введите код' },
              { pattern: CODE_RE, message: '3–64 символа: латиница A–Z, цифры, «-» и «_»' },
            ]}
          >
            <Input placeholder="WELCOME2026" maxLength={64} style={{ fontFamily: 'monospace' }} />
          </Form.Item>
          <Space wrap>
            <Form.Item name="diamonds" label="💎 Алмазы">
              <InputNumber min={0} precision={0} placeholder="0" style={{ width: 110 }} />
            </Form.Item>
            <Form.Item name="tickets" label="🎟 Билеты">
              <InputNumber min={0} precision={0} placeholder="0" style={{ width: 110 }} />
            </Form.Item>
            <Form.Item name="vipDays" label="VIP, дней">
              <InputNumber min={0} precision={0} placeholder="0" style={{ width: 110 }} />
            </Form.Item>
          </Space>
          <Form.Item
            name="maxRedemptions"
            label="Лимит погашений"
            tooltip="Сколько всего пользователей могут погасить код. 0 — безлимит."
          >
            <InputNumber min={0} precision={0} placeholder="0 (безлимит)" style={{ width: 160 }} />
          </Form.Item>
          <Form.Item
            name="expiresAt"
            label="Срок действия (до)"
            tooltip="Пусто — код бессрочный"
          >
            <DatePicker
              showTime
              format="DD.MM.YYYY HH:mm"
              placeholder="Бессрочно"
              disabledDate={(d) => d.isBefore(dayjs().startOf('day'))}
              style={{ width: 220 }}
            />
          </Form.Item>
          <Form.Item name="isActive" label="Активен сразу" valuePropName="checked">
            <Switch checkedChildren="Да" unCheckedChildren="Нет" />
          </Form.Item>
        </Form>
      </Modal>

      {/* Модалка правки лимита и срока */}
      <Modal
        title={`Промокод ${editRow?.code || ''}`}
        open={!!editRow}
        onCancel={() => setEditRow(null)}
        onOk={() => editForm.submit()}
        okText="Сохранить"
        cancelText="Отмена"
        confirmLoading={editSaving}
        destroyOnHidden
      >
        <Form form={editForm} layout="vertical" onFinish={handleEdit}>
          <Form.Item
            name="maxRedemptions"
            label="Лимит погашений"
            tooltip="0 — безлимит"
            extra={editRow ? `Уже погашено: ${editRow.redemptionsCount}` : undefined}
          >
            <InputNumber min={0} precision={0} style={{ width: 160 }} />
          </Form.Item>
          <Form.Item name="expiresAt" label="Срок действия (до)" tooltip="Очистите поле, чтобы сделать код бессрочным">
            <DatePicker showTime format="DD.MM.YYYY HH:mm" placeholder="Бессрочно" style={{ width: 220 }} />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
}
