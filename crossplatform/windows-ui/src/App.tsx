import React, { useEffect, useMemo, useState } from 'react';
import { invoke } from '@tauri-apps/api/tauri';
import './styles.css';

type SectionID =
  | 'dashboard'
  | 'download'
  | 'upload'
  | 'history'
  | 'connection'
  | 'schedule'
  | 'background'
  | 'limits'
  | 'analytics'
  | 'server'
  | 'duplicates'
  | 'reset';

type DashboardStats = {
  downloaded: number;
  uploaded: number;
  syncStatus: string;
  lastSync?: string;
  uploadQueue: number;
  downloadQueue: number;
};

type ConnectionIndicator = {
  title: string;
  value: string;
  detail?: string;
};

const sections: { id: SectionID; label: string; subtitle: string }[] = [
  { id: 'dashboard', label: 'Dashboard', subtitle: 'Sync overview' },
  { id: 'download', label: 'Download', subtitle: 'Asset downloads' },
  { id: 'upload', label: 'Upload', subtitle: 'Local uploads' },
  { id: 'history', label: 'History', subtitle: 'Recent sync events' },
  { id: 'connection', label: 'Connection', subtitle: 'Server + API' },
  { id: 'schedule', label: 'Schedule', subtitle: 'Background sync timing' },
  { id: 'background', label: 'Background', subtitle: 'Agent & permissions' },
  { id: 'limits', label: 'Limits', subtitle: 'Bandwidth & structure' },
  { id: 'analytics', label: 'Analytics', subtitle: 'Transfer graphs' },
  { id: 'server', label: 'Server', subtitle: 'Version + health' },
  { id: 'duplicates', label: 'Duplicates', subtitle: 'Find & resolve' },
  { id: 'reset', label: 'Reset', subtitle: 'Reset preferences' }
];

const emptyStats: DashboardStats = {
  downloaded: 0,
  uploaded: 0,
  syncStatus: 'Idle',
  uploadQueue: 0,
  downloadQueue: 0
};

const sampleConnection: ConnectionIndicator[] = [
  { title: 'Server', value: 'Not checked' },
  { title: 'API key', value: 'Not set' },
  { title: 'Connection', value: 'Pending', detail: 'Use Save + Validate' }
];

const sectionDescriptions: Record<SectionID, string> = {
  dashboard:
    'Track overall sync health, queued assets, and whether ImmichSync is currently active.',
  download: 'Control filter rules, folder structure, and manual download actions.',
  upload: 'Configure upload folders, subfolder rules, and manual queue management.',
  history: 'Review recent syncs, totals, and errors in one scrollable list.',
  connection: 'Validate the host, API key, and inspect permission warnings.',
  schedule: 'Enable automatic sync scheduling and troubleshoot launch agents.',
  background: 'Monitor the background agent, battery behavior, and retries.',
  limits: 'Set bandwidth caps and queue thresholds for safe syncing.',
  analytics: 'Understand transfer speeds with charts and history.',
  server: 'See server version, status, and compatibility insights.',
  duplicates: 'Scan local folders and server assets for duplicates.',
  reset: 'Clear credentials, reset the UI, or reinstall defaults.'
};

