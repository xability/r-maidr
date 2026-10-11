#!/usr/bin/env node
// Use the R charts of Quarto pages from the keyboard.
//
// `quarto-smoke.R` renders the pages with the Quarto CLI. Here each is
// loaded in headless Chromium and checked the way a reader would find it:
//
//   * `dash.html`, a dashboard: each chart is in a card of its own, titled
//     by its chunk, in the chunks' order, as a chunk's image is, and fills
//     it as Quarto fills the card beside it with an image, larger than the
//     chart's own size: as large, less the line kept below the chart for
//     maidr's text and the room the card keeps for its scrollbar, and
//     centred in it; and as large as the card when it is shown full screen.
//     The chart keeps its size and place while the reader uses it -- on the
//     focus, a key, braille turned on and off, and when the focus leaves --
//     in a card too short for maidr's braille field too, which the card
//     scrolls into view, and a pointer moved from point to point of a
//     scatter plot there, once the reader has clicked into it, hears each
//     point it is on. With a
//     card shown full screen, Escape pressed in its chart -- on the chart,
//     or to close maidr's help -- leaves the card full screen, whether the
//     card was shown full screen before the chart had the focus or after,
//     and Escape pressed anywhere else in it takes it back. High contrast,
//     turned on in a chart, paints the chart dark and leaves the page in its
//     own colours, read from what the page shows whatever paints it.
//   * `deck.html`, a reveal.js deck, in a window large enough for reveal.js
//     to scale its slides up: in the chart on its second slide, Right
//     Arrow is maidr's and leaves the slide where it is; neither
//     Ctrl+Shift+F nor Ctrl+F with Caps Lock on, each of which opens the
//     deck's search out of a chart, opens it, and Ctrl+Shift+F can still
//     be recorded as a shortcut in maidr's settings; maidr's help, opened
//     from it, stays within the window on a slide reveal.js scales up;
//     Shift+Tab, with no tab stop before the chart -- only a link taken out
//     of the tab order -- puts the focus on the slide, where Right Arrow
//     moves the deck on. The text reveal.js reads aloud as each of the two
//     slides is shown holds none of its chart's tick labels. The chart
//     alone on its slide is stretched as Quarto stretches the picture alone
//     on another, larger than its own size and as large, less no more than
//     the room maidr's instructions, text and braille and review fields
//     take below it, which stay on the slide; and it keeps its size and
//     place while the reader uses it. A chart on a slide marked
//     `.nostretch`, and one in a column, keep their own size, as Quarto
//     stretches no picture there.
//   * `fig.html`, a page with a chart in a Quarto figure: the chart stands
//     in the middle of the figure, as Quarto centres its figures. A chart at
//     Quarto's 7 x 5 in is shown as large as a picture is, and one at
//     `out-width: 100%` as wide as a picture given it, wider than its own
//     size.
//
//     node .github/scripts/quarto-smoke.mjs <dir-rendered-by-quarto-smoke.R>
//
// Needs the `playwright` package and its Chromium; `MAIDR_SMOKE_CHROMIUM`
// names an executable to use instead of the one Playwright installed.

import { chromium } from 'playwright';
import path from 'node:path';

const dir = process.argv[2];
if (!dir) {
  console.error('usage: quarto-smoke.mjs <dir-rendered-by-quarto-smoke.R>');
  process.exit(2);
}

