// Saves the homepage's logo section in both themes, for the pull request.
import { chromium } from 'playwright'

const [url, directory] = process.argv.slice(2)
const browser = await chromium.launch()

for (const theme of ['light', 'dark']) {
  const page = await browser.newPage({ colorScheme: theme, viewport: { width: 1280, height: 900 } })
  await page.goto(url, { waitUntil: 'load' })
  await page.evaluate((value) => document.documentElement.setAttribute('data-theme', value), theme)
  await page.locator('.home-companies-section').first().screenshot({ path: `${directory}/company-logos-${theme}.png` })
}

await browser.close()