const App = () => {
  const [selectedSection, setSelectedSection] = useState<SectionID>('dashboard');
  const [stats, setStats] = useState<DashboardStats>(emptyStats);
  const [connection, setConnection] = useState<ConnectionIndicator[]>(sampleConnection);
  const [logs, setLogs] = useState<string[]>(['Ready to sync.']);
  const [status, setStatus] = useState<string>('Ready');
  const [isLoadingStats, setIsLoadingStats] = useState(false);

  useEffect(() => {
    refreshDashboard();
  }, []);

  const sidebarItems = useMemo(
    () =>
      sections.map((section) => (
        <button
          key={section.id}
          className={`sidebar-item ${selectedSection === section.id ? 'is-active' : ''}`}
          onClick={() => setSelectedSection(section.id)}
        >
          <span>{section.label}</span>
          <small>{section.subtitle}</small>
        </button>
      )),
    [selectedSection]
  );

  async function refreshDashboard() {
    setIsLoadingStats(true);
    setStatus('Refreshing...');
    try {
      const response = await invoke<DashboardStats>('fetch_dashboard');
      setStats(response);
      setStatus(response.syncStatus);
      setConnection([
        { title: 'Server', value: 'immich.local', detail: 'TLS verified' },
        { title: 'API key', value: 'Saved', detail: 'Keychain' },
        { title: 'Connection', value: 'Healthy', detail: '200 /cached /asset' }
      ]);
      setLogs((prev) => ['Dashboard synced', ...prev].slice(0, 5));
    } catch (error) {
      console.error(error);
      setStatus('Failed to refresh');
      setLogs((prev) => [`Failed to refresh: ${error}`, ...prev].slice(0, 5));
    } finally {
      setIsLoadingStats(false);
    }
  }

  const actionButtons = (
    <div className="action-row">
      <button className="primary" onClick={() => invoke('sync_now')}>
        Sync Now
      </button>
      <button className="ghost" onClick={refreshDashboard} disabled={isLoadingStats}>
        Refresh
      </button>
    </div>
  );

  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="Navigation">
        <div className="sidebar-header">
          <div className="logo" />
          <div>
            <p className="app-name">ImmichSync</p>
            <p className="app-tagline">macOS and Windows sync companion</p>
          </div>
        </div>
        <div className="sidebar-items">{sidebarItems}</div>
      </aside>

      <main className="detail-pane">
        <header className="detail-header">
          <div>
            <p className="section-title">{sections.find((s) => s.id === selectedSection)?.label}</p>
            <p className="section-subtitle">{sectionDescriptions[selectedSection]}</p>
          </div>
          {actionButtons}
        </header>

        <section className="status-pills">
          <aside>
            <p className="status-label">Status</p>
            <p className="status-value">{status}</p>
          </aside>
          <div className="progress" aria-label="Overall progress">
            <div className="progress-fill" style={{ width: `${(stats.downloaded + stats.uploaded) / 100}%` }} />
          </div>
          <div className="speed-grid">
            <StatusCard title="Downloaded" value={`${stats.downloaded} assets`} />
            <StatusCard title="Uploaded" value={`${stats.uploaded} assets`} />
            <StatusCard title="Queues" value={`${stats.uploadQueue} upload · ${stats.downloadQueue} download`} />
          </div>
        </section>

        <section className="detail-body">{renderDetail(selectedSection, stats, connection, logs)}</section>
      </main>
    </div>
  );
};

const StatusCard = ({ title, value }: { title: string; value: string }) => (
  <div className="status-card">
    <p className="status-card-title">{title}</p>
    <p className="status-card-value">{value}</p>
  </div>
);