const settle = 400;
const failures = [];
const check = (ok, what) => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`);
  if (!ok) {
    failures.push(what);
  }
};

// The element maidr makes focusable around a chart's svg.
const plotOf = 'figure[id^="maidr-figure"] > [tabindex="0"]';

// What a reader sees of a chart or a picture, in the page's pixels: an
// image as object-fit shows it in its box, an svg as its viewBox does (its
// default preserveAspectRatio, as contain does an image), and where.
const drawnScript = () => {
  window.__maidrSmokeDrawn = element => {
    const box = element.getBoundingClientRect();
    let [width, height] = [box.width, box.height];
    const [own, ownHeight] = element.tagName === 'IMG'
      ? [element.naturalWidth, element.naturalHeight]
      : [element.viewBox.baseVal.width, element.viewBox.baseVal.height];
    const fitted = element.tagName !== 'IMG'
      || ['contain', 'scale-down'].includes(getComputedStyle(element).objectFit);
    if (fitted && own > 0 && ownHeight > 0) {
      const scale = Math.min(box.width / own, box.height / ownHeight);
      [width, height] = [own * scale, ownHeight * scale];
    }
    const round = value => Math.round(value * 10) / 10;
    return {
      left: round(box.left + (box.width - width) / 2),
      top: round(box.top + (box.height - height) / 2),
      width: round(width),
      height: round(height),
    };
  };
};
const sameSize = (a, b, slack = 1) => Boolean(a && b)
  && Math.abs(a.width - b.width) <= slack && Math.abs(a.height - b.height) <= slack;
const near = (a, b, slack = 1) => Math.abs(a - b) <= slack;

// Where a chart's svg is in the box it scrolls with, and how large: the
// same whatever the box is scrolled to.
const placeScript = () => {
  window.__maidrSmokePlace = svg => {
    const box = svg.closest('.maidr-knitr').parentElement;
    const r = svg.getBoundingClientRect();
    const b = box.getBoundingClientRect();
    const round = value => Math.round(value * 10) / 10;
    return [round(r.left - b.left), round(r.top - b.top + box.scrollTop), round(r.width), round(r.height)];
  };
};
// The JSON of every chart, read before knitr-inline.js hands it to maidr.js
// and takes it away.
const jsonScript = () => {
  window.__maidrSmokeJson = [];
  document.addEventListener('DOMContentLoaded', () => {
    for (const svg of document.querySelectorAll('svg[data-maidr-knitr]')) {
      window.__maidrSmokeJson.push(JSON.parse(svg.getAttribute('data-maidr-knitr')));
    }
  });
};

// The colours a reader sees around a chart: the page's body, and the
// nearest box from the chart's plot out to its wrapper that has a
// background of its own; null when none has.
const coloursScript = () => {
  window.__maidrSmokeColours = wrapper => {
    const body = getComputedStyle(document.body);
    const plot = wrapper.querySelector('figure[id^="maidr-figure"] > [tabindex="0"]');
    let backdrop = null;
    for (let at = plot; at && !backdrop; at = at === wrapper ? null : at.parentElement) {
      const colour = getComputedStyle(at).backgroundColor;
      if (colour !== 'transparent' && !/^rgba\(.*,\s*0\)$/.test(colour)) {
        backdrop = colour;
      }
    }
    return { body: [body.backgroundColor, body.color], backdrop };
  };
};
// A colour no channel of which is lighter than a quarter: maidr's default
// dark colour for high contrast is black.
const dark = colour => Boolean(colour)
  && Math.max(...colour.match(/[\d.]+/g).slice(0, 3).map(Number)) <= 64;
const sameColours = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const coloursOf = (page, selector) => page.evaluate(
  selector => window.__maidrSmokeColours(document.querySelector(selector)),
  selector,
);

const launch = {};
if (process.env.MAIDR_SMOKE_CHROMIUM) {
  launch.executablePath = process.env.MAIDR_SMOKE_CHROMIUM;
}
const browser = await chromium.launch(launch);

// Load one of the pages, once maidr.js has bound `charts` charts on it.
const open = async (name, charts, viewport) => {
  const page = await browser.newPage({ viewport });
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.addInitScript(coloursScript);
  await page.addInitScript(drawnScript);
  await page.addInitScript(placeScript);
  await page.addInitScript(jsonScript);
  await page.goto('file://' + path.resolve(dir, name), { waitUntil: 'load' });
  await page.waitForFunction(count => {
    const wrappers = document.querySelectorAll('.maidr-knitr');
    return wrappers.length === count
      && Array.from(wrappers).every(w => w.querySelector('article[id^="maidr-article-"]'));
  }, charts, { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(settle * 2);
  const bound = await page.evaluate(plotOf => document.querySelectorAll(`.maidr-knitr ${plotOf}`).length, plotOf);
  check(bound === charts, `${name}: maidr.js binds its ${charts} chart(s) (${bound})`);
  return { page, errors };
};

// --- A dashboard -------------------------------------------------------------

{
  const { page, errors } = await open('dash.html', 4, { width: 1200, height: 900 });
  const inCards = await page.evaluate(() => Array.from(
    document.querySelectorAll('.maidr-knitr'),
    wrapper => Boolean(wrapper.closest('.bslib-card')),
  ));
  check(
    inCards.length === 4 && inCards.every(Boolean),
    `dash.html: every chart is in a card (${JSON.stringify(inCards)})`,
  );
  // One card per chunk, titled by it: the title, and how many charts it holds.
  const cards = await page.evaluate(() => Array.from(
    document.querySelectorAll('.bslib-card'),
    card => {
      const title = card.querySelector('.card-title');
      return [title ? title.textContent.trim() : null, card.querySelectorAll('.maidr-knitr').length];
    },
  ));
  check(
    JSON.stringify(cards) === JSON.stringify([
      ['Cylinders', 1], ['Gears', 1], ['Picture', 0], ['Points', 1], ['Counts', 1],
    ]),
    `dash.html: each chunk's chart is in a card of its own, titled by the chunk (${JSON.stringify(cards)})`,
  );
  // The three cards of the first row are the same size, larger than a
  // 3 x 2 in figure: each chart is drawn as large as the picture, less the
  // line kept below it for maidr's text where the card's height is the
  // limit, or the room the card keeps for its scrollbar where its width is
  // -- none where the scrollbar takes none -- and centred across what the
  // card leaves it.
  const filled = await page.evaluate(() => {
    const measure = element => {
      const box = (element.closest('.maidr-knitr') || element).parentElement;
      const style = getComputedStyle(box);
      const rect = box.getBoundingClientRect();
      const left = rect.left + parseFloat(style.borderLeftWidth) + parseFloat(style.paddingLeft);
      const right = left + box.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
      const drawn = window.__maidrSmokeDrawn(element);
      return {
        ...drawn,
        gutter: box.offsetWidth - box.clientWidth
          - parseFloat(style.borderLeftWidth) - parseFloat(style.borderRightWidth),
        centred: Math.abs((drawn.left - left) - (right - drawn.left - drawn.width)) <= 1,
      };
    };
    const picture = document.querySelector('.card-body img');
    return {
      charts: Array.from(document.querySelectorAll('.maidr-knitr svg.maidr-knitr-svg'), svg => ({
        ...measure(svg),
        own: Number.parseFloat(svg.getAttribute('width')),
        line: parseFloat(getComputedStyle(svg.closest('.maidr-knitr')).lineHeight),
      })).slice(0, 2),
      picture: picture ? measure(picture) : null,
    };
  });
  check(
    filled.charts.length === 2 && filled.picture && filled.charts.every(chart => chart.centred
      && chart.width > chart.own + 10
      && chart.width <= filled.picture.width + 1 && chart.height <= filled.picture.height + 1
      && (near(chart.width, filled.picture.width - chart.gutter)
        || near(chart.height, filled.picture.height - chart.line))),
    'dash.html: each chart fills its card, centred, as the picture beside them fills its own,'
      + ` less a line or the scrollbar's room, larger than its own size (${JSON.stringify(filled)})`,
  );

  // The chart keeps its size and place in its card while the reader uses
  // it, in a card as tall as the first row's and in one too short for the
  // braille field, which the card scrolls into view.
  for (const [index, name] of [[0, 'Cylinders'], [3, 'Counts']]) {
    const place = () => page.evaluate(
      index => window.__maidrSmokePlace(document.querySelectorAll('.maidr-knitr svg.maidr-knitr-svg')[index]),
      index,
    );
    const plot = page.locator(`.maidr-knitr ${plotOf}`).nth(index);
    const places = { load: await place() };
    await plot.focus();
    await page.waitForTimeout(settle);
    places.focus = await place();
    await page.keyboard.press('ArrowRight');
    await page.waitForTimeout(settle);
    places.key = await place();
    await page.keyboard.press('b');
    await page.waitForTimeout(settle);
    places.braille = await place();
    const field = await page.evaluate(index => {
      const wrapper = document.querySelectorAll('.maidr-knitr')[index];
      const textarea = wrapper.querySelector('textarea[id^="maidr-braille-textarea"]');
      if (!textarea) {
        return null;
      }
      const box = wrapper.parentElement.getBoundingClientRect();
      const r = textarea.getBoundingClientRect();
      // A field taller than its card from its first line, where the braille is.
      return {
        focused: document.activeElement === textarea,
        inView: r.height > box.height
          ? Math.abs(r.top - box.top) <= 1
          : r.top >= box.top - 1 && r.bottom <= box.bottom + 1,
      };
    }, index);
    await page.keyboard.press('b');
    await page.waitForTimeout(settle);
    places.off = await place();
    await page.evaluate(() => document.activeElement.blur());
    await page.waitForTimeout(settle);
    places.blur = await place();
    const steady = Object.values(places).every(at => JSON.stringify(at) === JSON.stringify(places.load));
    check(
      steady && places.load[3] > 0 && field && field.focused && field.inView,
      `dash.html: the ${name} chart keeps its size and place in its card as the reader uses it,`
        + ` and its card scrolls the braille field into view (${JSON.stringify({ places, field })})`,
    );
  }
  check(
    await page.evaluate(() => {
      const box = document.querySelectorAll('.maidr-knitr')[3].parentElement;
      return box.clientHeight < 200;
    }),
    'dash.html: the Counts card is too short for the braille field below its chart',
  );

  // A pointer moved from point to point of the scatter plot, once the
  // reader has clicked into it, hears each point it is on: maidr.js
  // measures the points once, and the chart has not moved since.
  const pointAt = mark => page.evaluate(mark => {
    const svg = document.querySelectorAll('.maidr-knitr svg.maidr-knitr-svg')[2];
    const layer = window.__maidrSmokeJson[2].subplots[0][0].layers[0];
    const selector = Array.isArray(layer.selectors) ? layer.selectors[0] : layer.selectors;
    // Not the copies maidr.js draws its highlight with.
    const point = Array.from(svg.querySelectorAll(selector))
      .filter(element => !element.hasAttribute('data-maidr-owned'))[mark];
    const box = point.getBBox();
    const at = svg.createSVGPoint();
    at.x = box.x + box.width / 2;
    at.y = box.y + box.height / 2;
    const screen = at.matrixTransform(point.getScreenCTM());
    return [screen.x, screen.y];
  }, mark);
  const heard = () => page.evaluate(() => {
    const text = document.querySelectorAll('.maidr-knitr')[2].querySelector('[id^="maidr-text-container"]');
    return text ? text.textContent.trim() : '';
  });
  const pointed = [];
  const first = await pointAt(0);
  await page.mouse.click(first[0], first[1]);
  await page.waitForTimeout(settle);
  for (const mark of [1, 2, 0]) {
    const [x, y] = await pointAt(mark);
    await page.mouse.move(x, y, { steps: 5 });
    await page.waitForTimeout(settle);
    pointed.push(await heard());
  }
  await page.evaluate(() => document.activeElement.blur());
  await page.mouse.move(0, 0);
  check(
    /\b2\b.*\b12\b/.test(pointed[0]) && /\b3\b.*\b23\b/.test(pointed[1]) && /\b1\b.*\b31\b/.test(pointed[2]),
    `dash.html: a pointer moved over each point of a scatter plot clicked into hears that point (${JSON.stringify(pointed)})`,
  );

  const fullScreen = () => page.evaluate(
    () => document.querySelector('.maidr-knitr').closest('.bslib-card').getAttribute('data-full-screen'),
  );
  const showFullScreen = () => page.evaluate(() => {
    document.querySelector('.maidr-knitr').closest('.bslib-card')
      .querySelector('.bslib-full-screen-enter').click();
  });
  const helpOpen = () => page.evaluate(() => Boolean(document.querySelector('.maidr-knitr .MuiDialog-paper')));
  // Escape on the card's close button, which bslib shows while the card is
  // full screen: whether the card was full screen, and is not any more.
  const leaveByEscape = async () => {
    const shown = await page.evaluate(() => {
      const close = document.querySelector('.bslib-full-screen-exit');
      if (close) {
        close.focus();
      }
      return Boolean(close);
    });
    if (!shown) {
      return false;
    }
    await page.keyboard.press('Escape');
    await page.waitForTimeout(settle);
    return await fullScreen() === 'false';
  };

  // Shown full screen before the chart has the focus.
  await showFullScreen();
  await page.waitForTimeout(settle);
  check(await fullScreen() === 'true', 'dash.html: the first chart\'s card is shown full screen');
  // A card shown full screen is larger than the chart's own size, and the
  // chart grows with it, as an image does: as wide as the card's body, less
  // the room it keeps for its scrollbar, or as high, less the line kept for
  // maidr's text, and centred across it.
  const grown = await page.evaluate(() => {
    const svg = document.querySelector('.maidr-knitr svg.maidr-knitr-svg');
    const box = svg.closest('.maidr-knitr').parentElement;
    const style = getComputedStyle(box);
    const rect = box.getBoundingClientRect();
    const left = rect.left + parseFloat(style.borderLeftWidth) + parseFloat(style.paddingLeft);
    const width = box.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight);
    const height = box.clientHeight - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom);
    const drawn = window.__maidrSmokeDrawn(svg);
    return {
      drawn,
      box: [Math.round(width), Math.round(height)],
      line: parseFloat(getComputedStyle(svg.closest('.maidr-knitr')).lineHeight),
      own: Number.parseFloat(svg.getAttribute('width')),
      centred: Math.abs((drawn.left - left) - (left + width - drawn.left - drawn.width)) <= 2,
    };
  });
  check(
    (near(grown.drawn.width, grown.box[0], 2) || near(grown.drawn.height, grown.box[1] - grown.line, 2))
      && grown.drawn.width > grown.own && grown.centred,
    `dash.html: the chart grows to fill its card shown full screen, centred (${JSON.stringify(grown)})`,
  );
  await page.locator(`.maidr-knitr ${plotOf}`).first().focus();
  await page.waitForTimeout(settle);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(settle);
  check(await fullScreen() === 'true', 'dash.html: Escape pressed in the chart leaves its card full screen');
  await page.keyboard.press('Control+Slash');
  await page.waitForTimeout(settle * 2);
  const opened = await helpOpen();
  await page.keyboard.press('Escape');
  await page.waitForTimeout(settle);
  const state = { opened, closed: !(await helpOpen()), fullScreen: await fullScreen() };
  check(
    state.opened && state.closed && state.fullScreen === 'true',
    `dash.html: Escape closes maidr's help and leaves the card full screen (${JSON.stringify(state)})`,
  );
  check(
    await leaveByEscape(),
    'dash.html: Escape pressed in the card outside the chart takes the card back',
  );

  // Shown full screen while the chart has the focus.
  await page.locator(`.maidr-knitr ${plotOf}`).first().focus();
  await page.waitForTimeout(settle);
  await showFullScreen();
  await page.waitForTimeout(settle);
  await page.locator(`.maidr-knitr ${plotOf}`).first().focus();
  await page.keyboard.press('Escape');
  await page.waitForTimeout(settle);
  check(
    await fullScreen() === 'true',
    'dash.html: Escape pressed in the chart leaves its card full screen when it was shown full screen from the chart',
  );
  check(
    await leaveByEscape(),
    'dash.html: Escape pressed outside the chart then takes the card back',
  );

  // High contrast.
  const plain = await coloursOf(page, '.maidr-knitr');
  await page.locator(`.maidr-knitr ${plotOf}`).first().focus();
  await page.waitForTimeout(settle);
  await page.keyboard.press('c');
  await page.waitForTimeout(settle);
  const contrasted = await coloursOf(page, '.maidr-knitr');
  check(
    sameColours(contrasted.body, plain.body) && dark(contrasted.backdrop),
    'dash.html: high contrast paints the chart dark and leaves the page in its own colours'
      + ` (page ${contrasted.body.join(' on ')}, was ${plain.body.join(' on ')}; chart ${contrasted.backdrop})`,
  );
  await page.keyboard.press('c');
  await page.waitForTimeout(settle);
  const off = await coloursOf(page, '.maidr-knitr');
  check(
    sameColours(off.body, plain.body) && off.backdrop === plain.backdrop,
    `dash.html: high contrast turned off leaves nothing painted (page ${off.body.join(' on ')}; chart ${off.backdrop})`,
  );

  check(errors.length === 0, `dash.html: no page errors${errors.length ? ': ' + errors.join(' | ') : ''}`);
  await page.close();
}

