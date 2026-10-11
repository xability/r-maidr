/* maidr knitr-inline: the charts r-maidr writes inline into a knitted HTML
 * page (R Markdown, Quarto, bookdown, slide decks, dashboards).
 *
 * Each chart is an <svg data-maidr-knitr="{json}"> inside a .maidr-knitr
 * wrapper. The JSON is not in a maidr-data attribute, because maidr.js scans
 * the page for [maidr-data] when it starts and, on finding one, does not look
 * for plotly charts: a maidr_htmlwidget(plotly) elsewhere in the document
 * would lose its binding. This script hands each chart to maidr.js once,
 * through maidr:bindchart, as the widget binding does, and removes the
 * attribute again.
 *
 * It also keeps the host page's keyboard shortcuts away from a chart while
 * the focus is in one. A chart in an iframe had its keys to itself; inline,
 * a slide deck's arrow keys, a book's page keys and a site's search key
 * would otherwise act on the same key presses maidr navigates with. Every
 * shim only acts while the focus is inside a chart, so the page's own keys
 * work everywhere else. High contrast, which painted the frame, paints the
 * chart, not the page around it. */
(function () {
  'use strict';
  if (window.__maidrKnitr) return;
  window.__maidrKnitr = true;

  var PENDING = 'data-maidr-knitr';
  // An inline chart, or a widget maidr mounted on the same page.
  var CHART = '.maidr-knitr, article[id^="maidr-article-"]';
  // The element maidr makes focusable around the chart.
  var PLOT = '.maidr-knitr figure[id^="maidr-figure"] > [tabindex]';

  function inChart(node) {
    return !!(node && node.closest && node.closest(CHART));
  }

  function focusInChart() {
    return inChart(document.activeElement);
  }

  // The element that stands for a chart's frame: an inline chart's wrapper,
  // or the element maidr mounted a widget in.
  function paintTarget(node) {
    if (!node || !node.closest) return null;
    return node.closest('.maidr-knitr') || node.closest('article[id^="maidr-article-"]');
  }

  // maidr.js finds maidr-math.css beside its own <script src>. Inlined into a
  // self-contained page, or moved by bookdown, it cannot, so it is pointed at
  // the copy the page declares as an attachment of the maidr dependency.
  function pointAtMathStylesheet() {
    var math = document.getElementById('maidr-math-attachment');
    if (math && math.href && !window.maidrMathStylesheetUrl) {
      window.maidrMathStylesheetUrl = math.href;
    }
  }

  // maidr.js replaces the svg with its own tree at once, and React mounts that
  // tree a moment later. Should the mount fail, React unmounts the tree, and
  // the svg goes with it. So the svg keeps its static name until maidr's
  // focusable element is really around it, and is put back if it was lost:
  // the reader keeps a named picture rather than nothing. Once it is around
  // it, maidr names that element, and the drawing is hidden: reveal.js reads
  // a slide's text aloud when it is shown, all but what is hidden, and a
  // chart's tick labels are text.
  function verifyMounted(svg, wrapper, attempt) {
    if (svg.isConnected && svg.closest('figure[id^="maidr-figure"] > [tabindex]')) {
      svg.removeAttribute('role');
      svg.removeAttribute('aria-label');
      svg.removeAttribute('aria-labelledby');
      svg.setAttribute('aria-hidden', 'true');
      describeAll();
      if (wrapper) {
        fitChart(wrapper);
        stretchChart(wrapper);
        fitIoslide(wrapper);
      }
      return;
    }
    if (attempt < 40) {
      setTimeout(function () { verifyMounted(svg, wrapper, attempt + 1); }, 50);
      return;
    }
    if (!svg.isConnected && wrapper && wrapper.isConnected) {
      var emptied = null;
      for (var i = 0; i < wrapper.children.length; i++) {
        var child = wrapper.children[i];
        if (child.tagName === 'DIV' && child.style.display === 'contents' && !child.firstChild) {
          emptied = child;
          break;
        }
      }
      if (emptied) {
        wrapper.replaceChild(svg, emptied);
      } else {
        wrapper.insertBefore(svg, wrapper.firstChild);
      }
    }
  }

  function bindCharts() {
    // maidr.js has not run yet, or was not loaded: the charts stay named
    // pictures until it has.
    if (!window.maidrLive) return;
    var charts = document.querySelectorAll('svg[' + PENDING + ']');
    for (var i = 0; i < charts.length; i++) {
      var svg = charts[i];
      var wrapper = svg.parentNode;
      if (wrapper && wrapper.classList && wrapper.classList.contains('maidr-knitr')) {
        keepSlashFromPage(wrapper);
        sizeDialogs(wrapper);
      }
      var json = svg.getAttribute(PENDING);
      svg.removeAttribute(PENDING);
      svg.setAttribute('maidr-data', json);
      try {
        svg.dispatchEvent(new CustomEvent('maidr:bindchart', { bubbles: true }));
      } finally {
        // maidr.js must never find it when it scans the page itself.
        svg.removeAttribute('maidr-data');
      }
      if (svg.hasAttribute('data-maidr-value')) verifyMounted(svg, wrapper, 0);
    }
  }

  // Once maidr has mounted a chart, its focusable element is named by maidr,
  // and the author's alt text and caption would be lost. They become its
  // description: the hidden alt text r-maidr writes, then the caption --
  // r-maidr's own, or the figcaption of a Quarto figure, which Quarto names
  // in an aria-describedby on the figure's content.
  //
  // maidr.js describes the element too, by its keyboard instructions, under
  // ids that start with maidr-instruction- (xability/maidr#1384). Those are
  // kept, after the author's: a reader hears what the chart shows before how
  // to use it, and maidr adds and takes away its own as the reader enters and
  // uses the chart.
  var MAIDR_INSTRUCTION = 'maidr-instruction-';

  function describe(plot) {
    var wrapper = plot.closest('.maidr-knitr');
    if (!wrapper) return;
    keepFromSlidy(plot);
    var ids = [];
    var alt = wrapper.querySelector(':scope > .maidr-knitr-alt[id]');
    if (alt) ids.push(alt.id);
    var caption = wrapper.querySelector(':scope > .maidr-knitr-caption[id]');
    var host = wrapper.parentNode && wrapper.parentNode.closest('[aria-describedby]');
    if (caption) {
      ids.push(caption.id);
    } else if (host && !inChart(host)) {
      ids.push(host.getAttribute('aria-describedby'));
    }
    if (!ids.length) return;
    var current = plot.getAttribute('aria-describedby') || '';
    var maidrIds = current.split(/\s+/).filter(function (id) {
      return id.indexOf(MAIDR_INSTRUCTION) === 0;
    });
    var value = ids.concat(maidrIds).join(' ');
    if (current !== value) {
      plot.setAttribute('aria-describedby', value);
    }
  }

  function describeAll() {
    var plots = document.querySelectorAll(PLOT);
    for (var i = 0; i < plots.length; i++) describe(plots[i]);
  }

  // --- maidr's dialogs -------------------------------------------------------

  // Text of maidr's dialogs that MUI sizes from its theme: 1rem under MUI's
  // default theme, or 0.875rem for body2. Every dialog holds some.
  var DIALOG_TEXT = '[role="dialog"] .MuiTypography-body1, [role="dialog"] .MuiTypography-body2, ' +
    '[role="dialog"] .MuiInputBase-root';

  // The font size an element with these classes, or this font size of its
  // own, comes out at outside the page's content: read off a probe at the
  // root, never shown, where maidr.js reads the reader's default font size.
  // There a rule of the page for the element a text is (a book's for p) or
  // for the place it is in (a deck's for its slides) does not change the
  // size maidr's theme gives it.
  function probeFontSize(className, fontSize) {
    var probe = document.createElement('maidr-knitr-probe');
    probe.className = className;
    probe.style.setProperty('display', 'none', 'important');
    if (fontSize) probe.style.setProperty('font-size', fontSize, 'important');
    document.documentElement.appendChild(probe);
    try {
      return parseFloat(getComputedStyle(probe).fontSize);
    } finally {
      probe.remove();
    }
  }

  // maidr opens its dialogs inside the chart, so they take the page's sizes:
  // a slide deck that zooms its slides (reveal.js on a large window) zooms
  // them past the window, and their text is in rem, which a Bootstrap 3 page
  // (html_document's default theme, bookdown's gitbook) makes 10px rather
  // than the reader's default font size, unless maidr.js sizes its text for
  // the page's root itself. So the text is measured once a dialog is shown,
  // and only what it lacks is made up. Each chart's wrapper carries, for the
  // stylesheet to apply, the zoom that undoes the page's, the size one rem
  // of MUI's default theme came out at in the chart's dialog, and the zoom
  // that brings that to the reader's default, as on a page that leaves its
  // root alone: none when maidr.js sized the text itself.
  function sizeDialogs(wrapper) {
    var host = 1;
    for (var node = wrapper.parentElement; node; node = node.parentElement) {
      var z = parseFloat(getComputedStyle(node).zoom);
      if (z > 0) host *= z;
    }
    wrapper.style.setProperty('--maidr-knitr-unzoom', String(1 / host));
    var text = wrapper.querySelector(DIALOG_TEXT);
    if (!text) return;
    var size = text.classList.contains('MuiTypography-body2') ? 0.875 : 1;
    // To a hundredth of a pixel, so that text maidr.js sized for the page is
    // never zoomed by a rounding error.
    var rem = Math.round(probeFontSize(text.className) / size * 100) / 100;
    var medium = probeFontSize('', 'medium');
    if (!(rem > 0) || !(medium > 0)) return;
    wrapper.style.setProperty('--maidr-knitr-rem', rem + 'px');
    wrapper.style.setProperty('--maidr-knitr-zoom', String(rem < medium ? medium / rem : 1));
  }

  function sizeAllDialogs() {
    var wrappers = document.querySelectorAll('.maidr-knitr');
    for (var i = 0; i < wrappers.length; i++) sizeDialogs(wrappers[i]);
  }

  // pkgdown takes / for its search box from anywhere on the page, and stops
  // it being typed: on a page with pkgdown's search box, a / typed into
  // maidr's own fields (the command palette, the chat) is kept from the
  // page. maidr's handlers, below the wrapper, still see it. Not one typed
  // in braille or review mode: maidr reads the keys of those fields from the
  // document, where / resets the autoplay speed, and shimPkgdownSearch()
  // keeps pkgdown's box from taking the focus from them.
  var MODE_FIELD = 'textarea[id^="maidr-braille-textarea"], input[id^="maidr-review-input"]';

  function keepSlashFromPage(wrapper) {
    if (wrapper.__maidrKnitrSlash) return;
    wrapper.__maidrKnitrSlash = true;
    wrapper.addEventListener('keydown', function (event) {
      if (event.key !== '/' || !document.getElementById('search-input')) return;
      var target = event.target;
      var editable = target && (target.isContentEditable ||
        (target.matches && target.matches('input, textarea, select')));
      if (editable && !target.matches(MODE_FIELD)) event.stopPropagation();
    });
  }

  // --- Dashboards ----------------------------------------------------------

  // flexdashboard sizes each box to the window (.chart-shim). A chart taller
  // than its box is shrunk to it, keeping its shape and a line for maidr's
  // text below it. Whether a box is sized by the window or by its content
  // cannot be read from it (a scrolling dashboard, a phone-width one), so a
  // chart is only shrunk when its box is overflowing: a box sized by its
  // content never is.
  var FITTED = '.chart-shim > .maidr-knitr';
  // A Quarto dashboard's cards, and any other bslib fill item.
  var FILLED = '.html-fill-container > .maidr-knitr.html-fill-item';

  // The width r-maidr gave a chart for its out.height, or ''.
  function heightWidth(svg) {
    if (svg.__maidrKnitrWidth === undefined) svg.__maidrKnitrWidth = svg.style.width;
    return svg.__maidrKnitrWidth;
  }

  function fitChart(wrapper) {
    if (wrapper.matches(FILLED)) {
      fillChart(wrapper);
      return;
    }
    var box = wrapper.parentElement;
    // Not there while maidr mounts the chart, which fits it once mounted.
    var svg = wrapper.querySelector('svg.maidr-knitr-svg');
    if (!box || !svg || !wrapper.matches(FITTED)) return;
    svg.style.maxHeight = '';
    svg.style.width = heightWidth(svg);
    var over = box.scrollHeight - box.clientHeight;
    if (over <= 1) return;
    var line = 2.5 * parseFloat(getComputedStyle(wrapper).fontSize);
    var height = svg.getBoundingClientRect().height - over - line;
    svg.style.width = 'auto';
    svg.style.maxHeight = Math.max(height, 96) + 'px';
  }

  // The height of a line of maidr's text, which takes the wrapper's.
  function textLine(wrapper) {
    var style = getComputedStyle(wrapper);
    var line = parseFloat(style.lineHeight);
    return line > 0 ? line : 1.5 * parseFloat(style.fontSize);
  }

  // A Quarto dashboard shows an image in a card as large as the card's body
  // holds it, keeping its shape, centred in it (.quarto-dashboard-img-contain:
  // width and height 100%, object-fit: contain); and as wide as the card
  // where the card takes its height from what it holds: a flow or scrolling
  // layout, a phone's. A chart is given the same size and place, less a line
  // kept below it for the text maidr shows there, but is not made shorter
  // than an inch for that line unless the card is. A chart given an
  // out.height keeps the size r-maidr gave it.
  //
  // The size is the card's, never what maidr's text, braille and review
  // fields leave of it: a chart that changed size as they came and went
  // would jump under the reader's eyes, and maidr.js would hover its marks
  // where they were before, since it measures them once the reader is in
  // the chart and again only when the window scrolls or resizes. What does
  // not fit below the chart scrolls the card (knitr-inline.css).
  function fillChart(wrapper) {
    var box = wrapper.parentElement;
    var svg = wrapper.querySelector('svg.maidr-knitr-svg');
    var view = svg && svg.viewBox && svg.viewBox.baseVal;
    if (!box || !view || !(view.width > 0) || !(view.height > 0) || heightWidth(svg)) return;
    // A card not shown, as a tab not chosen, is filled when it is.
    if (!box.clientWidth) return;
    var size = svg.style;
    var place = wrapper.style;
    // Where the box and the page around it are scrolled to: a box measured
    // empty can be shorter than the scroll it had.
    var scrolled = [];
    for (var node = box; node; node = node.parentElement) {
      if (node.scrollTop) scrolled.push([node, node.scrollTop]);
    }
    size.width = '0px';
    size.height = '0px';
    place.paddingTop = '';
    // The height the card gives the box, whatever the chart and maidr's
    // fields below it take: a card that sizes the box keeps it whatever the
    // box holds; one that takes it from what the box holds has none to
    // give but a least height of its own (a row of a scrolling layout).
    place.height = '4000px';
    var tall = box.clientHeight;
    place.height = '0px';
    var least = box.clientHeight;
    place.height = '';
    var sized = Math.abs(tall - least) < 1;
    // Only a card that sizes the box scrolls to maidr's fields, and keeps
    // the room for its scrollbar (knitr-inline.css).
    wrapper.classList.toggle('maidr-knitr-filled', sized);
    var style = getComputedStyle(box);
    // As wide as the wrapper, which an out.width can make narrower than
    // the card.
    var width = wrapper.clientWidth;
    var inner = least - parseFloat(style.paddingTop) - parseFloat(style.paddingBottom);
    var room = inner - textLine(wrapper);
    var scale = width / view.width;
    if (sized) scale = Math.min(scale, Math.max(room, Math.min(inner, 96)) / view.height);
    var height = view.height * scale;
    size.width = view.width * scale + 'px';
    size.height = height + 'px';
    // Centred down the card, with the line for maidr's text below it.
    if (room > height) place.paddingTop = (room - height) / 2 + 'px';
    for (var i = 0; i < scrolled.length; i++) scrolled[i][0].scrollTop = scrolled[i][1];
  }

  // A box is fitted in the frame after it resized: fitting it in the
  // observer's callback would resize the box it observes in the same frame,
  // which the browser reports as an error.
  function fitLater(wrapper) {
    if (wrapper.__maidrKnitrFit) return;
    wrapper.__maidrKnitrFit = true;
    requestAnimationFrame(function () {
      wrapper.__maidrKnitrFit = false;
      fitChart(wrapper);
    });
  }

  function fitCharts() {
    var wrappers = document.querySelectorAll(FITTED + ', ' + FILLED);
    if (!wrappers.length) return;
    var observer = window.ResizeObserver && new ResizeObserver(function (entries) {
      for (var i = 0; i < entries.length; i++) {
        var wrapper = entries[i].target.querySelector(':scope > .maidr-knitr');
        if (wrapper) fitLater(wrapper);
      }
    });
    for (var i = 0; i < wrappers.length; i++) {
      fitChart(wrappers[i]);
      if (observer) observer.observe(wrappers[i].parentElement);
    }
  }

  // maidr's braille and review fields open below a chart that fills its
  // card, where the card scrolls to them. The browser scrolls a field into
  // view as it takes the focus only when the field is out of view then,
  // and leaves one that is partly in view, as a field that opens at the
  // card's edge is, partly out of it. A field taller than the card is
  // shown from its first line, where maidr writes the braille.
  function keepInView(target) {
    if (!target.matches(MODE_FIELD)) return;
    var wrapper = target.closest(FILLED);
    if (!wrapper || !wrapper.classList.contains('maidr-knitr-filled')) return;
    requestAnimationFrame(function () {
      if (document.activeElement !== target) return;
      var box = wrapper.parentElement;
      var field = target.getBoundingClientRect();
      var top = box.getBoundingClientRect().top + box.clientTop;
      var bottom = top + box.clientHeight;
      if (field.top < top || field.height > box.clientHeight) {
        box.scrollTop += field.top - top;
      } else if (field.bottom > bottom) {
        box.scrollTop += field.bottom - bottom;
      }
    });
  }

  // --- Slides --------------------------------------------------------------

  // A slide is as high as its deck makes it, and what runs past its foot is
  // not seen: reveal.js and ioslides clip it, or the window does. A chart
  // made as large as a slide allows keeps below it the room for what maidr
  // shows there as the reader uses it -- the instructions it gives as they
  // enter the chart, the line of text above its braille field and the
  // field, or above its review field -- whichever is the tallest. That room
  // is kept whether or not they are shown: a chart that changed size as
  // they came and went would jump under the reader's eyes, and maidr.js
  // would hover its marks where they were before, since it measures them
  // once the reader is in the chart and again only when the window scrolls
  // or resizes.
  var BRAILLE_ROWS = 5;

  // A block laid out as maidr lays out its text below a chart, the page's
  // rules for it included, out of sight: a paragraph of `text` in a text
  // container, and a braille field after it if asked for.
  function textProbe(wrapper, text, braille) {
    var probe = document.createElement('div');
    probe.setAttribute('aria-hidden', 'true');
    probe.style.cssText = 'position: absolute; visibility: hidden; display: flow-root; ' +
      'left: 0; top: 0; width: ' + wrapper.clientWidth + 'px;';
    var container = document.createElement('div');
    container.id = 'maidr-text-container-knitr-probe';
    var paragraph = document.createElement('p');
    paragraph.textContent = text;
    container.appendChild(paragraph);
    probe.appendChild(container);
    if (braille) {
      var field = document.createElement('textarea');
      field.rows = BRAILLE_ROWS;
      field.setAttribute('wrap', 'off');
      field.tabIndex = -1;
      probe.appendChild(field);
    }
    wrapper.appendChild(probe);
    try {
      return probe.offsetHeight;
    } finally {
      probe.remove();
    }
  }

  function textRoom(wrapper) {
    // maidr names the chart by its instructions until the reader moves in
    // it, and they are as long as the instructions it shows; three lines
    // where they are not known.
    var plot = wrapper.querySelector('figure[id^="maidr-figure"] > [tabindex]');
    var label = plot && plot.getAttribute('aria-label');
    if (label && wrapper.__maidrKnitrInstructions === undefined) {
      wrapper.__maidrKnitrInstructions = label;
    }
    var instructions = wrapper.__maidrKnitrInstructions;
    var shown = instructions ? textProbe(wrapper, instructions, false) : 3 * textLine(wrapper);
    return Math.max(shown, textProbe(wrapper, 'M', true));
  }

  // The room a chart has on a slide as high as `height`: what the rest of
  // the slide leaves of it, as reveal.js measures the room of an .r-stretch
  // element, less the room for maidr's text. The chart's wrapper is
  // measured empty, so that what maidr shows below the chart takes none of
  // the room, whether it is shown or not; the margin below the wrapper,
  // which that text meets, is left to the slide's padding.
  function slideRoom(wrapper, slide, height) {
    var place = wrapper.style;
    var own = slide.style.height;
    place.height = '0px';
    slide.style.height = 'auto';
    var room = height - slide.offsetHeight;
    slide.style.height = own;
    place.height = '';
    var margin = parseFloat(getComputedStyle(wrapper).marginBottom) || 0;
    return room + margin - textRoom(wrapper);
  }

  // Quarto stretches the one image of a slide to the room left on it
  // (auto-stretch, reveal.js's .r-stretch): as large as fits the slide's
  // width and the height its other content leaves, keeping its shape. A
  // chart is an svg, not an image, so r-maidr marks each chart Quarto would
  // stretch were it one (maidr-knitr-stretch: in a deck that keeps
  // auto-stretch, not given a height), and it is stretched here on the
  // terms Quarto stretches an image on, less the room for the text maidr
  // shows below it. Not in reveal.js's scroll view, a phone's, where
  // reveal.js's own stretch leaves an image no room at all and the page
  // scrolls: the chart keeps its size there.
  var STRETCH = '.reveal .slides section .maidr-knitr.maidr-knitr-stretch';
  // What Quarto leaves an image in unstretched.
  var NO_STRETCH = '.column, .quarto-layout-panel, .fragment, .output-location-slide, [class*="panel-"]';

  // The slide the chart stands alone on, as Quarto's applyStretch() finds an
  // image to stretch, or null.
  function stretchSlide(wrapper) {
    var slide = wrapper.closest('section.slide, .slides > section, .slides > section > section');
    if (!slide || slide.classList.contains('nostretch')) return null;
    if (slide.querySelector('img') || slide.querySelectorAll('.maidr-knitr').length !== 1 ||
        slide.querySelector('aside:not(.notes)')) {
      return null;
    }
    var top = wrapper;
    for (; top.parentElement && top.parentElement !== slide; top = top.parentElement) {
      if (top.parentElement.matches(NO_STRETCH)) return null;
    }
    if (top.tagName !== 'DIV') return null;
    // A div the author marked .r-stretch around the chunk: Quarto takes the
    // class from such a div and gives it to the image the div holds, which
    // reveal.js then sizes; left on the div, reveal.js sizes the div and
    // not the chart.
    if (top.classList.contains('r-stretch') || top.classList.contains('stretch')) {
      top.classList.remove('r-stretch', 'stretch');
      top.style.removeProperty('width');
      top.style.removeProperty('height');
      top.setAttribute('data-maidr-knitr-stretch', '');
    }
    if (!(top.classList.contains('cell') || top.classList.contains('quarto-figure') ||
        top.hasAttribute('data-maidr-knitr-stretch'))) {
      return null;
    }
    return slide;
  }

  function unstretch(wrapper, svg) {
    svg.style.removeProperty('width');
    svg.style.removeProperty('height');
    wrapper.classList.remove('maidr-knitr-stretched');
  }

  function stretchChart(wrapper) {
    var reveal = window.Reveal;
    if (!reveal || !wrapper.matches(STRETCH)) return;
    var svg = wrapper.querySelector('svg.maidr-knitr-svg');
    var box = svg && svg.viewBox && svg.viewBox.baseVal;
    if (!box || !(box.width > 0) || !(box.height > 0)) return;
    var slide = stretchSlide(wrapper);
    if (!slide || (typeof reveal.isScrollView === 'function' && reveal.isScrollView())) {
      unstretch(wrapper, svg);
      return;
    }
    // A slide reveal.js does not show has no height to measure; it is
    // measured when it is shown.
    if (!slide.offsetHeight) return;
    var size = typeof reveal.getComputedSlideSize === 'function'
      ? reveal.getComputedSlideSize() : reveal.getConfig();
    if (!(size.width > 0) || !(size.height > 0)) return;
    wrapper.classList.add('maidr-knitr-stretched');
    var room = slideRoom(wrapper, slide, size.height);
    var scale = Math.min(size.width / box.width, Math.max(room, 96) / box.height);
    svg.style.width = box.width * scale + 'px';
    svg.style.height = box.height * scale + 'px';
  }

  function stretchCharts() {
    var wrappers = document.querySelectorAll(STRETCH);
    for (var i = 0; i < wrappers.length; i++) stretchChart(wrappers[i]);
  }

  function watchStretch() {
    var reveal = window.Reveal;
    if (watchStretch.done || !reveal || typeof reveal.on !== 'function' ||
        !document.querySelector(STRETCH)) {
      return;
    }
    watchStretch.done = true;
    ['ready', 'resize', 'slidechanged'].forEach(function (name) {
      reveal.on(name, stretchCharts);
    });
    // reveal.js tells of a change of scale, but not of a change into its
    // scroll view or out of it, which a window resized past its width
    // makes; it has laid the deck out again by the frame after.
    var pending = false;
    window.addEventListener('resize', function () {
      if (pending) return;
      pending = true;
      requestAnimationFrame(function () {
        pending = false;
        stretchCharts();
      });
    });
    if (typeof reveal.isReady !== 'function' || reveal.isReady()) stretchCharts();
  }

  // ioslides shows a figure at its size, and clips what runs past the
  // slide's foot. A chart too large to leave the room for maidr's text
  // below it on its slide is made smaller, never larger. Not on a slide of
  // two columns, whose height is not the column's.
  var IOSLIDE = 'slides > slide';

  function fitIoslide(wrapper) {
    var slide = wrapper.closest(IOSLIDE);
    var svg = wrapper.querySelector('svg.maidr-knitr-svg');
    var box = svg && svg.viewBox && svg.viewBox.baseVal;
    if (!slide || !box || !(box.width > 0) || !(box.height > 0)) return;
    var article = wrapper.closest('article');
    if (article && parseInt(getComputedStyle(article).columnCount, 10) > 1) return;
    // A slide ioslides does not show is measured when it is shown.
    var height = slide.offsetHeight;
    if (!height) return;
    svg.style.width = heightWidth(svg);
    svg.style.height = '';
    // The slide's pixels: ioslides scales its slides to a small window.
    var scale = slide.getBoundingClientRect().height / height;
    var shown = svg.getBoundingClientRect().height / scale;
    var room = Math.max(slideRoom(wrapper, slide, height), 96);
    if (shown <= room) return;
    svg.style.width = box.width * room / box.height + 'px';
    svg.style.height = room + 'px';
  }

  function fitIoslides() {
    var wrappers = document.querySelectorAll(IOSLIDE + ' .maidr-knitr');
    for (var i = 0; i < wrappers.length; i++) fitIoslide(wrappers[i]);
    if (wrappers.length && !fitIoslides.done) {
      fitIoslides.done = true;
      document.addEventListener('slideenter', function (event) {
        var inSlide = event.target.querySelectorAll ? event.target.querySelectorAll('.maidr-knitr') : [];
        for (var j = 0; j < inSlide.length; j++) fitIoslide(inSlide[j]);
      });
    }
  }

  // --- High contrast -------------------------------------------------------

  // maidr.js paints document.body for high contrast. In a frame that was the
  // chart's own body; inline it is the whole page. While maidr has it
  // painted, the page is given its own colours back, and the chart's wrapper
  // -- or a widget's, which maidr mounted in the page itself -- takes
  // maidr's, which is what the frame looked like. The body's inline style is
  // left as maidr.js wrote it -- knitr-inline.css overrides it -- so that
  // maidr.js putting it back is a change this sees, whenever it happens:
  // high contrast turned off, or the reader leaving the chart.
  var painted = null;
  var pageInline = null;

  function bodyColours() {
    var style = document.body.style;
    return [style.getPropertyValue('background-color'), style.getPropertyValue('color')];
  }

  function unpaint() {
    document.documentElement.classList.remove('maidr-knitr-contrast');
    if (painted) {
      painted.style.removeProperty('background-color');
      painted.style.removeProperty('color');
      painted = null;
    }
  }

  // The page's colours, read before maidr paints the body over them. Not
  // while a chart has it painted: the reader went from one chart to the
  // next, and the colours on it are maidr's.
  function notePageColours() {
    if (!document.body || document.documentElement.classList.contains('maidr-knitr-contrast')) return;
    var computed = getComputedStyle(document.body);
    var root = document.documentElement.style;
    root.setProperty('--maidr-knitr-page-bg', computed.backgroundColor);
    root.setProperty('--maidr-knitr-page-fg', computed.color);
    pageInline = bodyColours();
  }

  function followContrast() {
    var now = bodyColours();
    if (!pageInline || (now[0] === pageInline[0] && now[1] === pageInline[1])) {
      unpaint();
      return;
    }
    var target = paintTarget(document.activeElement);
    if (!target) {
      // The page changed its own body, not maidr.
      unpaint();
      pageInline = now;
      return;
    }
    if (painted && painted !== target) unpaint();
    target.style.setProperty('background-color', now[0]);
    target.style.setProperty('color', now[1]);
    painted = target;
    document.documentElement.classList.add('maidr-knitr-contrast');
  }

  function watchContrast() {
    if (!document.body || !window.MutationObserver || watchContrast.done) return;
    watchContrast.done = true;
    notePageColours();
    new MutationObserver(followContrast)
      .observe(document.body, { attributes: true, attributeFilter: ['style'] });
  }

  // --- Host page shortcuts ---------------------------------------------

  // Each host object this script guards is marked, and one marked already
  // is left alone: by this script, or by a maidr.js that guards the page's
  // hosts itself, which marks what it guards with __maidrHostGuard (and
  // this script's mark), so a key is never guarded twice over.
  function isGuarded(object) {
    return !!(object.__maidrKnitr || object.__maidrHostGuard);
  }

  // Such a maidr.js says so in maidrLive.features. reveal.js's search key
  // below guards no object to mark, and is left to it: it holds the key
  // off the deck itself, but for a reader who gave the key to one of
  // maidr's commands.
  function nativeGuards() {
    var live = window.maidrLive;
    return !!(live && live.features && live.features.hostGuards >= 1);
  }

  // reveal.js (rmarkdown revealjs, Quarto revealjs) reads keyboardCondition
  // on every keydown; whatever the deck set is kept. reveal.js 3, which
  // older revealjs packages bundle, has no on(), and may be ready only once
  // its dependencies have loaded.
  function shimReveal() {
    var reveal = window.Reveal;
    if (!reveal || isGuarded(reveal) || typeof reveal.configure !== 'function' ||
        typeof reveal.getConfig !== 'function') {
      return;
    }
    reveal.__maidrKnitr = true;
    function apply() {
      var previous = reveal.getConfig().keyboardCondition;
      reveal.configure({
        keyboardCondition: function () {
          if (focusInChart()) return false;
          if (typeof previous === 'function') return previous.apply(this, arguments);
          if (previous === 'focused') return reveal.isFocused();
          return true;
        }
      });
    }
    if (typeof reveal.isReady === 'function' && reveal.isReady()) {
      apply();
    } else if (typeof reveal.on === 'function') {
      reveal.on('ready', apply);
    } else if (typeof reveal.addEventListener === 'function') {
      reveal.addEventListener('ready', apply);
    } else {
      reveal.__maidrKnitr = false;
    }
  }

  // Mousetrap (bookdown's gitbook: the arrow keys turn the page, s toggles
  // the sidebar, f opens the search).
  function shimMousetrap() {
    var mousetrap = window.Mousetrap;
    if (!mousetrap || isGuarded(mousetrap)) return;
    var host = mousetrap.prototype && typeof mousetrap.prototype.stopCallback === 'function'
      ? mousetrap.prototype : mousetrap;
    var previous = host.stopCallback;
    if (typeof previous !== 'function') return;
    mousetrap.__maidrKnitr = true;
    host.stopCallback = function (event, element) {
      if (inChart(element) || focusInChart()) return true;
      return previous.apply(this, arguments);
    };
  }

  // The search of a Quarto website or book opens on f, s or / outside a form
  // field, through window.quartoOpenSearch, looked up when the key is let go.
  function shimQuartoSearch() {
    var open = window.quartoOpenSearch;
    if (typeof open !== 'function' || isGuarded(open)) return;
    var guarded = function () {
      if (focusInChart()) return;
      return open.apply(this, arguments);
    };
    guarded.__maidrKnitr = true;
    window.quartoOpenSearch = guarded;
  }

  // A flexdashboard storyboard's Sly moves between frames on the arrow keys,
  // listening on the document with no regard for the focus. It reads
  // options.keyboardNavBy on every key press.
  function shimSly() {
    var Sly = window.Sly;
    if (!Sly || typeof Sly.getInstance !== 'function') return;
    var frames = document.querySelectorAll('.sbframelist');
    for (var i = 0; i < frames.length; i++) {
      var sly = Sly.getInstance(frames[i]);
      if (!sly || !sly.options || isGuarded(sly.options)) continue;
      guardSlyOptions(sly.options);
    }
  }

  function guardSlyOptions(options) {
    var navBy = options.keyboardNavBy;
    Object.defineProperty(options, 'keyboardNavBy', {
      configurable: true,
      get: function () { return focusInChart() ? null : navBy; },
      set: function (value) { navBy = value; }
    });
    options.__maidrKnitr = true;
  }

  // ioslides listens for keydown in the capture phase on the document, from
  // a handler bound when the deck is built at DOMContentLoaded. This script
  // runs before that, so the handler is guarded on the prototype.
  function shimIoslides() {
    var SlideDeck = window.SlideDeck;
    if (!SlideDeck || !SlideDeck.prototype || isGuarded(SlideDeck) ||
        typeof SlideDeck.prototype.onBodyKeyDown_ !== 'function') {
      return;
    }
    SlideDeck.__maidrKnitr = true;
    var previous = SlideDeck.prototype.onBodyKeyDown_;
    SlideDeck.prototype.onBodyKeyDown_ = function () {
      if (focusInChart()) return;
      return previous.apply(this, arguments);
    };
  }

  // slidy leaves alone a key pressed on an element with an onkeydown
  // property of its own.
  function keepFromSlidy(plot) {
    if (window.w3c_slidy && !isGuarded(window.w3c_slidy) && !plot.onkeydown) {
      plot.onkeydown = function () {};
    }
  }

  // pkgdown moves the focus to its search box on /, which maidr reads as
  // "reset speed" on the chart itself and in braille mode. The box cannot
  // take the focus while it is disabled, for the one task in which pkgdown's
  // handler runs. (A / typed into maidr's other fields never reaches
  // pkgdown: see keepSlashFromPage().)
  function shimPkgdownSearch(event) {
    if (event.key !== '/') return;
    var search = document.getElementById('search-input');
    if (!search || search.disabled) return;
    search.disabled = true;
    setTimeout(function () { search.disabled = false; }, 0);
  }

  // A bslib card shown full screen (a Quarto dashboard's) leaves it on
  // Escape pressed anywhere, through a listener on the document that it
  // keeps on the card's instance. The one for a card around a chart ignores
  // the keys pressed in the chart, where Escape closes maidr's own modes.
  // (This file reaches a page as a dependency in its <head>, never as a
  // cell's output, so Quarto's dashboard filter, which lifts an output that
  // is only a raw HTML block out of its card when the text 'bsli' is in it
  // -- its pattern 'bslib-' is a Lua pattern, whose 'b-' matches no b at
  // all -- never reads it.)
  function shimCard(card) {
    var Card = window.bslib && window.bslib.Card;
    var instance = Card && typeof Card.getInstance === 'function' && Card.getInstance(card);
    if (!instance || isGuarded(instance) || typeof instance._exitFullScreenOnEscape !== 'function') {
      return;
    }
    instance.__maidrKnitr = true;
    var previous = instance._exitFullScreenOnEscape;
    var guarded = function (event) {
      if (inChart(event.target)) return;
      return previous.call(instance, event);
    };
    if (card.getAttribute('data-full-screen') === 'true') {
      document.removeEventListener('keydown', previous, false);
      document.addEventListener('keydown', guarded, false);
    }
    instance._exitFullScreenOnEscape = guarded;
  }

  function shimCards(node) {
    for (var card = node.closest('.bslib-card'); card;
      card = card.parentElement && card.parentElement.closest('.bslib-card')) {
      shimCard(card);
    }
  }

  function shimHosts() {
    shimIoslides();
    shimReveal();
    shimMousetrap();
    shimQuartoSearch();
    shimSly();
  }

  // --- A deck's keys -------------------------------------------------------

  // A slide deck: reveal.js (rmarkdown revealjs, Quarto revealjs), ioslides
  // or slidy.
  function onDeck() {
    return !!(window.Reveal || window.SlideDeck || window.w3c_slidy);
  }

  // On a slide a chart is often the first thing Tab reaches, and Shift+Tab
  // from it would leave the page for the browser's own controls, where no
  // key reaches the deck. maidr.js hands the reader to the slide when its
  // chart is framed; this does the same inline, on a deck, and only when
  // nothing on the page comes before the chart. On any other page Shift+Tab
  // is left to the browser.
  var TABBABLE = 'a[href],area[href],button:not([disabled]),input:not([disabled]),' +
    'select:not([disabled]),textarea:not([disabled]),iframe,audio[controls],video[controls],' +
    '[contenteditable]:not([contenteditable="false"]),[tabindex]:not([tabindex^="-"])';

  // A link or a field with a negative tabindex is out of the tab order, as
  // pandoc's anchors for the lines of a code block are.
  function reachable(element) {
    if (parseInt(element.getAttribute('tabindex'), 10) < 0) return false;
    if (element.closest('[hidden],[aria-hidden="true"],[inert]')) return false;
    var style = getComputedStyle(element);
    return style.display !== 'none' && style.visibility !== 'hidden';
  }

  function takeFocus(element) {
    var added = !element.hasAttribute('tabindex');
    if (added) element.setAttribute('tabindex', '-1');
    element.focus();
    if (document.activeElement === element) return true;
    if (added) element.removeAttribute('tabindex');
    return false;
  }

  function handOff(event) {
    if (event.key !== 'Tab' || !event.shiftKey || event.altKey || event.ctrlKey ||
        event.metaKey || event.defaultPrevented || !onDeck()) {
      return;
    }
    var active = document.activeElement;
    var wrapper = paintTarget(active);
    if (!wrapper || active.closest('[role="dialog"],[aria-modal="true"]')) return;
    var stops = document.querySelectorAll(TABBABLE);
    for (var i = 0; i < stops.length && stops[i] !== active; i++) {
      if (reachable(stops[i])) return;
    }
    event.preventDefault();
    // From outside the wrapper: maidr mounts a widget in an <article> of its
    // own, which is no slide.
    var host = wrapper.parentElement;
    var slide = host && host.closest('section,article,[role="region"],.slide');
    var candidates = slide ? [slide] : [];
    for (var node = host; node; node = node.parentElement) {
      if (node !== slide) candidates.push(node);
    }
    for (var j = 0; j < candidates.length; j++) {
      if (takeFocus(candidates[j])) return;
    }
    active.blur();
  }

  // reveal.js's search plugin opens on Ctrl+Shift+F (Cmd on a Mac) from a
  // listener of its own on the document, which keyboardCondition does not
  // reach. Its test is a capital F with Ctrl or Cmd held, so Ctrl+F with
  // Caps Lock on opens it too. The key is stopped on the root element as
  // it bubbles up: after the React handlers inside the page have had it --
  // among them the recorder that takes a new shortcut in maidr's settings
  // -- and before the document. maidr.js's own shortcuts listen on the
  // document too, so the stopped key reaches them no more than the plugin,
  // and it is stopped only on a deck that has the plugin: anywhere else it
  // is left to a reader who gave it to one of maidr's commands.
  function keepSearchShut(event) {
    if (!(event.ctrlKey || event.metaKey) || event.key !== 'F' || nativeGuards()) return;
    var reveal = window.Reveal;
    if (window.RevealSearch ||
        (reveal && typeof reveal.hasPlugin === 'function' && reveal.hasPlugin('search'))) {
      event.stopPropagation();
    }
  }

  // --- Quarto cross-reference previews -----------------------------------

  // Hovering a reference to a Quarto figure shows a copy of the figure in a
  // tippy popup, which Quarto places beside the reference and fills when it
  // shows it: a second chart with the same ids, and a second focusable
  // element. The copy is made inert and loses its ids and tab stops; its
  // url(#..) references still find the original's definitions.
  function quietPreview(root) {
    if (!root.querySelector(CHART)) return;
    root.setAttribute('inert', '');
    var nodes = root.querySelectorAll('[id], [tabindex]');
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].removeAttribute('id');
      nodes[i].removeAttribute('tabindex');
    }
  }

  function watchPreviews() {
    if (!window.MutationObserver || !window.tippy) return;
    new MutationObserver(function (records) {
      for (var i = 0; i < records.length; i++) {
        var added = records[i].addedNodes;
        for (var j = 0; j < added.length; j++) {
          var node = added[j];
          var root = node.nodeType === 1 && node.closest('[data-tippy-root]');
          if (root) quietPreview(root);
        }
      }
    }).observe(document.body, { childList: true, subtree: true });
  }

  // --- Start ---------------------------------------------------------------

  shimIoslides();
  // Before any handler of the page sees a key pressed in a chart: a host
  // built after load (a storyboard's Sly) is guarded by then.
  window.addEventListener('keydown', function (event) {
    if (!focusInChart()) return;
    shimHosts();
    shimPkgdownSearch(event);
    handOff(event);
  }, true);
  document.documentElement.addEventListener('keydown', function (event) {
    if (focusInChart()) keepSearchShut(event);
  }, false);
  document.addEventListener('focusin', function (event) {
    var target = event.target;
    if (inChart(target)) {
      notePageColours();
      shimCards(target);
    }
    if (target && target.matches && target.matches(PLOT)) describe(target);
    // The page may have zoomed since (a deck resized to its window), and a
    // dialog takes the focus when it is shown.
    var wrapper = target && target.closest && target.closest('.maidr-knitr');
    if (wrapper) {
      sizeDialogs(wrapper);
      keepInView(target);
    }
  }, true);

  function onReady() {
    pointAtMathStylesheet();
    bindCharts();
    shimHosts();
    watchContrast();
    watchPreviews();
    // Hosts that build their page when it is ready (Quarto's search, a
    // storyboard) are built by load, and so is a maidr.js that loaded late.
    window.addEventListener('load', function () {
      pointAtMathStylesheet();
      bindCharts();
      shimHosts();
      describeAll();
      fitCharts();
      watchStretch();
      fitIoslides();
      sizeAllDialogs();
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onReady);
  } else {
    onReady();
  }
})();
