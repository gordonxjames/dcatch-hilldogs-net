import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { getCurrentSession, signOut as cognitoSignOut } from './cognitoClient';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  // session: null (loading) | false (unauthenticated) | { idToken, username, sub }
  const [session, setSession] = useState(null);

  useEffect(() => {
    getCurrentSession().then((s) => {
      setSession(s || false);
    });
  }, []);

  const onSignIn = useCallback((sessionData) => {
    setSession(sessionData);
  }, []);

  const onSignOut = useCallback(() => {
    cognitoSignOut();
    setSession(false);
  }, []);

  return (
    <AuthContext.Provider value={{ session, onSignIn, onSignOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
