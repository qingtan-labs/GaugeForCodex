import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Gauge for Codex — Codex usage in your macOS menu bar',
  description:
    'See Codex remaining quota, every usage window, and the exact reset time from your macOS menu bar.',
  applicationName: 'Gauge for Codex',
  keywords: ['Codex', 'macOS', 'menu bar', 'usage', 'quota', 'open source'],
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
