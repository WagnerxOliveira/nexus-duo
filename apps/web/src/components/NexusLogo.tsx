import React from 'react';

interface NexusLogoProps {
  compact?: boolean;
  className?: string;
}

export function NexusLogo({ compact = false, className = '' }: NexusLogoProps) {
  return (
    <div className={`inline-flex items-center gap-2.5 select-none ${className}`}>
      <div
        className="relative flex h-9 w-9 shrink-0 items-center justify-center rounded-xl nexus-brand-gradient shadow-nexus-primary"
        aria-hidden="true"
      >
        <svg
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M5 17V7L12 13.5L19 7V17"
            stroke="#F8FAFC"
            strokeWidth="2.4"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <circle cx="12" cy="18.5" r="1.8" fill="#06B6D4" />
        </svg>
      </div>
      {!compact && (
        <div className="flex flex-col leading-none">
          <span className="font-display text-base font-bold tracking-tight text-nexus-text">
            NEXUS <span className="text-nexus-primary">DUO</span>
          </span>
          <span className="nexus-tabular text-[10px] font-semibold uppercase tracking-widest text-nexus-text-muted">
            Cyber-Velvet
          </span>
        </div>
      )}
    </div>
  );
}
