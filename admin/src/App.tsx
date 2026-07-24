import { useState, useEffect } from 'react';
import { ConfigProvider, App as AntApp } from 'antd';
import ruRU from 'antd/locale/ru_RU';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import UsersPage from './pages/UsersPage';
import NovelsPage from './pages/NovelsPage';
import ConfigPage from './pages/ConfigPage';
import ReviewsPage from './pages/ReviewsPage';
import PromoPage from './pages/PromoPage';
import AdminLayout from './components/AdminLayout';
import { logoutAdmin } from './services/api';

const pageFromHash = () => {
  const hash = window.location.hash.replace('#/', '') || 'dashboard';
  // '#/login' — служебный маршрут разлогина, не является страницей меню
  return hash === 'login' ? 'dashboard' : hash;
};

function AppContent() {
  const [loggedIn, setLoggedIn] = useState(() => !!localStorage.getItem('admin_token'));
  // Ленивая инициализация из hash — без setState в теле эффекта
  const [page, setPage] = useState(pageFromHash);

  useEffect(() => {
    // Реагируем на смену hash: навигация + разлогин (интерсептор api.ts ставит #/login)
    const onHashChange = () => {
      setPage(pageFromHash());
      setLoggedIn(!!localStorage.getItem('admin_token'));
    };
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);

  const navigate = (key: string) => {
    setPage(key);
    window.location.hash = `#/${key}`;
  };

  const handleLogout = () => {
    // Отзыв refresh-токена на сервере (fire-and-forget) + локальная очистка
    void logoutAdmin();
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
      case 'promo': return <PromoPage />;
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
