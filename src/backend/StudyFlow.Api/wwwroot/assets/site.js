(() => {
  const root = document.documentElement;
  const savedTheme = window.localStorage.getItem('studyflow-web-theme');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const initialTheme = savedTheme || (prefersDark ? 'dark' : 'light');

  const setTheme = (theme) => {
    root.dataset.theme = theme;
    document.querySelectorAll('.theme-toggle').forEach((button) => {
      const isDark = theme === 'dark';
      button.setAttribute('aria-pressed', String(isDark));
      button.querySelector('.toggle-label').textContent = isDark ? 'Sombre' : 'Clair';
    });
    window.localStorage.setItem('studyflow-web-theme', theme);
  };

  setTheme(initialTheme);

  document.querySelectorAll('.theme-toggle').forEach((button) => {
    button.addEventListener('click', () => {
      setTheme(root.dataset.theme === 'dark' ? 'light' : 'dark');
    });
  });

  const header = document.querySelector('.site-header');
  const updateHeaderState = () => {
    header?.classList.toggle('is-scrolled', window.scrollY > 10);
  };
  updateHeaderState();
  window.addEventListener('scroll', updateHeaderState, {passive: true});

  const revealItems = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window) {
    const revealObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('visible');
        revealObserver.unobserve(entry.target);
      });
    }, {threshold: 0.16});

    revealItems.forEach((item) => revealObserver.observe(item));
  } else {
    revealItems.forEach((item) => item.classList.add('visible'));
  }

  const showToast = (message) => {
    document.querySelector('.toast')?.remove();
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.setAttribute('role', 'status');
    toast.textContent = message;
    document.body.appendChild(toast);
    requestAnimationFrame(() => toast.classList.add('visible'));
    window.setTimeout(() => toast.classList.remove('visible'), 2600);
  };

  if (document.body.dataset.page !== 'alternance') return;

  const demoOffers = [
    {
      source: 'demo',
      opportunityType: 'job',
      title: 'Développeur web full-stack en alternance',
      company: 'Nova Labs',
      location: 'Paris 11e',
      distanceKm: 3.4,
      publishedAt: new Date(Date.now() - 2 * 86400000).toISOString(),
      contractTypes: ['Apprentissage'],
      targetDiploma: 'Bac +3 à Bac +5',
      remoteMode: 'Hybride',
      summary:
        'Rejoins une petite équipe produit pour concevoir des interfaces utiles, développer des API et livrer des fonctionnalités complètes.',
      applicationUrl: 'https://labonnealternance.apprentissage.beta.gouv.fr',
    },
    {
      source: 'demo',
      opportunityType: 'job',
      title: 'Alternant développeur front-end Flutter',
      company: 'Atelier Tech',
      location: 'Boulogne-Billancourt',
      distanceKm: 8.1,
      publishedAt: new Date(Date.now() - 4 * 86400000).toISOString(),
      contractTypes: ['Apprentissage'],
      targetDiploma: 'Bac +2 à Bac +4',
      remoteMode: 'Sur site',
      summary:
        'Participe au développement d’applications mobiles Flutter et à la mise en place d’un design system partagé.',
      applicationUrl: 'https://labonnealternance.apprentissage.beta.gouv.fr',
    },
    {
      source: 'demo',
      opportunityType: 'spontaneous',
      title: 'Entreprise susceptible de recruter en développement',
      company: 'Pixel Vert',
      location: 'Montreuil',
      distanceKm: 9.6,
      publishedAt: null,
      contractTypes: [],
      targetDiploma: null,
      remoteMode: null,
      summary:
        'Cette entreprise a été identifiée comme ayant un potentiel d’embauche dans ton domaine.',
      applicationUrl: 'https://labonnealternance.apprentissage.beta.gouv.fr',
    },
  ];

  const escapeHtml = (value = '') =>
    String(value).replace(/[&<>"']/g, (character) => ({
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;',
    })[character]);

  const initialsFor = (value = 'SF') =>
    value
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0])
      .join('')
      .toUpperCase() || 'SF';

  const formatDistance = (value) => {
    if (value === null || value === undefined) return null;
    return `${Number(value).toLocaleString('fr-FR', {maximumFractionDigits: 1})} km`;
  };

  const formatPublishedAt = (value) => {
    if (!value) return null;
    const days = Math.max(0, Math.round((Date.now() - new Date(value).getTime()) / 86400000));
    if (days === 0) return 'Publiée aujourd’hui';
    if (days === 1) return 'Publiée hier';
    return `Publiée il y a ${days} jours`;
  };

  const renderOffer = (offer) => {
    const meta = [
      ...(offer.contractTypes || []),
      offer.targetDiploma,
      offer.remoteMode,
    ].filter(Boolean);
    const footer = [
      formatPublishedAt(offer.publishedAt),
      formatDistance(offer.distanceKm),
      offer.source,
    ].filter(Boolean);
    const isSpontaneous = offer.opportunityType === 'spontaneous';
    const url = offer.applicationUrl || 'https://labonnealternance.apprentissage.beta.gouv.fr';

    return `
      <article class="job-card">
        <div class="job-topline">
          <span class="company-logo">${escapeHtml(initialsFor(offer.company || offer.title))}</span>
          <div class="job-title">
            <span class="tag ${isSpontaneous ? 'tag-warm' : ''}">${isSpontaneous ? 'Candidature spontanée' : 'Offre'}</span>
            <h3>${escapeHtml(offer.title)}</h3>
            <p>${escapeHtml([offer.company, offer.location].filter(Boolean).join(' · ') || 'Entreprise')}</p>
          </div>
          <button class="favorite" type="button" aria-label="Ajouter aux favoris">♡</button>
        </div>
        <p class="job-summary">${escapeHtml(offer.summary || 'Consulte la source pour découvrir les détails de cette opportunité.')}</p>
        ${meta.length ? `<div class="job-meta">${meta.map((item) => `<span>${escapeHtml(item)}</span>`).join('')}</div>` : ''}
        <footer>
          <span>${escapeHtml(footer.join(' · ') || 'Source alternance')}</span>
          <a href="${escapeHtml(url)}" target="_blank" rel="noreferrer">Voir l’opportunité</a>
        </footer>
      </article>
    `;
  };

  const renderOffers = (offers) => {
    const list = document.querySelector('.result-list');
    if (!list) return;
    if (!offers.length) {
      list.innerHTML = `
        <article class="state-card">
          <h3>Aucune opportunité trouvée</h3>
          <p>Essaie un domaine plus large ou une autre ville.</p>
        </article>
      `;
      return;
    }

    list.innerHTML = offers.map(renderOffer).join('');
  };

  const searchOpportunities = async ({keywords, location, distanceKm}) => {
    const url = new URL('/api/v1/public/alternances', window.location.origin);
    url.searchParams.set('keywords', keywords);
    url.searchParams.set('distanceKm', distanceKm);
    if (location) url.searchParams.set('location', location);

    const response = await fetch(url);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  };

  const runSearch = async () => {
    const form = document.querySelector('.search-panel');
    const keywords = form.elements.keywords.value.trim() || 'alternance';
    const location = form.elements.location.value.trim() || 'France';
    const distanceKm = document.querySelector('input[name="distance"]:checked')?.value || '30';
    const title = document.querySelector('#results-title');
    const kicker = document.querySelector('.results-kicker');
    const list = document.querySelector('.result-list');

    kicker.textContent = `Résultats pour “${keywords}”`;
    title.textContent = `Recherche autour de ${location}`;
    list.innerHTML = `
      <article class="state-card">
        <h3>Recherche en cours</h3>
        <p>StudyFlow interroge les sources d’alternance disponibles.</p>
      </article>
    `;

    try {
      const offers = await searchOpportunities({keywords, location, distanceKm});
      renderOffers(offers);
      title.textContent = `${offers.length} opportunité${offers.length > 1 ? 's' : ''} autour de ${location}`;
      showToast('Résultats chargés depuis l’API StudyFlow.');
    } catch {
      renderOffers(demoOffers);
      title.textContent = `${demoOffers.length} opportunités de démonstration autour de ${location}`;
      showToast('API indisponible : démonstration affichée.');
    }
  };

  const form = document.querySelector('.search-panel');
  form?.addEventListener('submit', (event) => {
    event.preventDefault();
    runSearch();
    document.querySelector('#results').scrollIntoView({behavior: 'smooth'});
  });

  document.querySelectorAll('.quick-searches button').forEach((button) => {
    button.addEventListener('click', () => {
      form.elements.keywords.value = button.textContent.trim();
      form.requestSubmit();
    });
  });

  document.querySelector('.filter-mobile')?.addEventListener('click', () => {
    document.querySelector('.filters')?.classList.toggle('mobile-open');
  });

  document.querySelector('[data-reset-filters]')?.addEventListener('click', () => {
    document.querySelector('input[name="distance"][value="30"]').checked = true;
    document.querySelectorAll('.filters input[type="checkbox"]').forEach((input) => {
      input.checked = true;
    });
    runSearch();
  });

  document.addEventListener('click', (event) => {
    const button = event.target.closest('.favorite');
    if (!button) return;
    const saved = button.getAttribute('aria-pressed') !== 'true';
    button.setAttribute('aria-pressed', String(saved));
    button.textContent = saved ? '♥' : '♡';
    showToast(saved ? 'Offre ajoutée aux favoris.' : 'Offre retirée des favoris.');
  });

  runSearch();
})();
