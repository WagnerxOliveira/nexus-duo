import React from 'react';
import type { GamerDna } from '@/core/domain/types';
import { DAYS_PT_BR, WeeklyScheduleMask } from '@/core/algo/scheduleDp';

interface GamerDnaBarsProps {
  dna: GamerDna;
  compact?: boolean;
}

const DNA_AXES: readonly {
  key: keyof Pick<GamerDna, 'competitive' | 'voiceCall' | 'coopFocus' | 'nightOwl'>;
  leftLabel: string;
  rightLabel: string;
  barClass: string;
}[] = [
  {
    key: 'competitive',
    leftLabel: 'Casual',
    rightLabel: 'Competitivo',
    barClass: 'from-nexus-primary to-nexus-secondary',
  },
  {
    key: 'voiceCall',
    leftLabel: 'Só Chat',
    rightLabel: 'Call Discord',
    barClass: 'from-nexus-cyber to-nexus-primary',
  },
  {
    key: 'coopFocus',
    leftLabel: 'Solo Chill',
    rightLabel: 'Co-op Total',
    barClass: 'from-nexus-success to-nexus-cyber',
  },
  {
    key: 'nightOwl',
    leftLabel: 'Diurno',
    rightLabel: 'Coruja',
    barClass: 'from-nexus-warning to-nexus-secondary',
  },
];

export function GamerDnaBars({ dna, compact = false }: GamerDnaBarsProps) {
  return (
    <div className={compact ? 'space-y-2.5' : 'space-y-3'}>
      {DNA_AXES.map((axis) => {
        const value = Math.max(0, Math.min(100, dna[axis.key]));
        return (
          <div key={axis.key} className="space-y-1">
            <div className="flex items-center justify-between text-xs">
              <span className="text-nexus-text-secondary">{axis.leftLabel}</span>
              <span className="nexus-tabular text-[11px] font-semibold text-nexus-text">
                {value}%
              </span>
              <span className="text-nexus-text-secondary">{axis.rightLabel}</span>
            </div>
            <div className="h-1.5 w-full overflow-hidden rounded-full bg-white/10">
              <div
                className={`h-full rounded-full bg-gradient-to-r ${axis.barClass}`}
                style={{ width: `${value}%` }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}

interface ScheduleHeatmapStripProps {
  scheduleHours: readonly number[];
  overlapWithHours?: readonly number[];
}

const BLOCK_SLOTS = [
  { label: 'M', start: 6, end: 12 },
  { label: 'T', start: 12, end: 18 },
  { label: 'N', start: 18, end: 24 },
  { label: 'D', start: 0, end: 6 },
] as const;

export function ScheduleHeatmapStrip({
  scheduleHours,
  overlapWithHours,
}: ScheduleHeatmapStripProps) {
  const mask = WeeklyScheduleMask.fromHours(scheduleHours);
  const overlapMask = overlapWithHours
    ? mask.intersect(WeeklyScheduleMask.fromHours(overlapWithHours))
    : null;

  return (
    <div className="grid grid-cols-7 gap-1.5">
      {DAYS_PT_BR.map((day, dayIdx) => (
        <div key={day} className="flex flex-col items-center gap-1">
          <span className="text-[10px] font-semibold uppercase tracking-wide text-nexus-text-muted">
            {day}
          </span>
          <div className="flex w-full flex-col gap-1">
            {BLOCK_SLOTS.map((slot) => {
              let activeCount = 0;
              let overlapCount = 0;
              for (let h = slot.start; h < slot.end; h += 1) {
                const weekHour = dayIdx * 24 + h;
                if (mask.hasHour(weekHour)) activeCount += 1;
                if (overlapMask?.hasHour(weekHour)) overlapCount += 1;
              }
              const cellStyle =
                overlapCount >= 2
                  ? 'bg-nexus-cyber/90 border-nexus-cyber/60'
                  : activeCount >= 2
                    ? 'bg-nexus-primary/65 border-nexus-primary/40'
                    : 'bg-white/[0.04] border-white/[0.06]';

              return (
                <div
                  key={slot.label}
                  className={`h-2.5 w-full rounded-[4px] border ${cellStyle}`}
                  title={`${day} ${slot.start}h–${slot.end}h`}
                />
              );
            })}
          </div>
        </div>
      ))}
    </div>
  );
}