// --- A reveal.js deck ---------------------------------------------------------

{
  const { page, errors } = await open('deck.html', 4, { width: 1600, height: 900 });
  const slideNow = () => page.evaluate(() => window.Reveal.getIndices().h);
  // What reveal.js reads aloud as the slide shown: its text, all but what
  // is hidden.
  const announced = () => page.evaluate(() => document.querySelector('.reveal .aria-status').textContent);
  const quiet = (slide, text, labels) => check(
    labels.every(label => !text.includes(label)),
    `deck.html: showing the ${slide} reads none of its chart's tick labels ("${text.trim()}")`,
  );
  await page.evaluate(() => window.Reveal.slide(1));
  await page.waitForTimeout(settle * 2);
  quiet('slide of a chart', await announced(), ['slide1', 'slide2', 'slide3']);
  const chart = page.locator(`#a-chart .maidr-knitr ${plotOf}`);
  await chart.focus();
  await page.waitForTimeout(settle);
  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(settle);
  const read = await page.evaluate(() => {
    const text = document.querySelector('#a-chart #maidr-text-container');
    return text ? text.textContent.trim() : '';
  });
  check(
    await slideNow() === 1 && /\bslide1\b/.test(read),
    `deck.html: Right Arrow in a chart is maidr's, and leaves the slide where it is ("${read}")`,
  );

  // The search box the plugin shows: none until it is first opened.
  const searchShown = () => page.evaluate(() => {
    const box = document.querySelector('.reveal .searchbox');
    return box ? getComputedStyle(box).display : 'none';
  });
  // Shut it, as the plugin does, should a check have opened it, so that one
  // failure does not fail the checks after it.
  const shutSearch = () => page.evaluate(() => {
    const box = document.querySelector('.reveal .searchbox');
    if (box) {
      box.style.display = 'none';
    }
  });
  await page.keyboard.press('Control+Shift+F');
  await page.waitForTimeout(settle);
  const search = await searchShown();
  check(search === 'none', `deck.html: Ctrl+Shift+F in a chart leaves the deck's search shut (${search})`);
  await shutSearch();
  await chart.focus();
  await page.waitForTimeout(settle);
  // Ctrl+F, reported as a capital F as with Caps Lock on: the plugin opens
  // on it all the same.
  await page.keyboard.press('Control+F');
  await page.waitForTimeout(settle);
  const capsSearch = await searchShown();
  check(
    capsSearch === 'none',
    `deck.html: Ctrl+F reported as a capital F in a chart leaves the deck's search shut (${capsSearch})`,
  );
  await shutSearch();

  // Recorded as a shortcut of maidr's in its settings, from the chart: the
  // recorder, a React handler inside the chart, has the key, and the deck's
  // search stays shut while it does and when it is pressed in the dialog
  // again, with nothing recording it.
  await chart.focus();
  await page.waitForTimeout(settle);
  await page.keyboard.press('Control+Comma');
  const recording = { recorded: null, searchWhile: null, searchAfter: null };
  try {
    await page.getByRole('tab', { name: 'Keyboard Shortcuts' }).click({ timeout: 5000 });
    await page.getByRole('button', { name: 'Change shortcut for Toggle Text Mode' }).click({ timeout: 5000 });
    await page.keyboard.press('Control+Shift+F');
    const status = page.locator('.settings-shortcuts [role="status"]').filter({ hasText: 'Toggle Text Mode is now' });
    await status.waitFor({ timeout: 5000 });
    recording.recorded = (await status.innerText()).trim();
  } catch (error) {
    recording.recorded = null;
  }
  await page.waitForTimeout(settle);
  recording.searchWhile = await searchShown();
  await page.keyboard.press('Control+Shift+F');
  await page.waitForTimeout(settle);
  recording.searchAfter = await searchShown();
  check(
    /shift/i.test(recording.recorded || '') && recording.searchWhile === 'none' && recording.searchAfter === 'none',
    'deck.html: Ctrl+Shift+F is recorded as a shortcut in maidr\'s settings, and the deck\'s search stays shut'
      + ` (${JSON.stringify(recording)})`,
  );
  await shutSearch();
  // Closed, whether the recorder still waits for a key or not.
  const dialogOpen = () => page.evaluate(() => Boolean(document.querySelector('#a-chart .MuiDialog-paper')));
  for (let tries = 0; tries < 3 && await dialogOpen(); tries++) {
    await page.keyboard.press('Escape');
    await page.waitForTimeout(settle);
  }

  await chart.focus();
  await page.waitForTimeout(settle);
  await page.keyboard.press('Control+Slash');
  await page.waitForTimeout(settle * 2);
  const help = await page.evaluate(() => {
    const paper = document.querySelector('#a-chart .MuiDialog-paper');
    const slides = document.querySelector('.reveal .slides');
    if (!paper) {
      return null;
    }
    const box = paper.getBoundingClientRect();
    return {
      top: Math.round(box.top),
      bottom: Math.round(box.bottom),
      height: window.innerHeight,
      scale: Math.round(slides.getBoundingClientRect().width / slides.offsetWidth * 100) / 100,
    };
  });
  check(
    help !== null && help.scale > 1 && help.top >= 0 && help.bottom <= help.height,
    'deck.html: maidr\'s help stays within the window on a slide scaled up'
      + (help ? ` (${help.top}-${help.bottom} of ${help.height}, slides scaled ${help.scale})` : ': not opened'),
  );
  await page.keyboard.press('Escape');
  await page.waitForTimeout(settle);

  // The link before the chart, which a reader cannot tab to, is no tab
  // stop to leave the chart for.
  const passedOver = await page.evaluate(() => Array.from(
    document.querySelectorAll('#a-chart a[href][tabindex="-1"]'),
  ).some(link => link.textContent.trim() === 'The end' && !link.closest('[aria-hidden="true"]')));
  await chart.focus();
  await page.waitForTimeout(settle);
  await page.keyboard.press('Shift+Tab');
  await page.waitForTimeout(settle);
  const landed = await page.evaluate(() => {
    const active = document.activeElement;
    return active.matches('section#a-chart') ? 'the slide' : active.tagName.toLowerCase();
  });
  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(settle * 2);
  const after = await slideNow();
  check(
    passedOver && landed === 'the slide' && after === 2,
    'deck.html: Shift+Tab from the chart, past a link out of the tab order'
      + `${passedOver ? '' : ' (not on the slide)'}, puts the focus on its slide (${landed}),`
      + ` where Right Arrow moves the deck on (slide ${after})`,
  );
  quiet('slide of a figure', await announced(), ['gear3', 'gear4', 'gear5']);

  // Out of the charts the deck's search is the deck's: each key the checks
  // above press in a chart opens it, and shuts it again, so it is held off
  // there and not lost.
  await page.evaluate(() => document.activeElement.blur());
  for (const key of ['Control+Shift+F', 'Control+F']) {
    await page.keyboard.press(key);
    await page.waitForTimeout(settle);
    const opened = await searchShown();
    await page.keyboard.press(key);
    await page.waitForTimeout(settle);
    const shut = await searchShown();
    check(
      opened !== 'none' && shut === 'none',
      `deck.html: ${key} out of a chart opens the deck's search and shuts it again (${opened}, then ${shut})`,
    );
  }

  // The 4 x 3 in chart alone on its slide is stretched as Quarto stretches
  // the 4 x 3 in picture alone on another, both below a line of text:
  // larger than its own size, and as large, less no more than the room
  // maidr's instructions, text and braille and review fields take below it
  // as the reader uses the chart, which they take on the slide, the chart
  // keeping its size and place. A slide's pixels, which reveal.js scales.
  const slideState = () => page.evaluate(() => {
    const scale = window.Reveal.getScale();
    const deck = document.querySelector('.reveal .slides').getBoundingClientRect();
    const foot = deck.top + window.Reveal.getConfig().height * scale;
    const element = window.Reveal.getCurrentSlide().querySelector('svg.maidr-knitr-svg, img');
    const wrapper = element.closest('.maidr-knitr');
    const rect = element.getBoundingClientRect();
    let lowest = 0;
    for (const selector of ['[id^="maidr-text-container"]', 'textarea[id^="maidr-braille-textarea"]',
      'input[id^="maidr-review-input"]']) {
      const shown = wrapper && wrapper.querySelector(selector);
      const box = shown && shown.getBoundingClientRect();
      if (box && box.height) {
        lowest = Math.max(lowest, box.bottom);
      }
    }
    const unit = value => Math.round(value / scale * 10) / 10;
    const drawn = window.__maidrSmokeDrawn(element);
    return {
      width: unit(drawn.width),
      height: unit(drawn.height),
      box: [rect.left, rect.top, rect.width, rect.height].map(unit),
      own: wrapper ? Number.parseFloat(element.getAttribute('width')) : null,
      below: lowest ? unit(lowest - rect.bottom) : 0,
      past: lowest ? unit(lowest - foot) : 0,
    };
  });
  await page.evaluate(() => window.Reveal.slide(3));
  await page.waitForTimeout(settle);
  const stretchedPicture = await slideState();
  await page.evaluate(() => window.Reveal.slide(1));
  await page.waitForTimeout(settle);
  const states = { load: await slideState() };
  await chart.focus();
  await page.waitForTimeout(settle);
  states.focus = await slideState();
  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(settle);
  states.key = await slideState();
  await page.keyboard.press('b');
  await page.waitForTimeout(settle);
  states.braille = await slideState();
  await page.keyboard.press('b');
  await page.waitForTimeout(settle);
  await chart.focus();
  await page.keyboard.press('r');
  await page.waitForTimeout(settle);
  states.review = await slideState();
  await page.keyboard.press('r');
  await page.waitForTimeout(settle);
  await page.evaluate(() => document.activeElement.blur());
  await page.waitForTimeout(settle);
  states.blur = await slideState();
  const stretchedChart = states.load;
  const all = Object.values(states);
  const room = Math.max(...all.map(state => state.below));
  check(
    stretchedChart.width > stretchedChart.own + 10
      && stretchedChart.height <= stretchedPicture.height + 1
      && stretchedChart.height >= stretchedPicture.height - room - 1
      && Math.abs(stretchedChart.width / stretchedChart.height - 4 / 3) < 0.01,
    'deck.html: the chart alone on its slide is stretched as the picture alone on another is, less no more'
      + ` than the room maidr's text takes below it (${JSON.stringify(stretchedChart)} and`
      + ` ${JSON.stringify(stretchedPicture)}; ${room} below)`,
  );
  check(
    all.every(state => JSON.stringify(state.box) === JSON.stringify(stretchedChart.box))
      && states.focus.below > 0 && states.braille.below > states.key.below && states.review.below > 0
      && all.every(state => state.past <= 1),
    'deck.html: the stretched chart keeps its size and place as the reader uses it, and maidr\'s'
      + ` instructions, text and braille and review fields stay on the slide (${JSON.stringify(states)})`,
  );

  // Quarto stretches no picture on a slide marked .nostretch or in a
  // column, and no chart is stretched there either: each keeps its size.
  for (const [index, where] of [[5, 'a slide marked .nostretch'], [6, 'a column']]) {
    await page.evaluate(i => window.Reveal.slide(i), index);
    await page.waitForTimeout(settle);
    const kept = await slideState();
    check(
      kept.own !== null && Math.abs(kept.width - kept.own) <= 1,
      `deck.html: the chart on ${where} keeps its own size, as Quarto stretches no picture there`
        + ` (${JSON.stringify(kept)})`,
    );
  }

  check(errors.length === 0, `deck.html: no page errors${errors.length ? ': ' + errors.join(' | ') : ''}`);
  await page.close();
}

