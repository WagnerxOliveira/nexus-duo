import React from 'react';
import Link from 'next/link';
import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { ArrowLeft, Monitor } from 'lucide-react';
import {
  DEMO_CURRENT_USER,
  DEMO_PROFILES,
  findDemoProfileByUsername,
} from '@/core/data/demoSeed';
import { HybridGamerScoringStrategy } from '@/core/algo/matchScoring';
import { getSupabaseServerClient } from '@/core/supabase/server';
import type { GamerProfile } from '@/core/domain/types';
import { NexusLogo } from '@/components/NexusLogo';
import { GamerDnaCardView } from '@/components/GamerDnaCardView';

interface PublicProfilePageProps {
  params: Promise<{ username: string }>;
}

async function resolvePublicProfile(username: string): Promise<GamerProfile | null> {
  const demoMatch = findDemoProfileByUsername(username);
  if (demoMatch) {
    return demoMatch;
  }

  const supabase = await getSupabaseServerClient();
  if (!supabase) {
    return null;
  }

  const normalized = decodeURIComponent(username).trim().replace(/^@/, '').toLowerCase();
  const { data } = await supabase
    .from('profiles')
    .select('id, username, display_name, bio, city_label, is_liveness_verified, discord_handle, e2ee_public_key')
    .ilike('username', normalized)
    .maybeSingle();

  if (!data) return null;

  return {
    ...DEMO_PROFILES[0]!,
    id: String(data.id),
    username: String(data.username),
    displayName: String(data.display_name ?? data.username),
    bio: String(data.bio ?? 'Jogador verificado no NEXUS DUO.'),
    cityLabel: String(data.city_label ?? 'Brasil'),
    isLivenessVerified: Boolean(data.is_liveness_verified),
    discordHandle: String(data.discord_handle ?? ''),
    e2eePublicKeyB64: String(data.e2ee_public_key ?? DEMO_PROFILES[0]!.e2eePublicKeyB64),
  };
}

export async function generateMetadata({
  params,
}: PublicProfilePageProps): Promise<Metadata> {
  const { username } = await params;
  const profile = await resolvePublicProfile(username);

  if (!profile) {
    return {
      title: 'Perfil não encontrado',
      description: 'Este Gamer DNA Card não está disponível no NEXUS DUO.',
    };
  }

  const topGames = profile.games
    .slice(0, 3)
    .map((g) => g.title)
    .join(', ');

  return {
    title: `${profile.displayName} (@${profile.username}) — Gamer DNA Card`,
    description: `${profile.gamerDna.archetype} · Top Jogos: ${topGames}. Horários nobres: ${profile.primeScheduleLabel}. Descubra sua compatibilidade no NEXUS DUO.`,
    openGraph: {
      title: `${profile.displayName} (@${profile.username}) · Gamer DNA Card | NEXUS DUO`,
      description: `${profile.gamerDna.archetype} · ${topGames} · ${profile.primeScheduleLabel}`,
      type: 'profile',
    },
    twitter: {
      card: 'summary_large_image',
      title: `${profile.displayName} (@${profile.username}) — Gamer DNA`,
      description: `Top Jogos: ${topGames} · ${profile.gamerDna.archetype}`,
    },
  };
}

export default async function PublicProfilePage({
  params,
}: PublicProfilePageProps) {
  const { username } = await params;
  const profile = await resolvePublicProfile(username);

  if (!profile) {
    notFound();
  }

  const strategy = new HybridGamerScoringStrategy();
  const score = strategy.calculate(DEMO_CURRENT_USER, profile);

  return (
    <div className="nexus-aura-bg min-h-screen bg-nexus-void text-nexus-text">
      <header className="border-b border-white/[0.08] bg-nexus-void/85 backdrop-blur-xl">
        <div className="mx-auto flex max-w-[1200px] items-center justify-between gap-4 px-4 py-3.5 sm:px-6">
          <div className="flex items-center gap-3">
            <Link
              href="/"
              className="inline-flex items-center gap-1.5 rounded-xl border border-white/10 bg-nexus-surface px-3 py-2 text-xs font-semibold text-nexus-text-secondary transition hover:text-white"
            >
              <ArrowLeft className="h-3.5 w-3.5" />
              Voltar
            </Link>
            <Link href="/" className="hidden sm:inline-flex">
              <NexusLogo />
            </Link>
          </div>

          <Link
            href="/app"
            className="inline-flex items-center gap-2 rounded-xl nexus-brand-gradient px-4 py-2 text-xs font-semibold text-white shadow-nexus-primary transition hover:opacity-95"
          >
            <Monitor className="h-3.5 w-3.5" />
            Abrir Web App
          </Link>
        </div>
      </header>

      <main className="mx-auto max-w-[1200px] px-4 py-10 sm:px-6 lg:py-14">
        {/* Quick switcher for featured demo cards */}
        <div className="mb-8 flex flex-wrap items-center justify-between gap-3">
          <div>
            <span className="text-xs font-semibold uppercase tracking-widest text-nexus-cyber">
              Carta Colecionável Pública · Shareable Stories
            </span>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            {DEMO_PROFILES.map((item) => {
              const active = item.username === profile.username;
              return (
                <Link
                  key={item.username}
                  href={`/u/${item.username}`}
                  className={`rounded-full px-3 py-1 text-xs font-semibold transition ${
                    active
                      ? 'bg-nexus-primary text-white shadow-nexus-primary'
                      : 'border border-white/10 bg-nexus-surface text-nexus-text-secondary hover:text-white'
                  }`}
                >
                  @{item.username}
                </Link>
              );
            })}
          </div>
        </div>

        <GamerDnaCardView profile={profile} matchPercent={score.totalPercent} />
      </main>
    </div>
  );
}
