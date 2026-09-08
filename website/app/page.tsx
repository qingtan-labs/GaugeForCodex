'use client';

import { useEffect, useState } from 'react';
import {
  ArrowRight,
  Check,
  Clock3,
  Download,
  GitFork,
  Languages,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  TerminalSquare,
} from 'lucide-react';

import { Button } from '@/components/ui/button';

type Language = 'en' | 'zh';

const copy = {
  en: {
    navFeatures: 'Features',
    navPrivacy: 'Privacy',
    navInstall: 'Install',
    openSource: 'Open source',
    eyebrow: 'Native macOS menu bar utility',
    headlineTop: 'Know your Codex',
    headlineAccent: 'runway.',
    intro:
      'See every usage window, remaining quota, and reset countdown without leaving your work.',
    download: 'Download for macOS',
    source: 'View source',
    trust: ['Universal 2', 'macOS 12+', 'No telemetry'],
    remaining: 'remaining',
    resets: 'Resets in 4d 2h',
    resetDate: 'Sep 14, 3:11 PM',
    updated: 'Updated just now',
    refresh: 'Refresh Now',
    menuDisplay: 'Menu Bar Display',
    manual: 'Enter Usage Manually…',
    about: 'About Gauge for Codex',
    smallTitle: 'Quiet in the menu bar. Precise when you open it.',
    smallBody:
      'Gauge keeps the number you need visible, then gets out of the way. Open the menu for every window and the exact local reset time.',
    statRefresh: 'refresh interval',
    statLanguages: 'interface languages',
    statAnalytics: 'analytics or ads',
    featuresEyebrow: 'Built for focus',
    featuresTitle: 'The right information, at the right altitude.',
    featuresBody:
      'No dashboard to manage. No account to create. Just the usage signal that changes how you plan the next run.',
    cards: [
      {
        title: 'See the tightest window first',
        body: 'Gauge checks every available usage window and surfaces the one with the least room remaining.',
      },
      {
        title: 'Know exactly when it resets',
        body: 'A plain-language countdown sits beside the exact reset time in your own time zone.',
      },
      {
        title: 'Stay useful through hiccups',
        body: 'Automatic refresh and a last-known-good cache keep transient failures from turning the menu bar blank.',
      },
    ],
    previewEyebrow: 'Everything in one glance',
    previewTitle: 'Designed to answer one question quickly.',
    previewBody:
      'How much Codex capacity do I have, and when does it come back? Gauge answers without following a Codex window around your desktop.',
    privacyEyebrow: 'Local by design',
    privacyTitle: 'Your work stays your work.',
    privacyBody:
      'Gauge reads a normalized rate-limit summary from the Codex installation already on your Mac. It does not read prompts, conversations, browser cookies, passwords, or API keys.',
    privacyPoints: [
      'No analytics, advertising, or crash-reporting SDK',
      'No developer-operated account system or backend',
      'Only usage percentages and reset times are cached locally',
    ],
    flowLocal: 'Your Mac',
    flowCodex: 'Local Codex',
    flowRead: 'Read-only usage summary',
    flowMenu: 'Menu bar',
    installEyebrow: 'Ready in minutes',
    installTitle: 'Download the Universal build or install from source.',
    installBody:
      'The release includes a DMG, ZIP, and SHA-256 checksums. Apple silicon and Intel Macs are supported.',
    release: 'Open latest release',
    copyHint: 'Build and install from source',
    requirement: 'Requires macOS 12 Monterey or later and a signed-in Codex installation.',
    footerLine: 'A focused, open-source utility for macOS.',
    disclaimer:
      'Unofficial third-party utility. Not affiliated with or endorsed by OpenAI. Codex and OpenAI are trademarks of OpenAI.',
  },
  zh: {
    navFeatures: '功能',
    navPrivacy: '隐私',
    navInstall: '安装',
    openSource: '开源项目',
    eyebrow: '原生 macOS 菜单栏工具',
    headlineTop: '随时掌握 Codex',
    headlineAccent: '可用额度。',
    intro: '无需离开当前工作，即可查看全部额度周期、剩余比例与重置倒计时。',
    download: '下载 macOS 版本',
    source: '查看源代码',
    trust: ['Universal 2', 'macOS 12+', '无遥测'],
    remaining: '剩余',
    resets: '4 天 2 小时后重置',
    resetDate: '9 月 14 日 15:11',
    updated: '刚刚更新',
    refresh: '立即刷新',
    menuDisplay: '菜单栏显示',
    manual: '手动输入额度…',
    about: '关于 Gauge for Codex',
    smallTitle: '菜单栏里足够安静，展开后足够准确。',
    smallBody:
      'Gauge 只把最需要的数字留在顶部。展开菜单，即可查看全部额度周期与本地准确重置时间。',
    statRefresh: '自动刷新',
    statLanguages: '界面语言',
    statAnalytics: '分析与广告',
    featuresEyebrow: '为专注而生',
    featuresTitle: '信息刚刚好，不打断工作。',
    featuresBody:
      '无需管理仪表盘，也无需额外注册账号。只保留真正影响下一次 Codex 任务安排的使用信号。',
    cards: [
      {
        title: '优先显示最紧张的额度',
        body: '自动检查所有可用额度周期，并把剩余空间最少的一档放在菜单栏。',
      },
      {
        title: '准确知道何时恢复',
        body: '同时显示易读的剩余时间和当前时区下的准确重置时刻。',
      },
      {
        title: '偶发故障也不会空白',
        body: '自动刷新与最近一次有效缓存，避免临时同步失败让菜单栏突然失去数据。',
      },
    ],
    previewEyebrow: '一眼看全',
    previewTitle: '专门用来快速回答一个问题。',
    previewBody:
      '我还有多少 Codex 可用额度，什么时候恢复？Gauge 无需跟随 Codex 窗口，也能随时给出答案。',
    privacyEyebrow: '本地优先',
    privacyTitle: '你的工作内容始终属于你。',
    privacyBody:
      'Gauge 从这台 Mac 已安装的 Codex 中读取标准化额度摘要，不读取提示词、对话内容、浏览器 Cookie、密码或 API Key。',
    privacyPoints: [
      '没有分析、广告或崩溃上报 SDK',
      '没有开发者运营的账号系统或后端',
      '只在本机缓存额度比例与重置时间',
    ],
    flowLocal: '你的 Mac',
    flowCodex: '本机 Codex',
    flowRead: '只读额度摘要',
    flowMenu: '菜单栏',
    installEyebrow: '几分钟即可使用',
    installTitle: '下载 Universal 安装包，或从源码安装。',
    installBody: 'Release 同时提供 DMG、ZIP 与 SHA-256 校验值，支持 Apple 芯片和 Intel Mac。',
    release: '打开最新 Release',
    copyHint: '从源码构建并安装',
    requirement: '需要 macOS 12 Monterey 或更高版本，并已登录 Codex。',
    footerLine: '专注、开源的 macOS 小工具。',
    disclaimer:
      '非官方第三方工具，与 OpenAI 没有隶属或背书关系。Codex 与 OpenAI 是 OpenAI 的商标。',
  },
} as const;

