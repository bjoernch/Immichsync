import React, { useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/tauri';
import { appWindow, WebviewWindow } from '@tauri-apps/api/window';
import './styles.css';

type DashboardStats = {
  downloaded: number;
  uploaded: number;
  syncStatus: string;
  lastSync?: string;
  uploadQueue: number;
  downloadQueue: number;
};

type ActionResponse = {
  message: string;
};

const emptyStats: DashboardStats = {
  downloaded: 0,
  uploaded: 0,
  syncStatus: 'Idle',
  uploadQueue: 0,
  downloadQueue: 0
};

const MiniApp: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats>(emptyStats);
  const [status, setStatus] = useState<string>('Ready');
  const [isRefreshing, setIsRefreshing] = useState(false);

  useEffect(() => {
    refreshStatus();
  }, []);

  const refreshStatus = async () => {
    setIsRefreshing(true);
    try {
      const response = await invoke<DashboardStats>('fetch_dashboard');
      setStats(response);
      setStatus(response.syncStatus);
    } catch (error) {
      console.error('fetch_dashboard', error);
      setStatus('Offline');
    } finally {
      setIsRefreshing(false);
    }
  };

  const handleSync = async () => {
    setStatus('Syncing...');
    await invoke<ActionResponse>('sync_now');
    await refreshStatus();
  };

  const openMainWindow = () => {
    const mainWindow = new WebviewWindow('main');
    mainWindow.show().catch(console.error);
    mainWindow.setFocus().catch(console.error);
  };

  const hideMini = () => {
    appWindow.hide().catch(console.error);
  };

  return (
    <div className="mini-shell">
      <div className="mini-header">
        <p>ImmichSync</p>
        <span className="mini-status-tag">{status}</span>
      </div>
      <div className="mini-stats">
        <div>
          <p>Downloaded</p>
          <strong>{stats.downloaded}</strong>
        </div>
        <div>
          <p>Uploaded</p>
          <strong>{stats.uploaded}</strong>
        </div>
      </div>
      <div className="mini-actions">
        <button className="ghost" onClick={refreshStatus} disabled={isRefreshing}>
          Refresh
        </button>
        <button className="primary" onClick={handleSync}>
          Sync Now
        </button>
        <button className="ghost" onClick={openMainWindow}>
          Open Dashboard
        </button>
        <button className="ghost" onClick={hideMini}>
          Hide
        </button>
      </div>
    </div>
  );
};

export default MiniApp;
