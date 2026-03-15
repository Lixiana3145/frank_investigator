require "ferrum"

module Fetchers
  class ChromiumFetcher
    FetchError = Class.new(StandardError)
    InterstitialDetectedError = Class.new(FetchError)
    Snapshot = Struct.new(:html, :title, keyword_init: true)

    BROWSER_OPTIONS = {
      headless: "new",
      browser_options: {
        "no-sandbox" => nil,
        "disable-setuid-sandbox" => nil,
        "disable-gpu" => nil,
        "disable-dev-shm-usage" => nil,
        "no-first-run" => nil,
        "no-default-browser-check" => nil,
        "disable-blink-features" => "AutomationControlled",
        "window-size" => "1440,2200",
        "lang" => "pt-BR,pt,en-US,en"
      }
    }.freeze

    USER_AGENTS = [
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36"
    ].freeze

    # Patterns that appear only in actual challenge/interstitial pages
    INTERSTITIAL_PATTERN = /challenge-platform|cf-challenge|cf_chl_opt|challenges\.cloudflare\.com|just a moment.*cloudflare|checking your browser|checking if the site connection is secure|aguarde.*verificando/i

    MIN_CONTENT_LENGTH = 500

    # Common consent button selectors, ordered by specificity
    CONSENT_SELECTORS = [
      # CMP (Consent Management Platform) standard buttons
      "[data-testid='consent-accept']",
      "[data-testid='accept-all']",
      "button.consent-accept",
      "button.accept-all",
      # Brazilian LGPD patterns
      "button[class*='lgpd'] >> text: Aceitar",
      "button[class*='consent'] >> text: Aceitar",
      "button[class*='cookie'] >> text: Aceitar",
      # Generic consent buttons — text matching
      "button >> text: Aceitar todos",
      "button >> text: Aceitar tudo",
      "button >> text: Aceitar e continuar",
      "button >> text: Aceitar cookies",
      "button >> text: Aceitar",
      "button >> text: Concordo",
      "button >> text: Accept all",
      "button >> text: Accept cookies",
      "button >> text: Accept & continue",
      "button >> text: Accept",
      "button >> text: Agree",
      "button >> text: OK",
      # Link-style consent
      "a >> text: Aceitar",
      "a >> text: Accept"
    ].freeze

    def self.call(url)
      new.call(url)
    end

    def call(url)
      profile = HostProfile.for(url)
      timeout_seconds = (profile[:budget] / 1000.0) + 15

      browser = create_browser(timeout_seconds)
      begin
        page = browser.create_page
        stealth_page!(page)
        page.go_to(url)

        # Wait for page to settle (JS rendering, dynamic content)
        wait_for_content(page, timeout_seconds)

        # Try to dismiss cookie consent if present
        dismiss_consent(page)

        # Check for Cloudflare interstitial
        html = page.body
        if interstitial?(html)
          # Wait longer and retry
          sleep 3
          html = page.body
          raise InterstitialDetectedError, "Interstitial/challenge page detected for #{url}" if interstitial?(html)
        end

        title = page.title.to_s.squish
        Snapshot.new(html:, title:)
      ensure
        browser.quit
      end
    rescue Ferrum::TimeoutError, Ferrum::DeadBrowserError, Ferrum::BrowserError => e
      raise FetchError, "Browser error fetching #{url}: #{e.message}"
    end

    private

    def create_browser(timeout)
      options = BROWSER_OPTIONS.dup
      options[:browser_path] = browser_path
      options[:timeout] = timeout
      options[:process_timeout] = timeout + 5

      Ferrum::Browser.new(**options)
    end

    def stealth_page!(page)
      ua = USER_AGENTS.sample
      page.headers.set({
        "User-Agent" => ua,
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language" => "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
        "Accept-Encoding" => "gzip, deflate, br",
        "DNT" => "1",
        "Upgrade-Insecure-Requests" => "1",
        "Sec-Fetch-Dest" => "document",
        "Sec-Fetch-Mode" => "navigate",
        "Sec-Fetch-Site" => "none",
        "Sec-Fetch-User" => "?1"
      })

      # Remove webdriver fingerprint and other automation tells
      page.command("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)
        // Remove webdriver flag
        Object.defineProperty(navigator, 'webdriver', { get: () => undefined });

        // Fake plugins (real browsers have at least a few)
        Object.defineProperty(navigator, 'plugins', {
          get: () => [
            { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer' },
            { name: 'Chrome PDF Viewer', filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai' },
            { name: 'Native Client', filename: 'internal-nacl-plugin' }
          ]
        });

        // Fake languages
        Object.defineProperty(navigator, 'languages', { get: () => ['pt-BR', 'pt', 'en-US', 'en'] });

        // Fix chrome object (headless doesn't have it)
        window.chrome = { runtime: {}, loadTimes: function(){}, csi: function(){} };

        // Permissions API — real browsers return 'prompt', not 'denied'
        const originalQuery = window.navigator.permissions?.query;
        if (originalQuery) {
          window.navigator.permissions.query = (parameters) =>
            parameters.name === 'notifications'
              ? Promise.resolve({ state: Notification.permission })
              : originalQuery(parameters);
        }
      JS
    end

    def wait_for_content(page, timeout)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + [ timeout - 5, 3 ].max
      loop do
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        # Check if page has meaningful content
        text_length = page.evaluate("document.body?.innerText?.length || 0") rescue 0
        break if text_length > MIN_CONTENT_LENGTH

        sleep 0.5
      end
    rescue Ferrum::TimeoutError
      # Proceed with whatever content we have
    end

    def dismiss_consent(page)
      CONSENT_SELECTORS.each do |selector|
        if selector.include?(" >> text: ")
          # Text-based matching: find button/link containing text
          css_part, text = selector.split(" >> text: ", 2)
          clicked = page.evaluate(<<~JS)
            (() => {
              const elements = document.querySelectorAll('#{css_part}');
              for (const el of elements) {
                if (el.innerText?.trim()?.toLowerCase()?.includes('#{text.downcase}') && el.offsetParent !== null) {
                  el.click();
                  return true;
                }
              }
              return false;
            })()
          JS
          if clicked
            sleep 0.5
            return
          end
        else
          node = page.at_css(selector) rescue nil
          if node
            node.click rescue nil
            sleep 0.5
            return
          end
        end
      end
    rescue Ferrum::JavaScriptError, Ferrum::NodeNotFoundError
      # Consent button not found or not clickable — proceed without it
    end

    def interstitial?(html)
      return false unless html.match?(INTERSTITIAL_PATTERN)

      doc = Nokogiri::HTML(html)
      doc.css("script, style, noscript, iframe").each(&:remove)
      visible_text = doc.at("body")&.text.to_s.gsub(/\s+/, " ").strip
      visible_text.length < MIN_CONTENT_LENGTH
    end

    def browser_path
      ENV.fetch("CHROMIUM_PATH", "chromium")
    end
  end
end
