import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test, type Page } from '@playwright/test';

const SCREENSHOT_DIR = process.env.SWARM_SCREENSHOT_DIR ?? '';

function trackConsoleErrors(page: Page): string[] {
  const errors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push(msg.text());
    }
  });
  page.on('pageerror', (err) => {
    errors.push(err.message);
  });
  return errors;
}

async function assertNoHorizontalOverflow(page: Page) {
  const metrics = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: document.documentElement.clientWidth,
  }));
  expect(metrics.scrollWidth).toBeLessThanOrEqual(metrics.clientWidth);
}

test.describe('NEXUS DUO Web — SEO, Viral Card, 2o Monitor & Responsividade', () => {
  test('Landing Page (/): SEO, Security Headers, APK CTA e Zero Overflow (Desktop + Mobile)', async ({
    page,
  }) => {
    const errors = trackConsoleErrors(page);

    await page.setViewportSize({ width: 1440, height: 900 });
    const response = await page.goto('/', { waitUntil: 'networkidle' });
    expect(response?.status()).toBe(200);

    // Security headers
    const headers = response?.headers() ?? {};
    expect(headers['x-frame-options']).toBe('DENY');
    expect(headers['x-content-type-options']).toBe('nosniff');
    expect(headers['referrer-policy']).toBe('strict-origin-when-cross-origin');
    expect(headers['content-security-policy']).toContain("default-src 'self'");

    // SEO metadata + JSON-LD
    await expect(page).toHaveTitle(/NEXUS DUO/);
    const metaDesc = await page
      .locator('meta[name="description"]')
      .getAttribute('content');
    expect(metaDesc).toContain('Programação Dinâmica');

    const ogTitle = await page
      .locator('meta[property="og:title"]')
      .getAttribute('content');
    expect(ogTitle).toContain('NEXUS DUO');

    const jsonLdText = await page
      .locator('script[type="application/ld+json"]')
      .textContent();
    expect(jsonLdText).toContain('SoftwareApplication');

    // APK Download CTA + /app CTA
    const apkLink = page
      .locator('a[href="https://github.com/WagnerxOliveira/nexus-duo/releases/latest"]')
      .first();
    await expect(apkLink).toBeVisible();
    await expect(page.locator('a[href="/app"]').first()).toBeVisible();

    await assertNoHorizontalOverflow(page);

    if (SCREENSHOT_DIR) {
      mkdirSync(SCREENSHOT_DIR, { recursive: true });
      await page.screenshot({
        path: join(SCREENSHOT_DIR, 'landing-1440x900.png'),
        fullPage: false,
      });
    }

    // Mobile viewport check (390x844)
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(150);
    await assertNoHorizontalOverflow(page);

    expect(errors).toEqual([]);
  });

  test('Public Viral Gamer DNA Card (/u/valkyrie e /u/biacozy)', async ({ page }) => {
    const errors = trackConsoleErrors(page);

    await page.setViewportSize({ width: 1440, height: 900 });
    const response = await page.goto('/u/valkyrie', { waitUntil: 'networkidle' });
    expect(response?.status()).toBe(200);

    await expect(page).toHaveTitle(/Clara.*@valkyrie/);
    await expect(page.getByTestId('gamer-dna-card')).toBeVisible();
    await expect(page.getByText('Estrategista Serena')).toBeVisible();
    await expect(page.getByText('Valorant').first()).toBeVisible();
    await expect(page.getByText('Zero Tilt')).toBeVisible();

    await assertNoHorizontalOverflow(page);

    if (SCREENSHOT_DIR) {
      mkdirSync(SCREENSHOT_DIR, { recursive: true });
      await page.screenshot({
        path: join(SCREENSHOT_DIR, 'gamer-dna-valkyrie-1440x900.png'),
        fullPage: false,
      });
    }

    // Mobile check on /u/valkyrie
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(150);
    await assertNoHorizontalOverflow(page);

    // Secondary demo profile
    await page.goto('/u/biacozy', { waitUntil: 'networkidle' });
    await expect(page).toHaveTitle(/Bia.*@biacozy/);
    await expect(page.getByText('Cozy Exploradora')).toBeVisible();
    await assertNoHorizontalOverflow(page);

    expect(errors).toEqual([]);
  });

  test('Web App Modo 2º Monitor (/app): Descoberta -> Match -> Chat E2EE -> Lobby -> LGPD', async ({
    page,
  }) => {
    const errors = trackConsoleErrors(page);

    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto('/app', { waitUntil: 'networkidle' });

    // Discovery Deck + Seeded Match + Right Context Panel (>= 1440px) visible
    await expect(page.getByTestId('discovery-card')).toBeVisible();
    await expect(page.getByTestId('match-list-item-valkyrie')).toBeVisible();
    await expect(page.getByText('Detalhes do Duo')).toBeVisible();
    await expect(page.getByTestId('schedule-overlap-badge')).toContainText(
      'livres em comum',
    );
    await assertNoHorizontalOverflow(page);

    if (SCREENSHOT_DIR) {
      mkdirSync(SCREENSHOT_DIR, { recursive: true });
      await page.screenshot({
        path: join(SCREENSHOT_DIR, 'app-second-monitor-1440x900.png'),
        fullPage: false,
      });
    }

    // Click Like -> IT'S A DUO! celebration modal -> click Icebreaker #0 -> opens E2EE Chat
    await page.getByTestId('action-like').click();
    await expect(page.getByTestId('match-celebration-modal')).toBeVisible();
    await expect(page.getByText("IT'S A DUO!")).toBeVisible();

    await page.getByTestId('icebreaker-btn-0').click();
    await expect(page.getByTestId('e2ee-chat-view')).toBeVisible();

    // Send a live E2EE message and verify it decrypts cleanly in feed
    const customMsg = 'Bora Swiftplay às 21h! Mensagem E2EE verificada.';
    await page.getByTestId('chat-message-input').fill(customMsg);
    await page.getByTestId('chat-send-button').click();
    await expect(page.getByText(customMsg)).toBeVisible();

    // Navigate to Clara's match to test protective media blur toggle
    await page.getByTestId('match-list-item-valkyrie').click();
    const blurToggle = page.getByTestId('toggle-media-blur').first();
    await expect(blurToggle).toBeVisible();
    await expect(blurToggle).toContainText('Revelar mídia');
    await blurToggle.click();
    await expect(blurToggle).toContainText('Ocultar mídia');

    // Navigate to Lobby "Duo Agora" and create a new 2h lobby
    await page.getByTestId('nav-rail-lobby').click();
    await expect(page.getByTestId('duo-lobby-view')).toBeVisible();
    await page.getByTestId('lobby-game-input').fill("Baldur's Gate 3");
    await page
      .getByTestId('lobby-notes-input')
      .fill('Ato 1 cooperativo sem pressa agora!');
    await page.getByTestId('lobby-create-button').click();
    await expect(
      page
        .getByTestId('duo-lobby-view')
        .getByText('Ato 1 cooperativo sem pressa agora!'),
    ).toBeVisible();

    // Navigate to Profile & Central LGPD -> export JSON
    await page.getByTestId('nav-rail-profile').click();
    await expect(page.getByTestId('profile-lgpd-view')).toBeVisible();
    await page.getByTestId('lgpd-export-button').click();
    await expect(page.getByTestId('lgpd-export-preview')).toContainText(
      'NEXUS DUO Web',
    );

    await assertNoHorizontalOverflow(page);

    // Responsive Mobile Web (390x844) with Bottom Navigation
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(150);
    await expect(page.getByTestId('nav-mobile-discover')).toBeVisible();
    await assertNoHorizontalOverflow(page);

    await page.getByTestId('nav-mobile-discover').click();
    await assertNoHorizontalOverflow(page);

    await page.getByTestId('nav-mobile-chat').click();
    await assertNoHorizontalOverflow(page);

    await page.getByTestId('nav-mobile-lobby').click();
    await assertNoHorizontalOverflow(page);

    expect(errors).toEqual([]);
  });
});
