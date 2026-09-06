(() => {
  const catalog = document.querySelector('[data-model-catalog]');
  if (!catalog || catalog.dataset.ready) return;

  const find = (name) => catalog.querySelector(`[data-catalog-${name}]`);
  const body = find('rows');
  const records = Array.from(body.rows, (row) => {
    const model = JSON.parse(row.dataset.model);
    return { row, ...model, search: [model.name, model.id, model.provider, ...model.capabilities, ...model.modalities].join(' ').toLowerCase() };
  });
  const groupLabels = { provider: 'providers', capabilities: 'capabilities', modalities: 'modalities' };
  const selections = { provider: records[0]?.provider || '', capabilities: '', modalities: '' };
  const search = find('search');
  const filters = find('filters');
  let grouping = 'provider';
  let sort = 'name';
  let ascending = true;
  let page = 1;
  let pageSize = 25;

  const values = (model) => [].concat(model[grouping]);
  const matchesSearch = (model) => search.value.toLowerCase().trim().split(/\s+/).every((word) => model.search.includes(word));
  const number = (value) => value.toLocaleString('en-US');

  function updateFilters() {
    const counts = new Map();
    const searched = records.filter(matchesSearch);
    searched.forEach((model) => values(model).forEach((value) => counts.set(value, (counts.get(value) || 0) + 1)));
    const names = Array.from(new Set(records.flatMap(values))).sort((a, b) => a.localeCompare(b));
    const buttons = ['', ...names].map((name) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.dataset.groupValue = name;
      button.setAttribute('aria-pressed', String(selections[grouping] === name));
      const count = document.createElement('span');
      count.textContent = number(name ? counts.get(name) || 0 : searched.length);
      button.append(name || `All ${groupLabels[grouping]}`, count);
      return button;
    });
    filters.setAttribute('aria-label', `Filter by ${grouping === 'provider' ? 'provider' : grouping === 'capabilities' ? 'capability' : 'modality'}`);
    filters.replaceChildren(...buttons);
  }

  function compare(a, b) {
    const left = a[sort];
    const right = b[sort];
    if (left == null && right == null) return a.name.localeCompare(b.name);
    if (left == null) return 1;
    if (right == null) return -1;
    const result = typeof left === 'number' ? left - right : left.localeCompare(right, 'en', { numeric: true });
    return (ascending ? result : -result) || a.name.localeCompare(b.name) || a.provider.localeCompare(b.provider) || a.id.localeCompare(b.id);
  }

  function render() {
    const selection = selections[grouping];
    const matching = records.filter((model) => matchesSearch(model) && (!selection || values(model).includes(selection))).sort(compare);
    const pages = Math.max(1, Math.ceil(matching.length / pageSize));
    page = Math.min(page, pages);
    const start = (page - 1) * pageSize;
    body.replaceChildren(...matching.slice(start, start + pageSize).map((model) => model.row));
    find('heading').textContent = selection || `All ${groupLabels[grouping]}`;
    find('count').textContent = matching.length ? `${number(start + 1)}–${number(Math.min(start + pageSize, matching.length))} of ${number(matching.length)} models` : '0 models';
    find('empty').hidden = matching.length > 0;
    find('pagination').hidden = matching.length === 0;
    find('page').textContent = `Page ${number(page)} of ${number(pages)}`;
    find('previous').disabled = page === 1;
    find('next').disabled = page === pages;
    catalog.querySelectorAll('[data-sort]').forEach((button) => {
      const selected = button.dataset.sort === sort;
      button.parentElement.setAttribute('aria-sort', selected ? ascending ? 'ascending' : 'descending' : 'none');
      let arrow = button.querySelector('span');
      if (!arrow) {
        arrow = document.createElement('span');
        arrow.setAttribute('aria-hidden', 'true');
        button.append(arrow);
      }
      arrow.textContent = selected ? ascending ? ' ↑' : ' ↓' : ' ↕';
    });
  }

  catalog.querySelectorAll('[name="catalog-group"]').forEach((input) => {
    input.addEventListener('change', () => {
      grouping = input.value;
      page = 1;
      updateFilters();
      render();
    });
  });
  filters.addEventListener('click', (event) => {
    const button = event.target.closest('[data-group-value]');
    if (!button) return;
    selections[grouping] = button.dataset.groupValue;
    page = 1;
    filters.querySelectorAll('button').forEach((filter) => filter.setAttribute('aria-pressed', String(filter === button)));
    render();
  });
  search.addEventListener('input', () => {
    selections[grouping] = '';
    page = 1;
    updateFilters();
    render();
  });
  catalog.querySelectorAll('[data-sort]').forEach((button) => {
    button.disabled = false;
    button.addEventListener('click', () => {
      ascending = sort === button.dataset.sort ? !ascending : true;
      sort = button.dataset.sort;
      page = 1;
      render();
    });
  });
  find('page-size').addEventListener('change', (event) => {
    pageSize = Number(event.target.value);
    page = 1;
    render();
  });
  for (const [control, direction] of [['previous', -1], ['next', 1]]) {
    find(control).addEventListener('click', () => {
      page += direction;
      render();
    });
  }
  find('reset').addEventListener('click', () => {
    search.value = '';
    selections[grouping] = '';
    page = 1;
    updateFilters();
    render();
    search.focus();
  });
  const copy = catalog.querySelector('[data-copy-command]');
  if (navigator.clipboard) {
    copy.hidden = false;
    copy.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText('curl https://rubyllm.com/models.json');
        copy.textContent = 'Copied';
      } catch {
        copy.textContent = 'Select to copy';
        const selection = window.getSelection();
        const range = document.createRange();
        range.selectNodeContents(copy.previousElementSibling);
        selection.removeAllRanges();
        selection.addRange(range);
      }
      window.setTimeout(() => { copy.textContent = 'Copy'; }, 2000);
    });
  }
  updateFilters();
  render();
  find('controls').hidden = false;
  filters.hidden = false;
  catalog.dataset.ready = 'true';
})();
