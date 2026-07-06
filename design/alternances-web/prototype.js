(() => {
  const apiBase =
    new URLSearchParams(window.location.search).get('api') ||
    window.localStorage.getItem('studyflow-api-base') ||
    'http://127.0.0.1:5198';
  const demoOffers = [
    {
      source: 'demo',
      externalId: 'nova-labs-fullstack',
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
        'Rejoins une petite équipe produit pour concevoir des interfaces utiles, développer des API et apprendre à livrer des fonctionnalités complètes.',
      applicationUrl: 'offre.html',
    },
    {
      source: 'demo',
      externalId: 'atelier-tech-flutter',
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
        'Participe au développement d’applications mobiles Flutter et à la mise en place d’un design system partagé par plusieurs produits.',
      applicationUrl: 'offre.html',
    },
    {
      source: 'demo',
      externalId: 'pixel-vert-spontaneous',
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
      applicationUrl: 'offre.html',
    },
  ];

  const showToast = (message) => {
    document.querySelector('.prototype-toast')?.remove();
    const toast = document.createElement('div');
    toast.className = 'prototype-toast';
    toast.setAttribute('role', 'status');
    toast.textContent = message;
    document.body.appendChild(toast);
    requestAnimationFrame(() => toast.classList.add('visible'));
    window.setTimeout(() => toast.classList.remove('visible'), 2300);
  };

  const escapeHtml = (value = '') =>
    String(value).replace(/[&<>"']/g, (character) => {
      return {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;',
      }[character];
    });

  const formatDistance = (value) => {
    if (value === null || value === undefined) return null;
    return `${Number(value).toLocaleString('fr-FR', {
      maximumFractionDigits: 1,
    })} km`;
  };

  const formatPublishedAt = (value) => {
    if (!value) return null;
    const days = Math.max(
      0,
      Math.round((Date.now() - new Date(value).getTime()) / 86400000),
    );
    if (days === 0) return 'Publiée aujourd’hui';
    if (days === 1) return 'Publiée hier';
    return `Publiée il y a ${days} jours`;
  };

  const initialsFor = (value = 'SF') =>
    value
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part[0])
      .join('')
      .toUpperCase() || 'SF';

  const renderOffer = (offer, index = 0) => {
    const meta = [
      ...(offer.contractTypes || []),
      offer.targetDiploma,
      offer.remoteMode,
    ].filter(Boolean);
    const footer = [
      formatPublishedAt(offer.publishedAt),
      formatDistance(offer.distanceKm),
    ].filter(Boolean);
    const isSpontaneous = offer.opportunityType === 'spontaneous';
    const logoClass = ['logo-indigo', 'logo-green', 'logo-sand'][index % 3];
    const tagClass = isSpontaneous ? 'tag tag-warm' : 'tag tag-accent';
    const tagLabel = isSpontaneous ? 'Candidature spontanée' : 'Offre';
    const url = offer.applicationUrl || 'offre.html';

    return `
      <article class="job-card ${index === 0 ? 'featured' : ''} ${isSpontaneous ? 'spontaneous' : ''}">
        <div class="job-topline">
          <span class="company-logo ${logoClass}">${escapeHtml(initialsFor(offer.company || offer.title))}</span>
          <div class="job-title">
            <span class="${tagClass}">${tagLabel}</span>
            <h3>${escapeHtml(offer.title)}</h3>
            <p>${escapeHtml([offer.company, offer.location].filter(Boolean).join(' · ') || 'Entreprise')}</p>
          </div>
          <button class="favorite" type="button" aria-label="Ajouter aux favoris">♡</button>
        </div>
        <p class="job-summary">${escapeHtml(offer.summary || 'Consulte la source pour découvrir les détails de cette opportunité.')}</p>
        ${
          meta.length
            ? `<div class="job-meta">${meta.map((item) => `<span>${escapeHtml(item)}</span>`).join('')}</div>`
            : ''
        }
        <footer>
          <span>${escapeHtml(footer.join(' · ') || 'Source La bonne alternance')}</span>
          <a href="${escapeHtml(url)}" target="${url.startsWith('http') ? '_blank' : '_self'}" rel="noreferrer">Voir l’opportunité <span aria-hidden="true">→</span></a>
        </footer>
      </article>
    `;
  };

  const renderOffers = (offers) => {
    const list = document.querySelector('.result-list');
    if (!list) return;
    if (!offers.length) {
      list.innerHTML = `
        <article class="empty-results">
          <h3>Aucune opportunité trouvée</h3>
          <p>Essaie un domaine plus large ou une autre ville.</p>
        </article>
      `;
      return;
    }

    list.innerHTML = offers.map(renderOffer).join('');
  };

  const searchOpportunities = async ({keywords, location}) => {
    const url = new URL('/api/v1/public/alternances', apiBase);
    url.searchParams.set('keywords', keywords);
    if (location) url.searchParams.set('location', location);
    url.searchParams.set('distanceKm', '30');

    const response = await fetch(url);
    if (!response.ok) throw new Error(`Recherche impossible (${response.status})`);
    return response.json();
  };

  const runSearch = async ({keywords, location}) => {
    const title = document.querySelector('#results-title');
    const kicker = document.querySelector('.section-kicker');
    const list = document.querySelector('.result-list');

    if (kicker) kicker.textContent = `Résultats pour “${keywords}”`;
    if (title) title.textContent = `Recherche autour de ${location || 'France'}`;
    if (list) {
      list.innerHTML = `
        <article class="loading-results">
          <span class="loader-dot"></span>
          <div>
            <h3>Recherche en cours…</h3>
            <p>On interroge l’API StudyFlow / La bonne alternance.</p>
          </div>
        </article>
      `;
    }

    try {
      const offers = await searchOpportunities({keywords, location});
      renderOffers(offers);
      if (title) {
        title.textContent = `${offers.length} opportunité${offers.length > 1 ? 's' : ''} autour de ${location || 'France'}`;
      }
      showToast('Résultats chargés depuis l’API.');
    } catch (error) {
      renderOffers(demoOffers);
      if (title) {
        title.textContent = `${demoOffers.length} opportunités de démonstration autour de ${location || 'France'}`;
      }
      showToast('Backend indisponible : résultats de démonstration affichés.');
    }
  };

  document.querySelectorAll('[data-demo-message]').forEach((element) => {
    element.addEventListener('click', (event) => {
      event.preventDefault();
      showToast(element.dataset.demoMessage);
    });
  });

  const searchForm = document.querySelector('.search-panel');
  searchForm?.addEventListener('submit', (event) => {
    event.preventDefault();
    const job =
      searchForm.querySelector('[aria-label="Métier ou domaine"]').value.trim() ||
      'Toutes les alternances';
    const place =
      searchForm.querySelector('[aria-label="Localisation"]').value.trim() ||
      'France';
    runSearch({keywords: job, location: place});
    document.querySelector('#results').scrollIntoView({behavior: 'smooth'});
  });

  document.querySelectorAll('.quick-searches button').forEach((button) => {
    button.addEventListener('click', () => {
      document.querySelector('[aria-label="Métier ou domaine"]').value = button.textContent;
      searchForm?.requestSubmit();
    });
  });

  document.addEventListener('click', (event) => {
    const button = event.target.closest('.favorite');
    if (button) {
      const saved = button.getAttribute('aria-pressed') !== 'true';
      button.setAttribute('aria-pressed', String(saved));
      button.textContent = saved ? '♥' : '♡';
      button.setAttribute('aria-label', saved ? 'Retirer des favoris' : 'Ajouter aux favoris');
      showToast(saved ? 'Offre ajoutée aux favoris.' : 'Offre retirée des favoris.');
    }
  });

  const detailFavorite = document.querySelector('.detail-favorite');
  detailFavorite?.addEventListener('click', () => {
    const saved = detailFavorite.getAttribute('aria-pressed') !== 'true';
    detailFavorite.setAttribute('aria-pressed', String(saved));
    detailFavorite.textContent = saved ? '♥ Ajoutée aux favoris' : '♡ Ajouter aux favoris';
    showToast(saved ? 'Offre ajoutée aux favoris.' : 'Offre retirée des favoris.');
  });

  const filters = document.querySelector('.filters');
  document.querySelector('.filter-mobile')?.addEventListener('click', () => {
    filters.classList.toggle('mobile-open');
    filters.scrollIntoView({behavior: 'smooth', block: 'start'});
  });

  document.querySelector('.filter-header button')?.addEventListener('click', () => {
    filters.querySelectorAll('input[type="radio"], input[type="checkbox"]').forEach((input) => { input.checked = false; });
    filters.querySelector('select').selectedIndex = 0;
    document.querySelector('.active-filters').innerHTML = '';
    document.querySelector('.filter-count').textContent = '0';
    showToast('Filtres réinitialisés.');
  });

  document.querySelectorAll('.active-filters button').forEach((button) => {
    button.addEventListener('click', () => {
      button.remove();
      document.querySelector('.filter-count').textContent = document.querySelectorAll('.active-filters button').length;
    });
  });

  document.querySelector('.load-more')?.addEventListener('click', (event) => {
    const list = document.querySelector('.result-list');
    const clones = [...list.children].slice(0, 2).map((card) => card.cloneNode(true));
    clones.forEach((card) => {
      card.classList.remove('featured');
      card.querySelector('.tag')?.replaceChildren(document.createTextNode('Plus ancienne'));
      list.appendChild(card);
    });
    event.currentTarget.textContent = 'Tous les résultats de la démo sont affichés';
    event.currentTarget.disabled = true;
    showToast('2 résultats supplémentaires affichés.');
  });

  renderOffers(demoOffers);
})();
