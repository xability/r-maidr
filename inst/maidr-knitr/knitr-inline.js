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
 * work everywhere else. */
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
  // the reader keeps a named picture rather than nothing.
  function verifyMounted(svg, wrapper, attempt) {
    if (svg.isConnected && svg.closest('figure[id^="maidr-figure"] > [tabindex]')) {
      svg.removeAttribute('role');
      svg.removeAttribute('aria-label');
      describeAll();
      if (wrapper) fitChart(wrapper);
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
    var value = ids.join(' ');
    if (value && plot.getAttribute('aria-describedby') !== value) {
      plot.setAttribute('aria-describedby', value);
    }
  }

  function describeAll() {
    var plots = document.querySelectorAll(PLOT);
    for (var i = 0; i < plots.length; i++) describe(plots[i]);
  }

  // --- maidr's dialogs -------------------------------------------------------

  // maidr opens its dialogs inside the chart, so they take the page's sizes:
  // their text is in rem, which a Bootstrap 3 page (html_document's default
  // theme, bookdown's gitbook) makes 10px rather than 16px, and a slide deck
  // that zooms its slides (reveal.js on a large window) zooms them past the
  // window. Each chart's wrapper carries the zoom that undoes the page's, and
  // the one that gives the dialogs' text its own size back, for the
  // stylesheet to apply.
  function sizeDialogs(wrapper) {
    var root = parseFloat(getComputedStyle(document.documentElement).fontSize);
    var host = 1;
    for (var node = wrapper.parentElement; node; node = node.parentElement) {
      var z = parseFloat(getComputedStyle(node).zoom);
      if (z > 0) host *= z;
    }
    wrapper.style.setProperty('--maidr-knitr-unzoom', String(1 / host));
    wrapper.style.setProperty('--maidr-knitr-zoom', String(root > 0 && root < 16 ? 16 / root : 1));
  }

  function sizeAllDialogs() {
    var wrappers = document.querySelectorAll('.maidr-knitr');
    for (var i = 0; i < wrappers.length; i++) sizeDialogs(wrappers[i]);
  }

  // pkgdown takes / for its search box from anywhere on the page, and stops
  // it being typed: a / typed into maidr's own fields (the command palette,
  // the chat) is kept from the page. maidr's handlers, below the wrapper,
  // still see it.
  function keepSlashFromPage(wrapper) {
    if (wrapper.__maidrKnitrSlash) return;
    wrapper.__maidrKnitrSlash = true;
    wrapper.addEventListener('keydown', function (event) {
      var target = event.target;
      var editable = target && (target.isContentEditable ||
        (target.matches && target.matches('input, textarea, select')));
      if (event.key === '/' && editable) event.stopPropagation();
    });
  }

  // --- Dashboards ----------------------------------------------------------

  // A dashboard sizes each box to the window: flexdashboard's .chart-shim, a
  // Quarto dashboard's fill items. A chart taller than its box is shrunk to
  // it, keeping its shape and a line for maidr's text below it. Whether a
  // box is sized by the window or by its content cannot be read from it (a
  // scrolling dashboard, a phone-width one), so a chart is only shrunk when
  // its box is overflowing: a box sized by its content never is.
  var FITTED = '.chart-shim > .maidr-knitr, .html-fill-item > .maidr-knitr';

  function fitChart(wrapper) {
    var box = wrapper.parentElement;
    // Not there while maidr mounts the chart, which fits it once mounted.
    var svg = wrapper.querySelector('svg.maidr-knitr-svg');
    if (!box || !svg || !wrapper.matches(FITTED)) return;
    svg.style.maxHeight = '';
    svg.style.width = '';
    var over = box.scrollHeight - box.clientHeight;
    if (over <= 1) return;
    var line = 2.5 * parseFloat(getComputedStyle(wrapper).fontSize);
    var height = svg.getBoundingClientRect().height - over - line;
    svg.style.width = 'auto';
    svg.style.maxHeight = Math.max(height, 96) + 'px';
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
    var wrappers = document.querySelectorAll(FITTED);
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

  // --- Host page shortcuts ---------------------------------------------

  // reveal.js 4 and 5 (rmarkdown revealjs, Quarto revealjs) read
  // keyboardCondition on every keydown; whatever the deck set is kept.
  function shimReveal() {
    var reveal = window.Reveal;
    if (!reveal || reveal.__maidrKnitr || typeof reveal.configure !== 'function' ||
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
    }
  }

  // Mousetrap (bookdown's gitbook: the arrow keys turn the page, s toggles
  // the sidebar, f opens the search).
  function shimMousetrap() {
    var mousetrap = window.Mousetrap;
    if (!mousetrap || mousetrap.__maidrKnitr) return;
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
    if (typeof open !== 'function' || open.__maidrKnitr) return;
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
      if (!sly || !sly.options || sly.options.__maidrKnitr) continue;
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
    if (!SlideDeck || !SlideDeck.prototype || SlideDeck.__maidrKnitr ||
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
    if (window.w3c_slidy && !plot.onkeydown) {
      plot.onkeydown = function () {};
    }
  }

  // pkgdown moves the focus to its search box on /, which maidr reads as
  // "reset speed" on the chart itself. The box cannot take the focus while
  // it is disabled, for the one task in which pkgdown's handler runs. (A /
  // typed into one of maidr's fields never reaches pkgdown: see
  // keepSlashFromPage().)
  function shimPkgdownSearch(event) {
    if (event.key !== '/') return;
    var search = document.getElementById('search-input');
    if (!search || search.disabled) return;
    search.disabled = true;
    setTimeout(function () { search.disabled = false; }, 0);
  }

  function shimHosts() {
    shimIoslides();
    shimReveal();
    shimMousetrap();
    shimQuartoSearch();
    shimSly();
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
  }, true);
  document.addEventListener('focusin', function (event) {
    var target = event.target;
    if (target && target.matches && target.matches(PLOT)) describe(target);
    // The page may have zoomed since (a deck resized to its window).
    var wrapper = target && target.closest && target.closest('.maidr-knitr');
    if (wrapper) sizeDialogs(wrapper);
  }, true);

  function onReady() {
    pointAtMathStylesheet();
    bindCharts();
    shimHosts();
    watchPreviews();
    // Hosts that build their page when it is ready (Quarto's search, a
    // storyboard) are built by load, and so is a maidr.js that loaded late.
    window.addEventListener('load', function () {
      pointAtMathStylesheet();
      bindCharts();
      shimHosts();
      describeAll();
      fitCharts();
      sizeAllDialogs();
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onReady);
  } else {
    onReady();
  }
})();
