import React from 'react';
import Link from 'next/link';
import type { Metadata } from 'next';
import {
  ArrowRight,
  Clock,
  Download,
  Gamepad2,
  KeyRound,
  Lock,
  MapPinOff,
  Monitor,
  Radio,
  ScanFace,
  ShieldCheck,
  Sparkles,
} from 'lucide-react';
import { NexusLogo } from '@/components/NexusLogo';
import { LandingInteractivePreview } from '@/components/LandingInteractivePreview';

const GITHUB_REPO =
  process.env.NEXT_PUBLIC_GITHUB_REPO ?? 'WagnerxOliveira/nexus-duo';
const APK_RELEASE_URL = `https://github.com/${GITHUB_REPO}/releases/latest`;
const APP_URL = process.env.NEXT_PUBLIC_APP_URL ?? 'https://nexusduo.app';

export const metadata: Metadata = {
  title: 'NEXUS DUO — Relacionamento Gamer com Match de Horários 168h & Chat E2EE',
  description:
    'App de relacionamento gamer feito para conexões reais: compatibilidade por Programação Dinâmica de horários livres, Lobby Efêmero "Duo Agora", chat E2EE X25519 + AES-256-GCM e Modo 2º Monitor.',
  alternates: {
    canonical: APP_URL,
  },
};

const jsonLd = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'NEXUS DUO',
  applicationCategory: 'SocialNetworkingApplication',
  operatingSystem: 'Android, Web',
  url: APP_URL,
  description:
    'Aplicativo de relacionamento gamer com motor de compatibilidade de horários (DP 168h), Lobby Duo Agora, verificação anti-catfish e chat criptografado de ponta a ponta (X25519 + AES-256-GCM).',
  offers: {
    '@type': 'Offer',
    price: '0',
    priceCurrency: 'BRL',
  },
};

