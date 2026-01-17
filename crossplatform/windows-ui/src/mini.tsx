import React from 'react';
import ReactDOM from 'react-dom/client';
import MiniApp from './MiniApp';
import './styles.css';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <MiniApp />
  </React.StrictMode>
);
