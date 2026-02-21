import { useState, useEffect } from 'react';
import { ConfigProvider, App as AntApp } from 'antd';
import ruRU from 'antd/locale/ru_RU';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import UsersPage from './pages/UsersPage';
import NovelsPage from './pages/NovelsPage';
import ConfigPage from './pages/ConfigPage';
import ReviewsPage from './pages/ReviewsPage';
import AdminLayout from './components/AdminLayout';

function AppContent() {
  const [loggedIn, setLoggedIn] = useState(!!localStorage.getItem('admin_token'));
  const [page, setPage] = useState('dashboard');

  useEffect(() => {
    const hash = window.location.hash.replace('#/', '') || 'dashboard';
    setPage(hash);
  }, []);

  const navigate = (key: string) => {
    setPage(key);
    window.location.hash = `#/${key}`;
  };

  const handleLogout = () => {
    localStorage.removeItem('admin_token');
    setLoggedIn(false);
  };

  if (!loggedIn) {
    return <LoginPage onLogin={() => setLoggedIn(true)} />;
  }

  const renderPage = () => {
    switch (page) {
      case 'users': return <UsersPage />;
      case 'novels': return <NovelsPage />;
      case 'reviews': return <ReviewsPage />;
      case 'config': return <ConfigPage />;
      default: return <DashboardPage />;
    }
  };

  return (
    <AdminLayout activeKey={page} onNavigate={navigate} onLogout={handleLogout}>
      {renderPage()}
    </AdminLayout>
  );
}

export default function App() {
  return (
    <ConfigProvider locale={ruRU}>
      <AntApp>
        <AppContent />
      </AntApp>
    </ConfigProvider>
  );
}
