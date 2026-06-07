import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import { themes as prismThemes } from 'prism-react-renderer';

// koel docs site — ADR-001 (Docusaurus 3.x, toolchain isolated under docs/).
// The authored content tree lives at the docs/ ROOT (getting-started.md,
// concepts/, recipes/, …) per PRD §13 D-3, so the docs plugin is pointed at '.'
// with an explicit `include` allowlist — the markdown paths match the PRD
// contract instead of being buried under a docs/docs/ convention folder.
// Site deploy (GitHub Pages) is Story 9.9; 9.6 only proves it builds locally.

const config: Config = {
  title: 'koel',
  tagline: 'The premium Dart/Flutter SDK for the AG-UI protocol',
  favicon: 'img/favicon.svg',

  url: 'https://si-huynh.github.io',
  baseUrl: '/koel/',

  organizationName: 'si-huynh',
  projectName: 'koel',

  // Premium bar: a dangling link is a build failure, not a warning.
  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          path: '.',
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          // Only the authored content tree — config, the ADR, and node/build
          // artifacts are NOT docs. (ADR-001 lives under docs/ as a decision
          // record, deliberately off the published site.)
          include: [
            'getting-started.md',
            'concepts/**/*.md',
            'recipes/**/*.md',
            'patterns/**/*.md',
            'api-reference.md',
            'migration-guide.md',
            'adapter-cookbook.md',
          ],
          editUrl: 'https://github.com/si-huynh/koel/tree/main/docs/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    navbar: {
      title: 'koel',
      items: [
        { to: '/', label: 'Docs', position: 'left', activeBaseRegex: '^/$' },
        { to: '/concepts/events', label: 'Concepts', position: 'left' },
        { to: '/recipes/quickstart-offline', label: 'Recipes', position: 'left' },
        { to: '/adapter-cookbook', label: 'Adapter Cookbook', position: 'left' },
        {
          href: 'https://pub.dev/packages/koel',
          label: 'pub.dev',
          position: 'right',
        },
        {
          href: 'https://github.com/si-huynh/koel',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            { label: 'Getting Started', to: '/' },
            { label: 'Concepts', to: '/concepts/events' },
            { label: 'Recipes', to: '/recipes/quickstart-offline' },
            { label: 'Migration Guide', to: '/migration-guide' },
          ],
        },
        {
          title: 'More',
          items: [
            { label: 'pub.dev', href: 'https://pub.dev/packages/koel' },
            { label: 'GitHub', href: 'https://github.com/si-huynh/koel' },
          ],
        },
      ],
      copyright: 'MIT © 2026 Si Huynh. Built with Docusaurus.',
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['dart', 'yaml', 'bash', 'json'],
    },
    // Search: Algolia DocSearch (free for OSS, ADR-001) is wired at deploy
    // (Story 9.9) once the site has a crawlable public URL + the OSS index is
    // provisioned. Omitted here so the local build needs no appId/apiKey.
  } satisfies Preset.ThemeConfig,
};

export default config;
