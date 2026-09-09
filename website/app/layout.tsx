import type { Metadata } from 'next';
import './globals.css';

const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '';

export const metadata: Metadata = {
  title: 'Gauge for Codex — Codex usage in your macOS menu bar',
  description:
    'See Codex remaining quota, every usage window, and the exact reset time from your macOS menu bar.',
  applicationName: 'Gauge for Codex',
  keywords: ['Codex', 'macOS', 'menu bar', 'usage', 'quota', 'open source'],
  icons: {
    icon: [
      { url: `${basePath}/favicon.ico?v=2`, sizes: '32x32' },
      { url: `${basePath}/favicon.svg?v=2`, type: 'image/svg+xml' },
      { url: `${basePath}/favicon-32.png?v=2`, sizes: '32x32', type: 'image/png' },
      { url: `${basePath}/favicon-16.png?v=2`, sizes: '16x16', type: 'image/png' },
    ],
    apple: [{ url: `${basePath}/apple-touch-icon.png?v=2`, sizes: '180x180', type: 'image/png' }],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