export default function LandingPage() {
  return (
    <div className="nexus-aura-bg min-h-screen overflow-x-clip bg-nexus-void text-nexus-text">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      {/* Sticky Glass Header */}
      <header className="sticky top-0 z-40 border-b border-white/[0.08] bg-nexus-void/80 backdrop-blur-xl">
        <div className="mx-auto flex max-w-[1440px] items-center justify-between gap-4 px-4 py-3.5 sm:px-6 lg:px-8">
          <Link href="/" aria-label="NEXUS DUO Home">
            <NexusLogo />
          </Link>

          <nav
            aria-label="Navegação principal"
            className="hidden items-center gap-7 text-sm font-medium text-nexus-text-secondary md:flex"
          >
            <a href="#como-funciona" className="transition hover:text-white">
              Como Funciona
            </a>
            <a href="#seguranca" className="transition hover:text-white">
              Zero-Trust & E2EE
            </a>
            <Link href="/u/valkyrie" className="transition hover:text-white">
              Gamer DNA Card
            </Link>
          </nav>

          <div className="flex items-center gap-2.5">
            <a
              href={APK_RELEASE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="hidden items-center gap-2 rounded-xl border border-white/10 bg-nexus-surface px-3.5 py-2 text-xs font-semibold text-nexus-text transition hover:border-nexus-primary/50 sm:inline-flex"
            >
              <Download className="h-3.5 w-3.5 text-nexus-cyber" />
              APK Android
            </a>
            <Link
              href="/app"
              className="inline-flex items-center gap-2 rounded-xl nexus-brand-gradient px-4 py-2 text-xs font-semibold text-white shadow-nexus-primary transition hover:opacity-95 sm:text-sm"
            >
              Abrir 2º Monitor
              <ArrowRight className="h-4 w-4" />
            </Link>
          </div>
        </div>
      </header>

      <main>
        {/* Hero Section */}
        <section className="mx-auto max-w-[1440px] px-4 pb-16 pt-12 sm:px-6 lg:px-8 lg:pb-24 lg:pt-16">
          <div className="grid items-center gap-12 lg:grid-cols-12">
            <div className="min-w-0 space-y-6 lg:col-span-7">
              <div className="inline-flex flex-wrap items-center gap-2 rounded-full border border-nexus-primary/35 bg-nexus-primary/10 px-3.5 py-1.5 text-xs font-semibold text-nexus-primary">
                <Sparkles className="h-3.5 w-3.5 text-nexus-cyber" />
                <span>Cyber-Velvet · Mobile Flutter + Web 2º Monitor</span>
              </div>

              <h1 className="font-display text-[32px] font-bold leading-[1.12] tracking-[-0.03em] text-nexus-text sm:text-[44px] lg:text-[52px]">
                Encontre o seu{' '}
                <span className="bg-gradient-to-r from-nexus-primary via-nexus-secondary to-nexus-cyber bg-clip-text text-transparent">
                  Duo na vida
                </span>{' '}
                que realmente joga no mesmo horário.
              </h1>

              <p className="max-w-[60ch] text-base leading-relaxed text-nexus-text-secondary sm:text-lg">
                Chega de dar match e nunca coincidir na fila. O{' '}
                <strong className="font-semibold text-nexus-text">NEXUS DUO</strong>{' '}
                calcula afinidade real pelos seus Top Jogos, janelas contínuas da
                semana (DP 168h) e Gamer DNA — com chat cifrado de ponta a ponta
                sincronizado entre o celular e o 2º monitor do PC.
              </p>

              <div className="flex flex-wrap items-center gap-3 pt-2">
                <Link
                  href="/app"
                  className="inline-flex items-center gap-2 rounded-2xl nexus-brand-gradient px-6 py-3.5 text-sm font-semibold text-white shadow-nexus-primary transition hover:opacity-95 sm:text-base"
                >
                  <Monitor className="h-4 w-4" />
                  Entrar no Web App (Modo 2º Monitor)
                  <ArrowRight className="h-4 w-4" />
                </Link>

                <a
                  href={APK_RELEASE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 rounded-2xl border border-white/15 bg-nexus-surface px-5 py-3.5 text-sm font-semibold text-nexus-text transition hover:border-nexus-cyber/60 hover:bg-nexus-elevated sm:text-base"
                >
                  <Download className="h-4 w-4 text-nexus-cyber" />
                  Baixar APK Android (Releases)
                </a>
              </div>

              {/* Metric strip */}
              <div className="grid max-w-xl grid-cols-1 gap-3 pt-4 sm:grid-cols-3">
                <div className="min-w-0 rounded-2xl border border-white/[0.08] bg-nexus-surface/80 p-3.5">
                  <p className="nexus-tabular text-lg font-bold text-nexus-cyber sm:text-xl">
                    O(168)
                  </p>
                  <p className="mt-0.5 text-xs text-nexus-text-secondary">
                    DP de janelas contínuas
                  </p>
                </div>
                <div className="min-w-0 rounded-2xl border border-white/[0.08] bg-nexus-surface/80 p-3.5">
                  <p className="nexus-tabular text-lg font-bold text-nexus-primary sm:text-xl">
                    E2EE
                  </p>
                  <p className="mt-0.5 text-xs text-nexus-text-secondary">
                    X25519 + AES-256-GCM
                  </p>
                </div>
                <div className="min-w-0 rounded-2xl border border-white/[0.08] bg-nexus-surface/80 p-3.5">
                  <p className="nexus-tabular text-lg font-bold text-nexus-success sm:text-xl">
                    2h Live
                  </p>
                  <p className="mt-0.5 text-xs text-nexus-text-secondary">
                    Lobby efêmero “Duo Agora”
                  </p>
                </div>
              </div>
            </div>

            <div className="min-w-0 lg:col-span-5">
              <LandingInteractivePreview />
            </div>
          </div>
        </section>

        {/* How it works / Bento Features */}
        <section
          id="como-funciona"
          className="border-t border-white/[0.08] bg-nexus-surface/40 py-16 lg:py-24"
        >
          <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
            <div className="max-w-[60ch]">
              <span className="text-xs font-semibold uppercase tracking-widest text-nexus-cyber">
                Engenharia de Afinidade Real
              </span>
              <h2 className="mt-2 font-display text-2xl font-bold tracking-tight text-nexus-text sm:text-3xl">
                Projetado para virar partida de verdade — sem fricção e sem ghosting.
              </h2>
            </div>

            <div className="mt-10 grid gap-5 md:grid-cols-2 lg:grid-cols-4">
              <article className="nexus-surface-card rounded-2xl p-6">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-nexus-primary/15 text-nexus-primary">
                  <Clock className="h-5 w-5" />
                </div>
                <h3 className="mt-4 font-display text-lg font-semibold text-nexus-text">
                  Agenda Semanal em Bitmask + DP
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-nexus-text-secondary">
                  Mapeia 168h em 3 inteiros de 64 bits e encontra blocos contínuos
                  de 2h+ (inclusive virada de domingo para segunda) para garantir
                  tempo real de jogo juntos.
                </p>
              </article>

              <article className="nexus-surface-card rounded-2xl p-6">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-nexus-cyber/15 text-nexus-cyber">
                  <Monitor className="h-5 w-5" />
                </div>
                <h3 className="mt-4 font-display text-lg font-semibold text-nexus-text">
                  Modo 2º Monitor Ultra-Leve
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-nexus-text-secondary">
                  DOM nativo Next.js em 3 colunas com baixíssimo consumo de GPU/RAM
                  para ficar aberto ao lado do Valorant, BG3 ou LoL enquanto a fila
                  carrega.
                </p>
              </article>

              <article className="nexus-surface-card rounded-2xl p-6">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-nexus-secondary/15 text-nexus-secondary">
                  <Radio className="h-5 w-5" />
                </div>
                <h3 className="mt-4 font-display text-lg font-semibold text-nexus-text">
                  Lobby Efêmero “Duo Agora”
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-nexus-text-secondary">
                  Livre pelos próximos 90 minutos? Abra um card de lobby com jogo,
                  modo e preferência de call que expira automaticamente em 2h.
                </p>
              </article>

              <article className="nexus-surface-card rounded-2xl p-6">
                <div className="flex h-11 w-11 items-center justify-center rounded-xl bg-nexus-success/15 text-nexus-success">
                  <Gamepad2 className="h-5 w-5" />
                </div>
                <h3 className="mt-4 font-display text-lg font-semibold text-nexus-text">
                  Gamer DNA Card Colecionável
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-nexus-text-secondary">
                  Compartilhe seu arquétipo, Top Jogos, selos OCR e GG Badges em{' '}
                  <Link
                    href="/u/valkyrie"
                    className="font-semibold text-nexus-cyber underline decoration-nexus-cyber/40 underline-offset-4 hover:text-white"
                  >
                    /u/valkyrie
                  </Link>{' '}
                  pronto para Discord e Stories.
                </p>
              </article>
            </div>
          </div>
        </section>

        {/* Zero-Trust Security & E2EE Section */}
        <section id="seguranca" className="py-16 lg:py-24">
          <div className="mx-auto max-w-[1440px] px-4 sm:px-6 lg:px-8">
            <div className="nexus-surface-card overflow-hidden rounded-[24px] p-6 sm:p-10">
              <div className="grid gap-10 lg:grid-cols-12">
                <div className="space-y-4 lg:col-span-5">
                  <span className="inline-flex items-center gap-1.5 rounded-full border border-nexus-success/35 bg-nexus-success/10 px-3 py-1 text-xs font-semibold text-nexus-success">
                    <ShieldCheck className="h-3.5 w-3.5" />
                    Arquitetura Zero-Trust & LGPD
                  </span>
                  <h2 className="font-display text-2xl font-bold tracking-tight text-nexus-text sm:text-3xl">
                    Privacidade física e digital como requisito de engenharia, não
                    discurso.
                  </h2>
                  <p className="max-w-[58ch] text-sm leading-relaxed text-nexus-text-secondary sm:text-base">
                    Suas conversas são cifradas localmente antes de tocar a rede,
                    sua localização exata nunca é exposta a terceiros e sua conta
                    pode ser exportada ou purgada em 1 clique.
                  </p>
                  <div className="pt-2">
                    <Link
                      href="/app"
                      className="inline-flex items-center gap-2 text-sm font-semibold text-nexus-cyber hover:underline"
                    >
                      Inspecionar chat E2EE ao vivo no Web App
                      <ArrowRight className="h-4 w-4" />
                    </Link>
                  </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2 lg:col-span-7">
                  <div className="nexus-elevated-card rounded-2xl p-5">
                    <Lock className="h-5 w-5 text-nexus-primary" />
                    <h3 className="mt-3 font-display text-base font-semibold text-nexus-text">
                      Chat E2EE Interoperável
                    </h3>
                    <p className="mt-1.5 text-xs leading-relaxed text-nexus-text-secondary">
                      Troca de chaves X25519 + HKDF-SHA256 + AES-256-GCM com AAD
                      vinculado ao match e remetente. Compatível bit a bit entre
                      Flutter Mobile e WebCrypto.
                    </p>
                  </div>

                  <div className="nexus-elevated-card rounded-2xl p-5">
                    <ScanFace className="h-5 w-5 text-nexus-cyber" />
                    <h3 className="mt-3 font-display text-base font-semibold text-nexus-text">
                      Selfie Liveness On-Device
                    </h3>
                    <p className="mt-1.5 text-xs leading-relaxed text-nexus-text-secondary">
                      Desafios de vivacidade processados localmente para selo
                      anti-catfish sem enviar vídeo biométrico para servidores
                      externos.
                    </p>
                  </div>

                  <div className="nexus-elevated-card rounded-2xl p-5">
                    <MapPinOff className="h-5 w-5 text-nexus-secondary" />
                    <h3 className="mt-3 font-display text-base font-semibold text-nexus-text">
                      Anti-Stalking Location Fuzzing
                    </h3>
                    <p className="mt-1.5 text-xs leading-relaxed text-nexus-text-secondary">
                      Distância exibida apenas em faixas aproximadas (~8 km).
                      Coordenadas exatas jamais são retornadas para outros usuários.
                    </p>
                  </div>

                  <div className="nexus-elevated-card rounded-2xl p-5">
                    <KeyRound className="h-5 w-5 text-nexus-success" />
                    <h3 className="mt-3 font-display text-base font-semibold text-nexus-text">
                      Row Level Security & LGPD
                    </h3>
                    <p className="mt-1.5 text-xs leading-relaxed text-nexus-text-secondary">
                      RLS estrito em 100% das tabelas Supabase, blur protetor em
                      mídias recebidas, exportação JSON e exclusão definitiva.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-white/[0.08] bg-nexus-void py-10">
        <div className="mx-auto flex max-w-[1440px] flex-col items-start justify-between gap-6 px-4 sm:flex-row sm:items-center sm:px-6 lg:px-8">
          <div className="space-y-2">
            <NexusLogo />
            <p className="text-xs text-nexus-text-muted">
              NEXUS DUO · Mobile Flutter + Web 2º Monitor Next.js · Zero-Trust E2EE
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-4 text-xs font-medium text-nexus-text-secondary">
            <Link href="/app" className="hover:text-white">
              Web App (/app)
            </Link>
            <Link href="/u/valkyrie" className="hover:text-white">
              @valkyrie
            </Link>
            <Link href="/u/biacozy" className="hover:text-white">
              @biacozy
            </Link>
            <Link href="/u/kael_br" className="hover:text-white">
              @kael_br
            </Link>
            <Link href="/u/rafatank" className="hover:text-white">
              @rafatank
            </Link>
            <a
              href={APK_RELEASE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-nexus-cyber hover:underline"
            >
              GitHub Releases APK
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
