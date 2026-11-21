import React from 'react';

interface MatchScoreRingProps {
  percent: number;
  size?: 'sm' | 'md' | 'lg';
  label?: string;
}

export function MatchScoreRing({
  percent,
  size = 'md',
  label = 'MATCH',
}: MatchScoreRingProps) {
  const clamped = Math.max(0, Math.min(100, Math.round(percent)));
  const dimensions =
    size === 'sm'
      ? { box: 48, r: 19, stroke: 3.5, text: 'text-xs' }
      : size === 'lg'
        ? { box: 84, r: 35, stroke: 5, text: 'text-xl' }
        : { box: 64, r: 26, stroke: 4, text: 'text-sm' };

  const circumference = 2 * Math.PI * dimensions.r;
  const dashOffset = circumference * (1 - clamped / 100);
  const strokeColor =
    clamped >= 85
      ? '#10B981'
      : clamped >= 70
        ? '#8B5CF6'
        : '#06B6D4';

  return (
    <div
      className="relative inline-flex items-center justify-center rounded-full bg-nexus-void/80 backdrop-blur-md"
      style={{ width: dimensions.box, height: dimensions.box }}
      aria-label={`${clamped}% de afinidade`}
    >
      <svg
        width={dimensions.box}
        height={dimensions.box}
        viewBox={`0 0 ${dimensions.box} ${dimensions.box}`}
        className="-rotate-90"
      >
        <circle
          cx={dimensions.box / 2}
          cy={dimensions.box / 2}
          r={dimensions.r}
          fill="none"
          stroke="rgba(255,255,255,0.12)"
          strokeWidth={dimensions.stroke}
        />
        <circle
          cx={dimensions.box / 2}
          cy={dimensions.box / 2}
          r={dimensions.r}
          fill="none"
          stroke={strokeColor}
          strokeWidth={dimensions.stroke}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={dashOffset}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center leading-none">
        <span className={`nexus-tabular font-bold text-nexus-text ${dimensions.text}`}>
          {clamped}%
        </span>
        {size !== 'sm' && (
          <span className="mt-0.5 text-[9px] font-semibold tracking-wider text-nexus-text-secondary">
            {label}
          </span>
        )}
      </div>
    </div>
  );
}
