import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

// GitHub Pages serverer appen under /aarhus-togo/.
export default defineConfig({
  base: process.env.BASE_PATH ?? '/aarhus-togo/',
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['apple-touch-icon.png', 'icon-192.png', 'icon-512.png'],
      manifest: {
        name: 'Aarhus ToGo',
        short_name: 'Aarhus ToGo',
        description: 'Voyager vert à Aarhus',
        lang: 'fr',
        start_url: '.',
        display: 'standalone',
        orientation: 'portrait',
        background_color: '#F3F5F0',
        theme_color: '#F3F5F0',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any maskable' },
        ],
      },
      workbox: {
        // Appen, data og fotos virker offline; kortfliser og skrifter gemmes, når de er set.
        globPatterns: ['**/*.{js,css,html,png,jpg,svg,json}'],
        maximumFileSizeToCacheInBytes: 4 * 1024 * 1024,
        runtimeCaching: [
          { urlPattern: /tile\.openstreetmap\.org/, handler: 'CacheFirst', options: { cacheName: 'tiles', expiration: { maxEntries: 400, maxAgeSeconds: 60 * 60 * 24 * 30 } } },
          { urlPattern: /fonts\.(googleapis|gstatic)\.com/, handler: 'CacheFirst', options: { cacheName: 'fonts' } },
        ],
      },
    }),
  ],
});
