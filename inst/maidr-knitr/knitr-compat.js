/* maidr knitr-compat: for a knitted page whose maidr.js is older than 4.15.0.
 *
 * Copies of what maidr.js does itself from 4.15.0 for a chart that shares
 * its page with other content. A page loads the maidr.js this package
 * bundles, which does all of it, and carries none of this; it carries this
 * beside knitr-inline.js only when its maidr.js comes from the CDN at a
 * version older than that, or at `latest`, which jsDelivr may answer with an
 * older release (see maidr_knitr_compat_needed() in R/html_dependencies.R).
 * Each copy, and the change to maidr.js that ships it:
 *
 * - High contrast: maidr.js paints document.body, which inline is the whole
 *   page (xability/maidr#1388 paints the chart).
 * - The page's shortcuts -- reveal.js, gitbook's Mousetrap, a Quarto site's
 *   search, ioslides, slidy, a storyboard's Sly, pkgdown's /, the Escape of
 *   a card shown full screen, the search key of reveal.js's plugin -- and
 *   Shift+Tab from a chart at the start of a deck's slide
 *   (xability/maidr#1390, which says so in maidrLive.features.hostGuards).
 * - The focus ring, in knitr-compat.css (xability/maidr#1390,
 *   maidrLive.features.focusRing).
 *
 * Every copy acts only while the focus is in a chart, so the page's own keys
 * work everywhere else, and stands down for a maidr.js that does the same
 * itself: `latest` may be one. */
(function () {
  'use strict';
  if (window.__maidrKnitrCompat) return;
  window.__maidrKnitrCompat = true;

  // An inline chart, or a widget maidr mounted on the same page.
  var CHART = '.maidr-knitr, article[id^="maidr-article-"]';
  // The element maidr makes focusable around an inline chart.
  var PLOT = '.maidr-knitr figure[id^="maidr-figure"] > [tabindex]';

  // Whether the page's maidr.js lacks what these copy: it has run, and does
  // not say it guards the page's hosts and draws the focus ring itself. The
  // release that first says so, 4.15.0, is also the first to paint the
  // chart, not the page, for high contrast.
  function olderMaidr() {
    var live = window.maidrLive;
    if (!live) return false;
    var features = live.features;
    return !(features && features.hostGuards >= 1 && features.focusRing >= 1);
  }

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

  // --- High contrast -------------------------------------------------------

  // maidr.js paints document.body for high contrast. In a frame that was the
  // chart's own body; inline it is the whole page. While maidr has it
  // painted, the page is given its own colours back, and the chart's wrapper
  // -- or a widget's, which maidr mounted in the page itself -- takes
  // maidr's, which is what the frame looked like. The body's inline style is
  // left as maidr.js wrote it -- knitr-compat.css overrides it -- so that
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
    if (!document.body || !window.MutationObserver || watchContrast.done || !olderMaidr()) return;
    watchContrast.done = true;
    notePageColours();
    new MutationObserver(followContrast)
      .observe(document.body, { attributes: true, attributeFilter: ['style'] });
  }

  // --- Host page shortcuts -------------------------------------------------

  // Each host object guarded here is marked, and one marked already is left
  // alone. maidr.js 4.15.0 and later honours the mark too, and leaves an
  // object guarded here as it is.
  function isGuarded(object) {
    return !!object.__maidrKnitr;
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
    if (!olderMaidr()) return;
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
  // pandoc's anchors for the lines of a code block are. ioslides marks none
  // of its slides hidden: it renders every one and fades out all but the
  // current, so a chart or a link on another slide is not on screen.
  function reachable(element) {
    if (parseInt(element.getAttribute('tabindex'), 10) < 0) return false;
    if (element.closest('[hidden],[aria-hidden="true"],[inert]')) return false;
    if (element.closest('slides > slide:not(.current)')) return false;
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
    if (!(event.ctrlKey || event.metaKey) || event.key !== 'F') return;
    var reveal = window.Reveal;
    if (window.RevealSearch ||
        (reveal && typeof reveal.hasPlugin === 'function' && reveal.hasPlugin('search'))) {
      event.stopPropagation();
    }
  }

  // --- Start ---------------------------------------------------------------

  // Marks the page for the copies of knitr-compat.css, the focus ring.
  function markPage() {
    document.documentElement.classList.toggle('maidr-knitr-compat', olderMaidr());
  }

  // The maidr.js a page carries this for comes from the CDN, a script with
  // no defer ahead of this one, which has run by now: ioslides is guarded
  // before it builds its deck.
  if (olderMaidr()) shimIoslides();
  // Before any handler of the page sees a key pressed in a chart: a host
  // built after load (a storyboard's Sly) is guarded by then.
  window.addEventListener('keydown', function (event) {
    if (!focusInChart() || !olderMaidr()) return;
    shimHosts();
    shimPkgdownSearch(event);
    handOff(event);
  }, true);
  document.documentElement.addEventListener('keydown', function (event) {
    if (focusInChart() && olderMaidr()) keepSearchShut(event);
  }, false);
  document.addEventListener('focusin', function (event) {
    var target = event.target;
    if (!inChart(target) || !olderMaidr()) return;
    notePageColours();
    shimCards(target);
    var wrapper = target.closest('.maidr-knitr');
    if (wrapper) keepSlashFromPage(wrapper);
    if (target.matches(PLOT)) keepFromSlidy(target);
  }, true);

  function onReady() {
    markPage();
    shimHosts();
    watchContrast();
    // Hosts that build their page when it is ready (Quarto's search, a
    // storyboard) are built by load, and so is a maidr.js that loaded late.
    window.addEventListener('load', function () {
      markPage();
      shimHosts();
      watchContrast();
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onReady);
  } else {
    onReady();
  }
})();
