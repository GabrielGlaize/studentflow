(() => {
  const showToast = (message) => {
    document.querySelector('.prototype-toast')?.remove();
    const toast = document.createElement('div');
    toast.className = 'prototype-toast';
    toast.setAttribute('role', 'status');
    toast.textContent = message;
    document.body.appendChild(toast);
    requestAnimationFrame(() => toast.classList.add('visible'));
    window.setTimeout(() => {
      toast.classList.remove('visible');
      window.setTimeout(() => toast.remove(), 250);
    }, 2200);
  };

  window.studyFlowToast = showToast;

  const notice = new URLSearchParams(window.location.search).get('notice');
  if (notice) {
    const messages = {
      course: 'Cours ajouté à l’emploi du temps de la classe.',
      task: 'Tâche créée dans ton agenda.',
      joined: 'Tu as rejoint L2 Développement.'
    };
    window.setTimeout(() => showToast(messages[notice] || notice), 250);
    history.replaceState({}, '', window.location.pathname + window.location.hash);
  }

  document.querySelectorAll('[data-href]').forEach((element) => {
    element.addEventListener('click', () => { window.location.href = element.dataset.href; });
  });

  document.querySelectorAll('[data-demo-message]').forEach((element) => {
    element.addEventListener('click', (event) => {
      event.preventDefault();
      showToast(element.dataset.demoMessage);
    });
  });

  document.querySelectorAll('.task-row input[type="checkbox"]').forEach((checkbox) => {
    checkbox.addEventListener('change', () => checkbox.closest('.task-row').classList.toggle('completed', checkbox.checked));
  });

  const taskButtons = document.querySelectorAll('.agenda-item .task-check');
  taskButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const item = button.closest('.agenda-item');
      item.classList.toggle('completed');
      button.setAttribute('aria-label', item.classList.contains('completed') ? 'Remettre la tâche à faire' : 'Marquer la tâche terminée');
      button.textContent = item.classList.contains('completed') ? '✓' : '';
    });
  });

  const agendaFilters = document.querySelectorAll('.agenda-filters button');
  agendaFilters.forEach((filter, index) => {
    filter.addEventListener('click', () => {
      agendaFilters.forEach((item) => item.classList.toggle('active', item === filter));
      document.querySelectorAll('.agenda-panel.active .agenda-item').forEach((item) => {
        item.hidden = index === 0 ? item.classList.contains('completed') : !item.classList.contains('completed');
      });
      if (index === 1 && !document.querySelector('.agenda-panel.active .agenda-item.completed')) {
        showToast('Aucune tâche terminée pour le moment.');
      }
    });
  });

  if (window.location.hash === '#company-panel') {
    document.querySelector('.workspace-switch [data-target="company-panel"]')?.click();
  }

  const dayButtons = document.querySelectorAll('.week-picker .days button');
  const daySummary = document.querySelector('.day-summary');
  const dayData = {
    '22': ['Lundi 22 juin', '3 cours', '5 h de cours'],
    '23': ['Mardi 23 juin', '4 cours', '7 h de cours'],
    '24': ['Mercredi 24 juin', '2 cours', '3 h 30 de cours'],
    '25': ['Jeudi 25 juin', '4 cours', '6 h de cours'],
    '26': ['Vendredi 26 juin', '3 cours', '4 h 30 de cours']
  };
  dayButtons.forEach((button) => {
    button.addEventListener('click', () => {
      dayButtons.forEach((item) => {
        item.classList.toggle('active', item === button);
        item.removeAttribute('aria-current');
      });
      button.setAttribute('aria-current', 'date');
      const [label, count, duration] = dayData[button.querySelector('strong').textContent];
      daySummary.querySelector('.overline').textContent = label;
      daySummary.querySelector('h2').textContent = `${count} ce jour`;
      daySummary.querySelector('.day-duration').textContent = duration;
      showToast(`Aperçu du ${label.toLowerCase()}.`);
    });
  });

  const infoTabs = document.querySelectorAll('.info-filters [role="tab"]');
  infoTabs.forEach((tab, index) => {
    tab.addEventListener('click', () => {
      infoTabs.forEach((item) => {
        item.classList.toggle('active', item === tab);
        item.setAttribute('aria-selected', String(item === tab));
      });
      const recent = document.querySelector('.recent-section');
      if (recent) recent.hidden = index === 1;
    });
  });

  const copyButton = document.querySelector('.copy-code');
  copyButton?.addEventListener('click', async () => {
    const code = document.querySelector('.code-heading h2')?.textContent.replace('–', '-') || '';
    try { await navigator.clipboard.writeText(code); } catch (_) { /* Clipboard may be unavailable on file:// previews. */ }
    copyButton.textContent = 'Code copié ✓';
    showToast('Code de classe copié.');
    window.setTimeout(() => { copyButton.textContent = 'Copier le code'; }, 1800);
  });

  document.querySelector('[data-action="renew-code"]')?.addEventListener('click', () => {
    document.querySelector('.code-heading h2').textContent = 'L2DEV–9M6Q';
    document.querySelector('.code-card small').textContent = 'Renouvelé à l’instant par Camille';
    showToast('Nouveau code généré. L’ancien code est désactivé.');
  });

  const themeInputs = document.querySelectorAll('input[name="theme"]');
  themeInputs.forEach((input) => input.addEventListener('change', () => {
    const label = input.nextElementSibling.textContent;
    document.documentElement.dataset.theme = label === 'Sombre' ? 'dark' : '';
    showToast(`Thème ${label.toLowerCase()} appliqué.`);
  }));

  const reminderToggle = document.querySelector('.reminder-field')?.previousElementSibling?.querySelector('input[type="checkbox"]');
  const reminderField = document.querySelector('.reminder-field');
  reminderToggle?.addEventListener('change', () => { reminderField.hidden = !reminderToggle.checked; });

  const classCode = document.querySelector('.join-form input');
  classCode?.addEventListener('input', () => {
    const normalized = classCode.value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10);
    classCode.value = normalized;
    const valid = normalized.length >= 8;
    document.querySelector('.class-preview')?.toggleAttribute('hidden', !valid);
    document.querySelector('.join-details')?.toggleAttribute('hidden', !valid);
    const joinButton = document.querySelector('.join-button');
    if (joinButton) {
      joinButton.classList.toggle('disabled', !valid);
      joinButton.setAttribute('aria-disabled', String(!valid));
    }
  });

  document.querySelectorAll('[data-submit-target]').forEach((button) => {
    button.addEventListener('click', () => {
      const scope = button.closest('.auth-panel, .form-shell, .join-shell') || document;
      const requiredFields = [...scope.querySelectorAll('input[required], select[required]')];
      const invalid = requiredFields.find((field) => field.type === 'checkbox' ? !field.checked : !field.value.trim());
      if (invalid) {
        invalid.focus();
        showToast('Complète les champs obligatoires.');
        return;
      }
      window.location.href = button.dataset.submitTarget;
    });
  });
})();
