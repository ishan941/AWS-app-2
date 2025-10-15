import { useState, useEffect } from 'react';
import { Routes, Route, Link } from 'react-router-dom';
import { HealthResponse } from '@aws-app/shared';
import { apiClient } from './services/apiClient';
import './App.css';

function App() {
  const [apiData, setApiData] = useState<HealthResponse | null>(null);
  const [loading, setLoading] = useState(false);

  const fetchApiData = async () => {
    setLoading(true);
    try {
      const data = await apiClient.getHealth();
      setApiData(data);
    } catch (error) {
      console.error('Error fetching API data:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchApiData();
  }, []);

  return (
    <div className="App">
      <header className="App-header">
        <nav>
          <Link to="/" className="nav-link">
            Home
          </Link>
          <Link to="/about" className="nav-link">
            About
          </Link>
        </nav>
      </header>

      <main className="App-main">
        <Routes>
          <Route
            path="/"
            element={
              <Home
                apiData={apiData}
                loading={loading}
                onRefresh={fetchApiData}
              />
            }
          />
          <Route path="/about" element={<About />} />
        </Routes>
      </main>
    </div>
  );
}

function Home({
  apiData,
  loading,
  onRefresh,
}: {
  apiData: HealthResponse | null;
  loading: boolean;
  onRefresh: () => void;
}) {
  return (
    <div className="page">
      <h1>AWS App Frontend</h1>
      <p>Welcome to the React frontend of your monorepo!</p>

      <div className="api-section">
        <h2>Backend API Status</h2>
        {loading ? (
          <p>Loading...</p>
        ) : apiData ? (
          <div className="api-response">
            <p>
              <strong>Message:</strong> {apiData.message}
            </p>
            <p>
              <strong>Timestamp:</strong>{' '}
              {new Date(apiData.timestamp).toLocaleString()}
            </p>
          </div>
        ) : (
          <p>Unable to connect to backend API</p>
        )}
        <button onClick={onRefresh} disabled={loading}>
          Refresh API Status
        </button>
      </div>
    </div>
  );
}

function About() {
  return (
    <div className="page">
      <h1>About</h1>
      <p>This is a monorepo application built with:</p>
      <ul>
        <li>React + TypeScript (Frontend)</li>
        <li>NestJS + TypeScript (Backend)</li>
        <li>Vite (Build Tool)</li>
        <li>npm Workspaces (Monorepo Management)</li>
      </ul>
    </div>
  );
}

export default App;
