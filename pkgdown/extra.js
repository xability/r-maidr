// Cookie consent configuration (orestbida/cookieconsent v3)
// Gates GA4 and MS Clarity under the "analytics" category.
window.addEventListener('DOMContentLoaded', function () {
  if (typeof CookieConsent !== 'undefined') {
    CookieConsent.run({
      guiOptions: {
        consentModal: {
          layout: 'box inline',
          position: 'bottom right',
        },
      },
      categories: {
        necessary: {
          enabled: true,
          readOnly: true,
        },
        analytics: {},
      },
      language: {
        default: 'en',
        translations: {
          en: {
            consentModal: {
              title: 'We use cookies',
              description:
                'This site uses cookies to help us understand how it is used. You can choose to accept or decline analytics cookies.',
              acceptAllBtn: 'Accept all',
              acceptNecessaryBtn: 'Accept necessary only',
              showPreferencesBtn: 'Manage preferences',
            },
            preferencesModal: {
              title: 'Cookie preferences',
              acceptAllBtn: 'Accept all',
              acceptNecessaryBtn: 'Accept necessary only',
              savePreferencesBtn: 'Save preferences',
              sections: [
                {
                  title: 'Necessary cookies',
                  description:
                    'These cookies are essential for the site to function properly.',
                  linkedCategory: 'necessary',
                },
                {
                  title: 'Analytics cookies',
                  description:
                    'These cookies help us understand how visitors interact with the site via Google Analytics and Microsoft Clarity.',
                  linkedCategory: 'analytics',
                },
              ],
            },
          },
        },
      },
    });
  }
});

// Accessibility fix: improve keyboard navigation per WCAG 2.4.3 (Focus Order)
// - Remove auto-linked function names from Tab order inside code blocks
// - Ensure all MAIDR plot iframes are keyboard-focusable

(function () {
  'use strict';

  // 1. Remove all links inside code blocks from keyboard Tab order.
  //    pkgdown/downlit auto-links R function names (e.g. c, ggplot, barplot)
  //    which creates dozens of unnecessary Tab stops per code block.
  //    Setting tabindex="-1" keeps them mouse-clickable but skips them on Tab.
  function fixCodeBlockLinks() {
    document
      .querySelectorAll('pre code a, pre.sourceCode a')
      .forEach(function (link) {
        link.setAttribute('tabindex', '-1');
      });
  }

  // 2. Ensure every MAIDR iframe is focusable via keyboard.
  //    The iframes now have tabindex="0" baked into the HTML from R,
  //    but we also reinforce it here as a safety net and trigger a
  //    reflow so the browser registers them as focusable immediately.
  function ensureIframeFocusable(iframe) {
    if (!iframe.hasAttribute('tabindex')) {
      iframe.setAttribute('tabindex', '0');
    }
    // Force the browser to recalculate the element's focusability
    // by briefly reading a layout property after setting tabindex.
    void iframe.offsetHeight;
  }

  function fixAllIframes() {
    document
      .querySelectorAll('iframe[id^="maidr-iframe"], iframe[id^="maidr-fallback"]')
      .forEach(ensureIframeFocusable);
  }

  // Run code-link fix as soon as the DOM is ready
  document.addEventListener('DOMContentLoaded', function () {
    fixCodeBlockLinks();

    // Attach per-iframe load handlers for iframes already in the DOM
    document
      .querySelectorAll('iframe[id^="maidr-iframe"], iframe[id^="maidr-fallback"]')
      .forEach(function (iframe) {
        ensureIframeFocusable(iframe);
        iframe.addEventListener('load', function () {
          ensureIframeFocusable(iframe);
        });
      });
  });

  // Final safety net: window.load fires after ALL sub-resources
  // (including iframe data-URI content) have fully loaded.
  window.addEventListener('load', function () {
    fixAllIframes();
  });
})();
