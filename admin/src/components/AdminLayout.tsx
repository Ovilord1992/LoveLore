import { useState } from 'react';
import { Layout, Menu, Button, Typography } from 'antd';
import { DashboardOutlined, UserOutlined, BookOutlined, LogoutOutlined } from '@ant-design/icons';

const { Sider, Header, Content } = Layout;
const { Text } = Typography;

interface Props {
  activeKey: string;
  onNavigate: (key: string) => void;
  onLogout: () => void;
}

export default function AdminLayout({ activeKey, onNavigate, onLogout, children }: Props & { children: React.ReactNode }) {
  const [collapsed, setCollapsed] = useState(false);

  const menuItems = [
    { key: 'dashboard', icon: <DashboardOutlined />, label: 'Дашборд' },
    { key: 'users', icon: <UserOutlined />, label: 'Пользователи' },
    { key: 'novels', icon: <BookOutlined />, label: 'Новеллы' },
  ];

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Sider collapsible collapsed={collapsed} onCollapse={setCollapsed}>
        <div style={{ padding: '16px', textAlign: 'center' }}>
          <Text strong style={{ color: '#fff', fontSize: collapsed ? 14 : 18 }}>
            {collapsed ? '🎭' : '🎭 Amoria'}
          </Text>
        </div>
        <Menu
          theme="dark"
          selectedKeys={[activeKey]}
          items={menuItems}
          onClick={({ key }) => onNavigate(key)}
        />
      </Sider>
      <Layout>
        <Header style={{ background: '#fff', padding: '0 24px', display: 'flex', justifyContent: 'flex-end', alignItems: 'center' }}>
          <Button icon={<LogoutOutlined />} onClick={onLogout}>Выйти</Button>
        </Header>
        <Content style={{ margin: 24, padding: 24, background: '#fff', borderRadius: 8, minHeight: 360 }}>
          {children}
        </Content>
      </Layout>
    </Layout>
  );
}
