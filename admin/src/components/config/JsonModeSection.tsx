import { useState } from 'react';
import { Alert, Button, Input, Space, Switch, Typography, App as AntApp } from 'antd';
import { SaveOutlined } from '@ant-design/icons';

const { TextArea } = Input;
const { Text } = Typography;

interface Props {
  /** Название секции для сообщений об ошибках */
  sectionKey: string;
  /** Текущее (типизированное) значение секции */
  value: unknown;
  /** Применить значение из JSON-режима к состоянию страницы; false — значение отвергнуто */
  onApply: (next: unknown) => boolean;
  /** Сохранить секцию на сервере (значение передаётся явно) */
  onSave: (next: unknown) => void;
  saving: boolean;
  /** Ошибки серверной валидации (400 details) для этой секции */
  errors?: string[];
  /** Правка текста в JSON-режиме — пометить вкладку как dirty */
  onDirty?: () => void;
  /** Типизированный редактор секции */
  children: React.ReactNode;
}

/**
 * Обёртка секции конфига: типизированный редактор + продвинутый фолбэк
 * «JSON-режим» (textarea с валидацией парсинга при применении/сохранении).
 */
export default function JsonModeSection({ sectionKey, value, onApply, onSave, saving, errors, onDirty, children }: Props) {
  const [jsonMode, setJsonMode] = useState(false);
  const [jsonText, setJsonText] = useState('');
  const { message } = AntApp.useApp();

  const parseJson = (): { ok: true; value: unknown } | { ok: false } => {
    try {
      return { ok: true, value: JSON.parse(jsonText) };
    } catch (err) {
      message.error(`Невалидный JSON в секции "${sectionKey}": ${(err as Error).message}`);
      return { ok: false };
    }
  };

  const toggleMode = (checked: boolean) => {
    if (checked) {
      setJsonText(JSON.stringify(value, null, 2));
      setJsonMode(true);
      return;
    }
    // Выход из JSON-режима: применяем текст к типизированному состоянию
    const parsed = parseJson();
    if (!parsed.ok) return; // остаёмся в JSON-режиме
    if (!onApply(parsed.value)) return;
    setJsonMode(false);
  };

  const handleSave = () => {
    if (!jsonMode) {
      onSave(value);
      return;
    }
    const parsed = parseJson();
    if (!parsed.ok) return;
    if (!onApply(parsed.value)) return;
    onSave(parsed.value);
  };

  return (
    <Space direction="vertical" style={{ width: '100%' }} size="middle">
      {errors && errors.length > 0 && (
        <Alert
          type="error"
          showIcon
          message="Сервер отклонил секцию (Invalid config)"
          description={<ul style={{ margin: 0, paddingLeft: 18 }}>{errors.map((e, i) => <li key={i}>{e}</li>)}</ul>}
        />
      )}
      <Space>
        <Switch checked={jsonMode} onChange={toggleMode} size="small" />
        <Text type="secondary">JSON-режим (продвинутый)</Text>
      </Space>
      {jsonMode ? (
        <TextArea
          rows={16}
          value={jsonText}
          onChange={(e) => { setJsonText(e.target.value); onDirty?.(); }}
          style={{ fontFamily: 'monospace', fontSize: 13 }}
        />
      ) : (
        children
      )}
      <Button type="primary" icon={<SaveOutlined />} loading={saving} onClick={handleSave}>
        Сохранить
      </Button>
    </Space>
  );
}