// --- A Quarto figure -----------------------------------------------------------

{
  const { page, errors } = await open('fig.html', 3, { width: 1200, height: 900 });
  const gaps = await page.evaluate(() => {
    const svg = document.querySelector('.maidr-knitr svg').getBoundingClientRect();
    const figure = document.querySelector('.maidr-knitr').closest('figure').getBoundingClientRect();
    return { left: Math.round(svg.left - figure.left), right: Math.round(figure.right - svg.right) };
  });
  check(
    gaps.left > 10 && Math.abs(gaps.left - gaps.right) <= 2,
    `fig.html: the chart stands in the middle of its figure (${gaps.left}px to its left, ${gaps.right}px to its right)`,
  );
  // Quarto shows a 7 x 5 in figure at fig-dpi, 96 pixels to the inch, and
  // one given out-width: 100% as wide as the column.
  const sizes = await page.evaluate(() => {
    const charts = document.querySelectorAll('.maidr-knitr svg.maidr-knitr-svg');
    const drawn = element => (element ? window.__maidrSmokeDrawn(element) : null);
    return {
      chart: drawn(charts[1]),
      picture: drawn(document.querySelector('img[alt="A plain grey circle"]')),
      wideChart: drawn(charts[2]),
      widePicture: drawn(document.querySelector('img[alt="A wide grey circle"]')),
    };
  });
  check(
    sameSize(sizes.chart, sizes.picture) && sizes.chart.width === 672 && sizes.chart.left === sizes.picture.left,
    `fig.html: a 7 x 5 in chart is shown as large as a 7 x 5 in picture, where it is (${JSON.stringify(sizes.chart)}`
      + ` and ${JSON.stringify(sizes.picture)})`,
  );
  check(
    sameSize(sizes.wideChart, sizes.widePicture) && sizes.wideChart.width > 672,
    'fig.html: a chart given out-width: 100% is as wide as a picture given it, wider than its own size'
      + ` (${JSON.stringify(sizes.wideChart)} and ${JSON.stringify(sizes.widePicture)})`,
  );
  check(errors.length === 0, `fig.html: no page errors${errors.length ? ': ' + errors.join(' | ') : ''}`);
  await page.close();
}

await browser.close();
if (failures.length > 0) {
  console.error(`${failures.length} check(s) failed`);
  process.exit(1);
}
console.log('the R charts of every Quarto page are used from the keyboard as on any other');
