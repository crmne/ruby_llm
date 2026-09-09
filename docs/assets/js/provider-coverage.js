(() => {
  const root = document.querySelector('.coverage-explorer');
  if (!root) return;

  const current = root.dataset.current === 'true';
  const controls = root.querySelector('.coverage-controls');
  const version = root.querySelector('#coverage-version');
  const provider = root.querySelector('#coverage-provider');
  const group = root.querySelector('#coverage-group');
  const filter = root.querySelector('#coverage-filter');
  const dialog = root.querySelector('.coverage-dialog');
  const columns = root.querySelectorAll('th[data-provider], td[data-provider]');
  const rows = root.querySelectorAll('tr[data-feature]');
  let auditRequest;

  const loadAudit = () => {
    auditRequest ||= fetch(root.dataset.coverageUrl).then(response => {
      if (!response.ok) throw new Error('Could not load the audit data.');
      return response.json();
    }).catch(error => {
      auditRequest = null;
      throw error;
    });
    return auditRequest;
  };

  function update() {
    root.dataset.view = version.value;
    root.dataset.filter = filter.value;
    columns.forEach(cell => { cell.hidden = provider.value !== 'all' && cell.dataset.provider !== provider.value; });
    root.querySelectorAll('td[data-provider]').forEach(cell => {
      let state;
      if (version.value === 'offered') {
        state = cell.dataset.offered === 'true' ? 'offered' : cell.dataset.offered === 'false' ? 'na' : 'unknown';
      } else {
        state = cell.dataset[version.value === 'v1' ? 'v1' : 'v2'];
        if (state === 'native') state = version.value === 'compare' && cell.dataset.v1 !== 'native' ? 'added' : 'existing';
      }
      const link = cell.querySelector('.coverage-cell');
      link.dataset.status = state;
      link.querySelector('span').textContent = { na: '–', deprecated: '–', out_of_scope: '╱', unknown: '?', passthrough: '{}', missing: '×' }[state] || '';
      const offering = cell.dataset.offered === 'true' ? 'offered' : cell.dataset.offered === 'false' ? 'not documented in this API' : 'unverified';
      link.setAttribute('aria-label', `${link.title} Provider offering: ${offering}. View evidence.`);
    });
    root.querySelectorAll('[data-legend]').forEach(item => {
      const kind = item.dataset.legend;
      item.hidden = kind === 'support' ? version.value === 'offered'
        : kind === 'version' ? !['v1', 'v2'].includes(version.value)
          : kind !== version.value;
    });

    let count = 0;
    rows.forEach(row => {
      const cells = [...row.querySelectorAll('td')].filter(cell => !cell.hidden);
      const rowGroup = row.closest('tbody').dataset.group;
      const additional = ['additional', 'boundaries'].includes(rowGroup);
      const inGroup = group.value === 'all' || group.value === rowGroup || (group.value === 'shared' && !additional) || (group.value === 'extras' && additional);
      const matches = filter.value === 'all' || cells.some(cell => filter.value === 'changed'
        ? cell.dataset.v1 !== cell.dataset.v2
        : filter.value === 'unknown'
          ? [cell.dataset.v1, cell.dataset.v2, cell.dataset.offered].includes('unknown')
          : filter.value === 'missing'
            ? cell.dataset.v2 === 'missing'
            : filter.value === 'raw'
              ? cell.dataset.v2 === 'passthrough'
              : ['missing', 'partial'].includes(cell.dataset.v2));
      row.hidden = !inGroup || !matches;
      if (!row.hidden) count++;
    });
    root.querySelectorAll('tbody').forEach(body => {
      body.hidden = ![...body.querySelectorAll('tr[data-feature]')].some(row => !row.hidden);
      body.querySelector('th[colspan]').colSpan = provider.value === 'all' ? provider.options.length : 2;
    });
    const providers = provider.value === 'all' ? provider.options.length - 1 : 1;
    root.querySelector('.coverage-results').textContent = `${count} feature rows · ${providers} ${providers === 1 ? 'provider' : 'providers'} · ${version.selectedOptions[0].textContent}${filter.value === 'all' ? '' : ` · ${filter.selectedOptions[0].textContent}`}`;
    root.querySelector('.coverage-empty').hidden = count !== 0;
    root.querySelector('caption').textContent = `RubyLLM provider features: ${version.selectedOptions[0].textContent}. ${current && version.value === 'v2' ? 'Solid red: built-in support. ' : version.value === 'compare' ? 'Red: new built-in support in 2.0. Gray: already in 1.16. ' : ''}Lighter red with braces: usable through raw options. Red stripes: partial. Outlined cross: missing. Dash: not documented in this API. Diagonal stroke: outside scope. Select a cell for implementation notes and evidence.`;
  }

  function listLinks(target, entries) {
    target.replaceChildren(...entries.map(entry => {
      const li = document.createElement('li');
      const link = document.createElement('a');
      link.href = entry.url;
      link.textContent = entry.title;
      li.append(link);
      return li;
    }));
    if (!entries.length) {
      const li = document.createElement('li');
      li.textContent = 'No evidence recorded for this combination.';
      target.append(li);
    }
  }

  function showVerification(entries, audit) {
    const section = dialog.querySelector('.coverage-detail-validation');
    section.hidden = !entries.length;
    const labels = { passed: 'Live API passed', unit: 'Regression tested', unavailable: 'Live API unavailable' };
    section.querySelector('ul').replaceChildren(...entries.map(entry => {
      const item = document.createElement('li');
      const heading = document.createElement('strong');
      heading.textContent = [labels[entry.status] || entry.status, entry.recorded_on || entry.checked_on, entry.model].filter(Boolean).join(' · ');
      item.append(heading);
      if (entry.notes) {
        const notes = document.createElement('p');
        notes.textContent = entry.notes;
        item.append(notes);
      }
      if (entry.example) {
        const example = document.createElement('p');
        example.textContent = entry.example;
        item.append(example);
      }
      const evidence = [['Spec', entry.spec], ['Cassette', entry.cassette]].filter(([, path]) => path);
      evidence.forEach(([label, path], index) => {
        if (index) item.append(' · ');
        const link = document.createElement('a');
        link.href = `https://github.com/crmne/ruby_llm/blob/${audit.revision}/${path}`;
        link.textContent = `${label}: ${path}`;
        item.append(link);
      });
      return item;
    }));
  }

  root.addEventListener('click', async event => {
    const cellLink = event.target.closest('.coverage-cell');
    if (!cellLink || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    const title = dialog.querySelector('.coverage-detail-title');
    const notes = dialog.querySelector('.coverage-detail-notes');
    title.textContent = 'Loading feature details';
    notes.textContent = '';
    dialog.querySelector('.coverage-detail-status').textContent = '';
    dialog.querySelectorAll('ul').forEach(list => list.replaceChildren());
    dialog.querySelector('.coverage-detail-validation').hidden = true;
    dialog.showModal();

    try {
      const audit = await loadAudit();
      const selectedProvider = audit.providers.find(item => item.id === cellLink.dataset.provider);
      const feature = audit.features.find(item => item.id === cellLink.dataset.feature);
      const cell = selectedProvider.features[feature.id];
      title.textContent = `${selectedProvider.name}: ${feature.name}`;
      dialog.querySelector('.coverage-detail-status').textContent = current ? audit.statuses[cell?.v2 || 'unknown'].label : `1.16: ${audit.statuses[cell?.v1 || 'unknown'].label} → 2.0: ${audit.statuses[cell?.v2 || 'unknown'].label}`;
      notes.textContent = cell?.notes || 'This provider and feature were not assessed together.';
      showVerification(cell?.verification || [], audit);
      listLinks(dialog.querySelector('.coverage-detail-sources'), (cell?.sources || []).map(id => audit.sources[id]));
      listLinks(dialog.querySelector('.coverage-detail-code'), (cell?.code || []).filter(entry => !current || entry.version !== 'v1').map(entry => ({
        title: `${current ? 'Current' : entry.version === 'v1' ? '1.16' : '2.0'}: ${entry.path}${entry.method ? `#${entry.method}` : ''}`,
        url: `https://github.com/crmne/ruby_llm/blob/${entry.version === 'v1' ? '1.16.0' : audit.revision}/${entry.path}`
      })));
    } catch (error) {
      title.textContent = 'Feature details unavailable';
      notes.textContent = 'The audit data could not be loaded. Follow the provider documentation link below or try again.';
      listLinks(dialog.querySelector('.coverage-detail-sources'), [{ title: 'Provider documentation', url: cellLink.href }]);
    }
  });

  controls.addEventListener('change', update);
  controls.hidden = false;
  update();
})();
