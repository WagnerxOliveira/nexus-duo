import React from 'react';
import { ShieldCheck } from 'lucide-react';

interface AvatarArtProps {
  glyph: string;
  displayName: string;
  gradient: readonly [string, string, string];
  size?: 'sm' | 'md' | 'lg' | 'card';
  isOnline?: boolean;
  isVerified?: boolean;
  className?: string;
}

export function AvatarArt({
  glyph,
  displayName,
  gradient,
  size = 'md',
  isOnline = false,
  isVerified = false,
  className = '',
}: AvatarArtProps) {
  const [c1, c2, c3] = gradient;

  if (size === 'card') {
    return (
      <div
        className={`relative w-full overflow-hidden ${className}`}
        style={{
          background: `radial-gradient(circle at 22% 18%, ${c1}66 0%, transparent 55%), radial-gradient(circle at 82% 28%, ${c2}55 0%, transparent 52%), linear-gradient(160deg, ${c3} 0%, #080A0F 100%)`,
        }}
        aria-label={`Retrato estilizado de ${displayName}`}
      >
        {/* Subtle editorial geometric grid & cyber glow */}
        <svg
          className="absolute inset-0 h-full w-full opacity-25"
          viewBox="0 0 400 460"
          fill="none"
          preserveAspectRatio="xMidYMid slice"
          aria-hidden="true"
        >
          <defs>
            <linearGradient id={`ring-${glyph}`} x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor={c1} />
              <stop offset="100%" stopColor={c2} />
            </linearGradient>
          </defs>
          <circle
            cx="200"
            cy="170"
            r="118"
            stroke={`url(#ring-${glyph})`}
            strokeWidth="1.5"
            strokeDasharray="6 8"
          />
          <circle
            cx="200"
            cy="170"
            r="84"
            stroke={c2}
            strokeOpacity="0.45"
            strokeWidth="1"
          />
          <path
            d="M40 340 L120 280 L280 280 L360 340"
            stroke="#F8FAFC"
            strokeOpacity="0.14"
            strokeWidth="1"
          />
        </svg>

        {/* Stylized editorial silhouette emblem */}
        <div className="relative flex h-full w-full items-center justify-center pb-16 pt-8">
          <div
            className="flex h-36 w-36 items-center justify-center rounded-full border border-white/15 shadow-2xl"
            style={{
              background: `linear-gradient(135deg, ${c1}CC 0%, ${c2}B3 100%)`,
              boxShadow: `0 0 50px ${c1}44`,
            }}
          >
            <span className="font-display text-5xl font-bold tracking-tight text-white">
              {glyph}
            </span>
          </div>
        </div>
      </div>
    );
  }

  const sizeClass =
    size === 'sm'
      ? 'h-10 w-10 text-sm'
      : size === 'lg'
        ? 'h-16 w-16 text-xl'
        : 'h-12 w-12 text-base';

  return (
    <div className={`relative inline-flex shrink-0 ${className}`}>
      <div
        className={`flex items-center justify-center rounded-2xl border border-white/15 font-display font-bold text-white shadow-md ${sizeClass}`}
        style={{
          background: `linear-gradient(135deg, ${c1} 0%, ${c2} 100%)`,
        }}
        aria-label={displayName}
      >
        {glyph}
      </div>
      {isOnline && (
        <span
          className="absolute -bottom-0.5 -right-0.5 h-3.5 w-3.5 rounded-full border-2 border-nexus-surface bg-nexus-cyber"
          title="Online agora"
        />
      )}
      {isVerified && !isOnline && (
        <span
          className="absolute -bottom-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full border border-nexus-surface bg-nexus-elevated text-nexus-cyber"
          title="Liveness verificado"
        >
          <ShieldCheck className="h-3 w-3" />
        </span>
      )}
    </div>
  );
}