const renderDetail = (
  section: SectionID,
  stats: DashboardStats,
  connection: ConnectionIndicator[],
  logs: string[]
) => {
  switch (section) {
    case 'dashboard':
      return (
        <div className="grid">
          <Panel title="Overview" subtitle="Sync progress and health">
            <p className="panel-text">Last sync: {stats.lastSync ?? 'Never'}</p>
            <p className="panel-text">Sync status: {stats.syncStatus}</p>
            <div className="panel-row">
              <Metric label="Downloaded" value={`${stats.downloaded}`} />
              <Metric label="Uploaded" value={`${stats.uploaded}`} />
              <Metric label="Queue" value={`${stats.uploadQueue} uploads`} />
            </div>
          </Panel>
          <Panel title="Activity" subtitle="Logs">
            {logs.map((log) => (
              <p key={log} className="panel-log">
                {log}
              </p>
            ))}
          </Panel>
        </div>
      );
    case 'download':
      return (
        <div className="grid">
          <Panel title="Download rules" subtitle="Filters + structure">
            <ListItem label="Include Photos" detail="true" />
            <ListItem label="Include Videos" detail="true" />
            <ListItem label="Folder structure" detail="Year/Month" />
            <ListItem label="Metadata" detail="Sidecar JSON" />
          </Panel>
          <Panel title="Manual download" subtitle="Kick off an immediate sync">
            <p className="panel-text">Run the Swift backend (pipeline) to fetch new assets from Immich.</p>
            <button className="primary" onClick={() => invoke('download_now')}>
              Download Now
            </button>
          </Panel>
        </div>
      );
    case 'upload':
      return (
        <Panel title="Upload folder" subtitle="Watch a local folder">
          <ListItem label="Upload enabled" detail="true" />
          <ListItem label="Subfolders" detail="Included" />
          <ListItem label="Allow list" detail="*.jpg, *.mov" />
          <ListItem label="Deny list" detail="Temporary" />
          <ListItem label="Upload speed" detail="{stats.uploadQueue} queued" />
          <button className="ghost" onClick={() => invoke('upload_now')}>
            Scan upload queue
          </button>
        </Panel>
      );
    case 'history':
      return (
        <Panel title="Sync history" subtitle="Recent runs">
          <HistoryList />
        </Panel>
      );
    case 'connection':
      return (
        <Panel title="Connection" subtitle="Validate URL + API key">
          {connection.map((item) => (
            <ListItem key={item.title} label={item.title} detail={`${item.value}${item.detail ? ' · ' + item.detail : ''}`} />
          ))}
          <button className="primary" onClick={() => invoke('validate_connection')}>
            Save + Validate
          </button>
        </Panel>
      );
    case 'schedule':
      return (
        <Panel title="Schedule" subtitle="Automatic runs">
          <ListItem label="Enabled" detail="true" />
          <ListItem label="Next run" detail="02:00 local" />
          <ListItem label="Launch agent" detail="Installed" />
          <p className="panel-text">The backend runs on a schedule and reacts to power/battery state.</p>
        </Panel>
      );
    case 'background':
      return (
        <Panel title="Background" subtitle="Agent and throttling">
          <ListItem label="Battery awareness" detail="Pauses when unplugged" />
          <ListItem label="Notifications" detail="Enabled" />
          <ListItem label="Auto pause" detail="On battery" />
        </Panel>
      );
    case 'limits':
      return (
        <Panel title="Limits" subtitle="Bandwidth and queues">
          <ListItem label="Download cap" detail="20 MB/s" />
          <ListItem label="Upload cap" detail="10 MB/s" />
          <ListItem label="Status limit" detail="50 items" />
        </Panel>
      );
    case 'analytics':
      return (
        <Panel title="Analytics" subtitle="Transfer speeds">
          <p className="panel-text">Visualize throughput without leaving ImmichSync.</p>
        </Panel>
      );
    case 'server':
      return (
        <Panel title="Server" subtitle="Immich instance info">
          <ListItem label="Version" detail="4.1" />
          <ListItem label="Health" detail="Operational" />
          <ListItem label="Duplicate support" detail="Enabled" />
        </Panel>
      );
    case 'duplicates':
      return (
        <Panel title="Duplicates" subtitle="Local + server scans">
          <ListItem label="Local duplicates" detail="3" />
          <ListItem label="Server duplicates" detail="0" />
          <button className="ghost" onClick={() => invoke('check_duplicates')}>
            Run duplicate scan
          </button>
        </Panel>
      );
    case 'reset':
      return (
        <Panel title="Reset" subtitle="Restore defaults">
          <ListItem label="Reset counter" detail="0" />
          <button className="ghost" onClick={() => invoke('reset_settings')}>
            Reset preferences
          </button>
        </Panel>
      );
    default:
      return <p>Select a section above.</p>;
  }
};

const Panel = ({ title, subtitle, children }: React.PropsWithChildren<{ title: string; subtitle: string }>) => (
  <div className="panel">
    <div className="panel-header">
      <h3>{title}</h3>
      <p>{subtitle}</p>
    </div>
    <div className="panel-body">{children}</div>
  </div>
);

const ListItem = ({ label, detail }: { label: string; detail?: string }) => (
  <div className="list-item">
    <span>{label}</span>
    {detail && <strong>{detail}</strong>}
  </div>
);

const Metric = ({ label, value }: { label: string; value: string }) => (
  <div className="metric">
    <p>{label}</p>
    <strong>{value}</strong>
  </div>
);

const HistoryList = () => (
  <div className="history-list">
    {Array.from({ length: 4 }).map((_, index) => (
      <div key={index} className="history-item">
        <span>Sync {index + 1}</span>
        <span>✔ {Math.floor(Math.random() * 20)} downloaded</span>
        <span>⚡ {Math.floor(Math.random() * 5)} errors</span>
      </div>
    ))}
  </div>
);

export default App;