const releaseUrl = 'https://github.com/qingtan-labs/GaugeForCodex/releases/latest';
const repositoryUrl = 'https://github.com/qingtan-labs/GaugeForCodex';

function BrandMark() {
  return (
    <span className="brand-mark" aria-hidden="true">
      <span className="brand-c">C</span>
      <span className="brand-bars">
        <i />
        <i />
        <i />
      </span>
    </span>
  );
}

function QuotaRing({ value, label }: { value: number; label: string }) {
  return (
    <div className="quota-ring" style={{ '--quota': `${value * 3.6}deg` } as React.CSSProperties}>
      <div className="quota-ring-core">
        <strong>{value}%</strong>
        <span>{label}</span>
      </div>
    </div>
  );
}

export default function Home() {
  const [language, setLanguage] = useState<Language>('en');
  const t = copy[language];

  useEffect(() => {
    document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
  }, [language]);

  return (
    <main className="site-shell">
      <div className="ambient ambient-one" aria-hidden="true" />
      <div className="ambient ambient-two" aria-hidden="true" />

      <header className="site-header">
        <a className="brand" href="#top" aria-label="Gauge for Codex home">
          <BrandMark />
          <span>Gauge for Codex</span>
        </a>
        <nav className="main-nav" aria-label="Primary navigation">
          <a href="#features">{t.navFeatures}</a>
          <a href="#privacy">{t.navPrivacy}</a>
          <a href="#install">{t.navInstall}</a>
        </nav>
        <div className="nav-actions">
          <a className="source-link" href={repositoryUrl} target="_blank" rel="noreferrer">
            <GitFork aria-hidden="true" />
            <span>{t.openSource}</span>
          </a>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="language-button"
            onClick={() => setLanguage(language === 'en' ? 'zh' : 'en')}
            aria-label={language === 'en' ? '切换为简体中文' : 'Switch to English'}
          >
            <Languages aria-hidden="true" />
            {language === 'en' ? '中文' : 'EN'}
          </Button>
        </div>
      </header>

      <section className="hero" id="top">
        <div className="hero-copy">
          <div className="eyebrow">
            <Sparkles aria-hidden="true" />
            {t.eyebrow}
          </div>
          <h1>
            {t.headlineTop}
            <span>{t.headlineAccent}</span>
          </h1>
          <p className="hero-intro">{t.intro}</p>
          <div className="hero-actions">
            <a className="primary-cta" href={releaseUrl} target="_blank" rel="noreferrer">
              <Download aria-hidden="true" />
              {t.download}
              <ArrowRight className="cta-arrow" aria-hidden="true" />
            </a>
            <a className="secondary-cta" href={repositoryUrl} target="_blank" rel="noreferrer">
              <GitFork aria-hidden="true" />
              {t.source}
            </a>
          </div>
          <ul className="trust-row" aria-label="Product compatibility">
            {t.trust.map((item) => (
              <li key={item}>
                <Check aria-hidden="true" /> {item}
              </li>
            ))}
          </ul>
        </div>

        <div className="product-stage" aria-label="Gauge for Codex interface preview">
          <div className="stage-orbit orbit-one" aria-hidden="true" />
          <div className="stage-orbit orbit-two" aria-hidden="true" />
          <div className="desktop-card">
            <div className="desktop-wallpaper">
              <div className="menu-strip">
                <span className="mini-brand">Gauge for Codex</span>
                <div className="menu-status">
                  <span>56%</span>
                  <span className="mini-track"><i /></span>
                </div>
              </div>
              <div className="editor-ghost" aria-hidden="true">
                <span />
                <span />
                <span />
                <span />
                <span />
              </div>
              <div className="popover-card">
                <div className="popover-heading">
                  <BrandMark />
                  <div>
                    <strong>Gauge for Codex</strong>
                    <span>56% {t.remaining}</span>
                  </div>
                </div>
                <div className="window-row">
                  <QuotaRing value={56} label="5 hr" />
                  <QuotaRing value={89} label="7 day" />
                  <div className="reset-copy">
                    <Clock3 aria-hidden="true" />
                    <strong>{t.resets}</strong>
                    <span>{t.resetDate}</span>
                  </div>
                </div>
                <div className="sync-row">
                  <span><i /> {t.updated}</span>
                  <RefreshCw aria-hidden="true" />
                </div>
                <div className="menu-options">
                  <span>{t.refresh}</span>
                  <span>{t.menuDisplay}<b>›</b></span>
                  <span>{t.manual}</span>
                  <span>{t.about}</span>
                </div>
              </div>
            </div>
          </div>
          <div className="floating-note note-top">
            <span>5h</span>
            <strong>56%</strong>
          </div>
          <div className="floating-note note-bottom">
            <ShieldCheck aria-hidden="true" />
            <span>{language === 'en' ? 'Local only' : '仅限本机'}</span>
          </div>
        </div>
      </section>

      <section className="utility-strip" aria-labelledby="utility-title">
        <div>
          <h2 id="utility-title">{t.smallTitle}</h2>
          <p>{t.smallBody}</p>
        </div>
        <dl>
          <div><dt>60s</dt><dd>{t.statRefresh}</dd></div>
          <div><dt>4</dt><dd>{t.statLanguages}</dd></div>
          <div><dt>0</dt><dd>{t.statAnalytics}</dd></div>
        </dl>
      </section>

      <section className="features-section" id="features">
        <div className="section-heading">
          <span>{t.featuresEyebrow}</span>
          <h2>{t.featuresTitle}</h2>
          <p>{t.featuresBody}</p>
        </div>
        <div className="feature-grid">
          {t.cards.map((card, index) => {
            const Icon = [TerminalSquare, Clock3, RefreshCw][index];
            return (
              <article className="feature-card" key={card.title}>
                <div className="feature-icon"><Icon aria-hidden="true" /></div>
                <span className="feature-index">0{index + 1}</span>
                <h3>{card.title}</h3>
                <p>{card.body}</p>
                <div className={`feature-visual visual-${index + 1}`} aria-hidden="true">
                  {index === 0 && <><i /><i /><i /><b>56%</b></>}
                  {index === 1 && <><strong>4d 2h</strong><span>{t.resetDate}</span></>}
                  {index === 2 && <><span /><span /><span /><b><Check /></b></>}
                </div>
              </article>
            );
          })}
        </div>
      </section>

      <section className="preview-section">
        <div className="preview-copy">
          <span>{t.previewEyebrow}</span>
          <h2>{t.previewTitle}</h2>
          <p>{t.previewBody}</p>
          <div className="preview-points">
            <span><Check /> {language === 'en' ? 'Percentage always visible' : '百分比始终可见'}</span>
            <span><Check /> {language === 'en' ? 'Every usage window included' : '展示全部额度周期'}</span>
          </div>
        </div>
        <figure className="screenshot-frame">
          <img src="/menu-overview.png" alt="Gauge for Codex menu bar and popover preview" />
          <figcaption>{language === 'en' ? 'Illustrative product preview' : '产品功能示意图'}</figcaption>
        </figure>
      </section>

      <section className="privacy-section" id="privacy">
        <div className="privacy-copy">
          <span>{t.privacyEyebrow}</span>
          <h2>{t.privacyTitle}</h2>
          <p>{t.privacyBody}</p>
          <ul>
            {t.privacyPoints.map((point) => (
              <li key={point}><Check aria-hidden="true" /> {point}</li>
            ))}
          </ul>
        </div>
        <div className="privacy-flow" aria-label="Local data flow">
          <div className="flow-node primary-node">
            <ShieldCheck aria-hidden="true" />
            <strong>{t.flowLocal}</strong>
          </div>
          <span className="flow-line"><i /></span>
          <div className="flow-node">
            <TerminalSquare aria-hidden="true" />
            <strong>{t.flowCodex}</strong>
            <span>{t.flowRead}</span>
          </div>
          <span className="flow-line"><i /></span>
          <div className="flow-node">
            <BrandMark />
            <strong>{t.flowMenu}</strong>
          </div>
        </div>
      </section>

      <section className="install-section" id="install">
        <div className="install-copy">
          <span>{t.installEyebrow}</span>
          <h2>{t.installTitle}</h2>
          <p>{t.installBody}</p>
          <a className="primary-cta" href={releaseUrl} target="_blank" rel="noreferrer">
            <Download aria-hidden="true" />
            {t.release}
            <ArrowRight className="cta-arrow" aria-hidden="true" />
          </a>
          <small>{t.requirement}</small>
        </div>
        <div className="terminal-card">
          <div className="terminal-top">
            <span><i /><i /><i /></span>
            <b>{t.copyHint}</b>
          </div>
          <pre><code><span>$</span> git clone https://github.com/qingtan-labs/GaugeForCodex.git{`\n`}<span>$</span> cd GaugeForCodex/quota-overlay{`\n`}<span>$</span> ./install.sh</code></pre>
          <div className="terminal-success"><Check /> Gauge for Codex · ready in your menu bar</div>
        </div>
      </section>

      <footer className="site-footer">
        <div className="footer-brand">
          <BrandMark />
          <div><strong>Gauge for Codex</strong><span>{t.footerLine}</span></div>
        </div>
        <div className="footer-links">
          <a href={repositoryUrl} target="_blank" rel="noreferrer">GitHub</a>
          <a href={`${repositoryUrl}/blob/main/PRIVACY.md`} target="_blank" rel="noreferrer">Privacy</a>
          <a href={`${repositoryUrl}/blob/main/LICENSE`} target="_blank" rel="noreferrer">MIT License</a>
        </div>
        <p>{t.disclaimer}</p>
      </footer>
    </main>
  );
}
