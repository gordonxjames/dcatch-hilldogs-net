import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

const IconSettings = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
  </svg>
);

export default function NavBar() {
  const { onSignOut } = useAuth();
  const navigate = useNavigate();

  function handleLogout() {
    onSignOut();
    navigate('/login');
  }

  return (
    <nav>
      <a href="https://www.hilldogs.com" className="logo" target="_blank" rel="noreferrer">
        <img src="/hilldogs-logo.png" alt="Hill Dogs" />
        <span>Delta Catcher</span>
      </a>
      <NavLink to="/" end className={({ isActive }) => 'nav-link' + (isActive ? ' active' : '')}>
        Home
      </NavLink>
      <NavLink to="/settings" className={({ isActive }) => 'nav-link nav-settings' + (isActive ? ' active' : '')}
        style={{ marginLeft: 'auto' }} title="Account Settings">
        <IconSettings />
      </NavLink>
      <a className="nav-link logout" onClick={handleLogout} style={{ marginLeft: 0 }}>Log Out</a>
    </nav>
  );
}
