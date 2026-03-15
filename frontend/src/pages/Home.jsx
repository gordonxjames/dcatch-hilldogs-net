import { useAuth } from '../auth/AuthContext';

export default function Home() {
  const { session } = useAuth();

  return (
    <div className="page">
      <p style={{ fontSize: 24, fontWeight: 700, color: 'var(--primary-dark)' }}>
        Welcome, {session?.username}.
      </p>
    </div>
  );
}
