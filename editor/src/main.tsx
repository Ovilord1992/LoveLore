import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { initEditorPersistence } from './store/editorStore'

// Асинхронная гидратация из IndexedDB (мультипроект + ассеты).
// App показывает заглушку, пока hasHydrated === false.
void initEditorPersistence()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
