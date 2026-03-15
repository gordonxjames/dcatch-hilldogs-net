import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth/AuthContext';
import Footer from './components/Footer';
import NavBar from './components/NavBar';
import Login from './pages/Login';
import Home from './pages/Home';
import Settings from './pages/Settings';

function ProtectedRoute({ children }) {
  const { session } = useAuth();
  if (session === null) {
    return <div className="loading-page"><span className="spinner" /> Loading…</div>;
  }
  if (session === false) return <Navigate to="/login" replace />;
  return children;
}

function PublicRoute({ children }) {
  const { session } = useAuth();
  if (session === null) return null;
  if (session) return <Navigate to="/" replace />;
  return children;
}

function AppShell({ children }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh' }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
        {children}
      </div>
      <Footer />
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={
            <PublicRoute>
              <AppShell><Login /></AppShell>
            </PublicRoute>
          } />
          <Route path="/" element={
            <ProtectedRoute>
              <AppShell><NavBar /><Home /></AppShell>
            </ProtectedRoute>
          } />
          <Route path="/settings" element={
            <ProtectedRoute>
              <AppShell><NavBar /><Settings /></AppShell>
            </ProtectedRoute>
          } />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
