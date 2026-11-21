import type { Metadata, Viewport } from 'next';
import './globals.css';

const APP_URL = process.env.NEXT_PUBLIC_APP_URL ?? 'https://nexusduo.app';

export const metadata: Metadata = {
  metadataBase: new URL(APP_URL),
  title: {
    default: 'NEXUS DUO — Relacionamento Gamer com Match por Horários & Chat E2EE',
    template: '%s · NEXUS DUO',
  },
  description:
    'Encontre seu Duo na vida e no jogo. Motor de afinidade com Programação Dinâmica de 168h, Lobby Efêmero "Duo Agora", Chat E2EE X25519 + AES-256-GCM e Modo 2º Monitor ultra-leve.',
  keywords: [
    'relacionamento gamer',
    'app gamer match',
    'encontrar duo',
    'nexus duo',
    'chat criptografado e2ee',
    'segundo monitor gamer',
    'valorant duo',
    'stardew valley coop',
  ],
  authors: [{ name: 'NEXUS DUO' }],
  openGraph: {
    type: 'website',
    locale: 'pt_BR',
    url: APP_URL,
    siteName: 'NEXUS DUO',
    title: 'NEXUS DUO — Seu Próximo Duo na Vida e no Jogo',
    description:
      'Compatibilidade real de jogos e horários livres em comum, verificação anti-catfish on-device e chat E2EE sincronizado entre celular e 2º monitor.',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'NEXUS DUO — Relacionamento Gamer & Modo 2º Monitor',
    description:
      'Match por afinidade de jogos + janelas contínuas de horário + chat criptografado E2EE.',
  },
  robots: {
    index: true,
    follow: true,
  },
};

export const viewport: Viewport = {
  themeColor: '#080A0F',
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-BR" className="dark">
      <body className="bg-nexus-void text-nexus-text antialiased selection:bg-nexus-primary/35 selection:text-white">
        {children}
      </body>
    </html>
  );
}
