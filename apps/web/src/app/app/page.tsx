import React from 'react';
import type { Metadata } from 'next';
import { SecondMonitorWorkspace } from '@/features/second-monitor/SecondMonitorWorkspace';

export const metadata: Metadata = {
  title: 'Modo 2º Monitor · Web App',
  description:
    'Descubra Duos por afinidade de jogos e horários (DP 168h), abra lobbies efêmeros de 2h e converse com criptografia de ponta a ponta X25519 + AES-256-GCM.',
};

export default function AppPage() {
  return <SecondMonitorWorkspace />;
}
