import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/features/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        nexus: {
          void: 'var(--nexus-bg-void)',
          surface: 'var(--nexus-bg-surface)',
          elevated: 'var(--nexus-bg-elevated)',
          primary: 'var(--nexus-brand-primary)',
          secondary: 'var(--nexus-brand-secondary)',
          cyber: 'var(--nexus-accent-cyber)',
          success: 'var(--nexus-semantic-success)',
          warning: 'var(--nexus-semantic-warning)',
          danger: 'var(--nexus-semantic-danger)',
          text: 'var(--nexus-text-primary)',
          'text-secondary': 'var(--nexus-text-secondary)',
          'text-muted': 'var(--nexus-text-muted)',
        },
      },
      fontFamily: {
        display: ['var(--nexus-font-display)'],
        body: ['var(--nexus-font-body)'],
        mono: ['var(--nexus-font-mono)'],
      },
      borderRadius: {
        'nexus-sm': 'var(--nexus-radius-sm)',
        'nexus-md': 'var(--nexus-radius-md)',
        'nexus-lg': 'var(--nexus-radius-lg)',
        'nexus-xl': 'var(--nexus-radius-xl)',
      },
      boxShadow: {
        'nexus-card': 'var(--nexus-shadow-card)',
        'nexus-primary': 'var(--nexus-shadow-glow-primary)',
        'nexus-cyber': 'var(--nexus-shadow-glow-cyber)',
        'nexus-match': 'var(--nexus-shadow-glow-match)',
      },
    },
  },
  plugins: [],
};

export default config;
