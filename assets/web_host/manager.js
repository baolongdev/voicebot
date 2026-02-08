const managerHostStatus = document.getElementById('managerHostStatus');
const managerDocCount = document.getElementById('managerDocCount');
const managerKpiDocs = document.getElementById('managerKpiDocs');
const managerKpiSelected = document.getElementById('managerKpiSelected');
const managerKpiDraft = document.getElementById('managerKpiDraft');
const managerDocBody = document.getElementById('managerDocBody');
const managerFilterInput = document.getElementById('managerFilterInput');
const managerSortSelect = document.getElementById('managerSortSelect');
const managerRefreshBtn = document.getElementById('managerRefreshBtn');
const managerEditorMeta = document.getElementById('managerEditorMeta');
const managerKdocBadge = document.getElementById('managerKdocBadge');
const managerSelectedDoc = document.getElementById('managerSelectedDoc');
const managerLastModified = document.getElementById('managerLastModified');
const managerKdocView = document.getElementById('managerKdocView');
const managerImageGallery = document.getElementById('managerImageGallery');
const managerQueryInput = document.getElementById('managerQueryInput');
const managerTopKInput = document.getElementById('managerTopKInput');
const managerSearchBtn = document.getElementById('managerSearchBtn');
const managerSearchResults = document.getElementById('managerSearchResults');
const managerStatus = document.getElementById('managerStatus');

let docsCache = [];
let selectedName = '';
let selectedImages = [];
let imagePreviewModal = null;
let imagePreviewImage = null;
let imagePreviewTitle = null;
let imagePreviewMeta = null;

const KDOC_SECTION_ORDER = [
  'DOC_ID',
  'DOC_TYPE',
  'TITLE',
  'ALIASES',
  'KEYWORDS',
  'SUMMARY',
  'CONTENT',
  'SERVICES',
  'DAY_VISIT',
  'STAY_PACKAGE',
  'REGULATIONS',
  'USAGE',
  'FAQ',
  'SAFETY_NOTE',
  'LAST_UPDATED',
];

const KDOC_SECTION_GROUPS = [
  {
    title: 'Thông tin nhận diện',
    keys: ['DOC_ID', 'DOC_TYPE', 'TITLE', 'ALIASES', 'KEYWORDS'],
  },
  {
    title: 'Nội dung tri thức',
    keys: ['SUMMARY', 'CONTENT'],
  },
  {
    title: 'Dịch vụ & trải nghiệm',
    keys: ['SERVICES', 'DAY_VISIT', 'STAY_PACKAGE', 'REGULATIONS'],
  },
  {
    title: 'Hướng dẫn & lưu ý',
    keys: ['USAGE', 'FAQ', 'SAFETY_NOTE'],
  },
  {
    title: 'Theo dõi cập nhật',
    keys: ['LAST_UPDATED'],
  },
];

const KDOC_SECTION_LABELS = {
  DOC_ID: 'Mã tài liệu',
  DOC_TYPE: 'Loại tài liệu',
  TITLE: 'Tiêu đề',
  ALIASES: 'Tên gọi khác',
  KEYWORDS: 'Từ khóa',
  SUMMARY: 'Tóm tắt',
  CONTENT: 'Nội dung chính',
  SERVICES: 'Dịch vụ',
  DAY_VISIT: 'Gói trong ngày',
  STAY_PACKAGE: 'Gói lưu trú',
  REGULATIONS: 'Quy định',
  USAGE: 'Hướng dẫn',
  FAQ: 'Câu hỏi thường gặp',
  SAFETY_NOTE: 'Lưu ý',
  LAST_UPDATED: 'Cập nhật',
};

const KDOC_SECTION_HINTS = {
  DOC_TYPE: 'Giá trị hợp lệ: product | faq | policy | guide | info | company_profile',
};

function esc(text) {
  return String(text || '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function formatTimestamp(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(date);
}

function formatCharCount(value) {
  return (Number(value) || 0).toLocaleString('vi-VN') + ' ký tự';
}

function setStatus(message, tone) {
  if (!managerStatus) return;
  const normalizedTone = ['info', 'loading', 'ok', 'warn'].includes(tone) ? tone : 'info';
  managerStatus.textContent = message;
  managerStatus.className = 'status-line ' + normalizedTone;
}

function setHostStatus(message, tone) {
  if (!managerHostStatus) return;
  managerHostStatus.textContent = message;
  if (tone === 'ok') {
    managerHostStatus.className = 'metric-chip metric-chip-host is-running';
    return;
  }
  managerHostStatus.className = 'metric-chip metric-chip-host is-error';
}

function updateKpis() {
  if (managerKpiDocs) {
    managerKpiDocs.textContent = String(docsCache.length || 0);
  }
  if (managerKpiSelected) {
    managerKpiSelected.textContent = selectedName || 'Chưa chọn';
  }
  if (managerKpiDraft) {
    managerKpiDraft.textContent = 'Chỉ xem';
  }
}

function updateLastModified(value) {
  if (!managerLastModified) return;
  managerLastModified.textContent = 'Cập nhật lần cuối: ' + formatTimestamp(value);
}

function updateSelectedDocMeta(name, textLength) {
  if (managerSelectedDoc) {
    managerSelectedDoc.textContent = 'Tài liệu: ' + (name || 'Chưa chọn');
  }
  if (managerEditorMeta) {
    managerEditorMeta.textContent = formatCharCount(textLength || 0);
  }
}

function setKdocBadge(isValid) {
  if (!managerKdocBadge) return;
  managerKdocBadge.className = 'metric-chip ' + (isValid ? 'manager-kdoc-ok' : 'manager-kdoc-warn');
  managerKdocBadge.textContent = isValid ? 'KDOC: Hợp lệ' : 'KDOC: Cần chỉnh';
}

function resetManagerImageGallery(message) {
  selectedImages = [];
  if (!managerImageGallery) return;
  managerImageGallery.innerHTML =
    '<div class="image-card image-card-empty">' + esc(message || 'Chưa có ảnh cho tài liệu này.') + '</div>';
}

function renderManagerImageGallery() {
  if (!managerImageGallery) return;
  if (selectedImages.length === 0) {
    resetManagerImageGallery('Chưa có ảnh cho tài liệu này.');
    return;
  }

  managerImageGallery.innerHTML = selectedImages
    .map((item) => {
      const imageId = String(item.id || '');
      const fileName = esc(String(item.file_name || 'image'));
      const bytes = Number(item.bytes || 0).toLocaleString('vi-VN');
      const created = esc(formatTimestamp(item.created_at));
      const url = '/api/documents/image/content?id=' + encodeURIComponent(imageId);
      return (
        '<figure class="image-card image-card-remote">' +
        '<button class="image-preview-trigger image-card-image-wrap" type="button" ' +
        'data-image-preview-url="' + esc(url) + '" ' +
        'data-image-preview-title="' + fileName + '" ' +
        'data-image-preview-meta="' + created + ' • ' + bytes + ' bytes" ' +
        'aria-label="Xem ảnh lớn ' + fileName + '">' +
        '<img src="' + url + '" alt="' + fileName + '" loading="lazy" />' +
        '</button>' +
        '<figcaption class="image-card-caption">' +
        '<div class="image-card-title" title="' + fileName + '">' + fileName + '</div>' +
        '<div class="image-card-meta">' + created + ' • ' + bytes + ' bytes</div>' +
        '</figcaption>' +
        '</figure>'
      );
    })
    .join('');

  managerImageGallery.querySelectorAll('[data-image-preview-url]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const imageUrl = btn.getAttribute('data-image-preview-url') || '';
      const title = btn.getAttribute('data-image-preview-title') || 'Ảnh minh họa';
      const meta = btn.getAttribute('data-image-preview-meta') || '';
      openImagePreview(imageUrl, title, meta);
    });
  });
}

function ensureImagePreviewModal() {
  if (imagePreviewModal) {
    return;
  }
  const wrapper = document.createElement('div');
  wrapper.className = 'image-preview-modal is-hidden';
  wrapper.setAttribute('role', 'dialog');
  wrapper.setAttribute('aria-modal', 'true');
  wrapper.setAttribute('aria-label', 'Xem ảnh lớn');
  wrapper.innerHTML =
    '<div class="image-preview-panel">' +
    '<header class="image-preview-head">' +
    '<p class="image-preview-title" id="managerImagePreviewTitle">Xem ảnh</p>' +
    '<button class="image-preview-close" type="button" data-image-preview-close aria-label="Đóng ảnh">×</button>' +
    '</header>' +
    '<div class="image-preview-body">' +
    '<img id="managerImagePreviewImage" alt="" loading="eager" />' +
    '</div>' +
    '<p class="image-preview-meta" id="managerImagePreviewMeta"></p>' +
    '</div>';
  document.body.appendChild(wrapper);
  imagePreviewModal = wrapper;
  imagePreviewImage = wrapper.querySelector('#managerImagePreviewImage');
  imagePreviewTitle = wrapper.querySelector('#managerImagePreviewTitle');
  imagePreviewMeta = wrapper.querySelector('#managerImagePreviewMeta');

  wrapper.addEventListener('click', (event) => {
    const target = event.target;
    if (target === wrapper) {
      closeImagePreview();
      return;
    }
    if (target instanceof HTMLElement && target.hasAttribute('data-image-preview-close')) {
      closeImagePreview();
    }
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && imagePreviewModal && !imagePreviewModal.classList.contains('is-hidden')) {
      event.preventDefault();
      closeImagePreview();
    }
  });
}

function openImagePreview(url, title, meta) {
  ensureImagePreviewModal();
  if (!imagePreviewModal || !imagePreviewImage) {
    return;
  }
  imagePreviewImage.src = String(url || '');
  imagePreviewImage.alt = String(title || 'Ảnh minh họa');
  if (imagePreviewTitle) {
    imagePreviewTitle.textContent = String(title || 'Ảnh minh họa');
  }
  if (imagePreviewMeta) {
    imagePreviewMeta.textContent = String(meta || '');
  }
  imagePreviewModal.classList.remove('is-hidden');
  document.body.classList.add('image-preview-open');
}

function closeImagePreview() {
  if (!imagePreviewModal) {
    return;
  }
  imagePreviewModal.classList.add('is-hidden');
  document.body.classList.remove('image-preview-open');
  if (imagePreviewImage) {
    imagePreviewImage.src = '';
  }
}

async function req(url, options) {
  const retryCount = Number(options?.retryCount || 0);
  let lastError = null;
  for (let attempt = 0; attempt <= retryCount; attempt += 1) {
    try {
      const cleanOptions = { ...(options || {}) };
      delete cleanOptions.retryCount;
      const response = await fetch(url, cleanOptions);
      const payload = await response.json().catch(() => ({}));
      if (!response.ok || payload.ok === false) {
        throw new Error(payload.error || ('HTTP ' + response.status));
      }
      return payload;
    } catch (error) {
      lastError = error;
      if (attempt >= retryCount) break;
      await new Promise((resolve) => setTimeout(resolve, 250 * (attempt + 1)));
    }
  }
  throw lastError || new Error('Yêu cầu thất bại.');
}

function renderListState(message, isError) {
  if (!managerDocBody) return;
  const toneClass = isError ? ' error' : '';
  managerDocBody.innerHTML = '<div class="state-card' + toneClass + '">' + esc(message) + '</div>';
}

function parseKdocSections(text) {
  const normalized = String(text || '').replaceAll('\r\n', '\n').trim();
  const lines = normalized.split('\n');
  const start = lines.findIndex((line) => line.trim() === '=== KDOC:v1 ===');
  const end = [...lines].reverse().findIndex((line) => line.trim() === '=== END_KDOC ===');
  if (start < 0 || end < 0) {
    return null;
  }
  const endIndex = lines.length - 1 - end;
  if (endIndex <= start) {
    return null;
  }

  const sections = {};
  let currentKey = null;
  let buffer = [];
  const sectionPattern = /^\s*\[([A-Z_]+)\]\s*$/;

  const flush = () => {
    if (!currentKey) return;
    sections[currentKey] = buffer.join('\n').trim();
    buffer = [];
  };

  for (let i = start + 1; i < endIndex; i += 1) {
    const line = lines[i];
    const match = line.match(sectionPattern);
    if (match) {
      flush();
      currentKey = match[1];
      continue;
    }
    if (currentKey) {
      buffer.push(line);
    }
  }
  flush();
  return sections;
}

function validateKdoc(text) {
  const sections = parseKdocSections(text);
  if (!sections) {
    return {
      ok: false,
      sections: null,
      errors: ['Không nhận diện được định dạng KDOC v1 (thiếu marker đầu/cuối).'],
    };
  }

  const errors = [];
  const required = ['DOC_ID', 'DOC_TYPE', 'TITLE', 'ALIASES', 'SUMMARY', 'CONTENT', 'LAST_UPDATED'];
  required.forEach((key) => {
    if (!String(sections[key] || '').trim()) {
      errors.push(`Thiếu mục bắt buộc [${key}].`);
    }
  });

  const docType = String(sections.DOC_TYPE || '').trim().toLowerCase();
  if (docType && !['product', 'faq', 'policy', 'guide', 'info', 'company_profile'].includes(docType)) {
    errors.push('[DOC_TYPE] chỉ chấp nhận: product, faq, policy, guide, info, company_profile.');
  }

  const lastUpdated = String(sections.LAST_UPDATED || '').trim();
  if (lastUpdated && Number.isNaN(Date.parse(lastUpdated))) {
    errors.push('[LAST_UPDATED] phải là ngày hợp lệ (ISO-8601).');
  }

  return { ok: errors.length === 0, sections: sections, errors: errors };
}

function splitSectionLines(key, value) {
  if (!value) return [];
  if (key === 'ALIASES' || key === 'KEYWORDS') {
    return String(value)
      .split(/[\n|,;]+/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
  }
  return String(value)
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
}

function renderSectionContent(key, value) {
  const lines = splitSectionLines(key, value);
  if (lines.length === 0) {
    const hint = KDOC_SECTION_HINTS[key];
    return (
      '<p class="manager-kdoc-empty">Chưa có nội dung.</p>' +
      (hint ? '<p class="kdoc-field-hint">' + esc(hint) + '</p>' : '')
    );
  }
  const hint = KDOC_SECTION_HINTS[key];
  return (
    '<ul class="kdoc-lines">' +
    lines.map((line) => '<li>' + esc(line) + '</li>').join('') +
    '</ul>' +
    (hint ? '<p class="kdoc-field-hint">' + esc(hint) + '</p>' : '')
  );
}

function renderKdocView(rawText) {
  if (!managerKdocView) return;
  const text = String(rawText || '').trim();
  if (!text) {
    setKdocBadge(false);
    managerKdocView.innerHTML = 'Tài liệu trống.';
    return;
  }

  const validation = validateKdoc(text);
  setKdocBadge(validation.ok);

  if (!validation.sections) {
    managerKdocView.innerHTML =
      '<div class="state-card error">' +
      '<strong>Tài liệu chưa theo chuẩn KDOC v1.</strong><br/>' +
      esc(validation.errors.join(' ')) +
      '</div>';
    return;
  }

  const sections = validation.sections;
  const orderedKeys = KDOC_SECTION_ORDER.slice();
  Object.keys(sections).forEach((key) => {
    if (!orderedKeys.includes(key)) {
      orderedKeys.push(key);
    }
  });

  const renderedKeySet = new Set();
  const blocks = KDOC_SECTION_GROUPS.map((group) => {
    const cards = group.keys
      .filter((key) => orderedKeys.includes(key))
      .map((key) => {
        renderedKeySet.add(key);
        const label = KDOC_SECTION_LABELS[key] || key;
        return (
          '<article class="kdoc-card">' +
          '<h5>' + esc(label) + ' [' + esc(key) + ']</h5>' +
          renderSectionContent(key, sections[key]) +
          '</article>'
        );
      })
      .join('');
    if (!cards) return '';
    return (
      '<section class="kdoc-group">' +
      '<h5 class="kdoc-group-title">' + esc(group.title) + '</h5>' +
      '<div class="kdoc-grid">' + cards + '</div>' +
      '</section>'
    );
  }).filter((block) => block);

  const extraCards = Object.keys(sections)
    .filter((key) => !renderedKeySet.has(key))
    .map((key) => {
      const label = KDOC_SECTION_LABELS[key] || key;
      return (
        '<article class="kdoc-card">' +
        '<h5>' + esc(label) + ' [' + esc(key) + ']</h5>' +
        renderSectionContent(key, sections[key]) +
        '</article>'
      );
    })
    .join('');

  if (extraCards) {
    blocks.push(
      '<section class="kdoc-group">' +
      '<h5 class="kdoc-group-title">Mục mở rộng</h5>' +
      '<div class="kdoc-grid">' + extraCards + '</div>' +
      '</section>'
    );
  }

  managerKdocView.innerHTML = blocks.join('');
}

function renderDocuments(rows) {
  if (!managerDocBody) return;
  const keyword = String(managerFilterInput?.value || '').trim().toLowerCase();
  const sort = String(managerSortSelect?.value || 'updated_desc');

  const filtered = (Array.isArray(rows) ? rows : []).filter((doc) => {
    const name = String(doc.name || '').toLowerCase();
    return !keyword || name.includes(keyword);
  });

  filtered.sort((a, b) => {
    const aName = String(a.name || '');
    const bName = String(b.name || '');
    const aUpdated = String(a.updated_at || '');
    const bUpdated = String(b.updated_at || '');
    if (sort === 'name_asc') return aName.localeCompare(bName);
    if (sort === 'name_desc') return bName.localeCompare(aName);
    if (sort === 'updated_asc') return aUpdated.localeCompare(bUpdated);
    return bUpdated.localeCompare(aUpdated);
  });

  if (managerDocCount) {
    managerDocCount.textContent = 'Tổng: ' + filtered.length;
  }
  updateKpis();

  if (filtered.length === 0) {
    renderListState('Chưa có tài liệu phù hợp.', false);
    return;
  }

  managerDocBody.innerHTML = filtered
    .map((doc) => {
      const name = esc(doc.name || '');
      const updated = esc(formatTimestamp(doc.updated_at || ''));
      const chars = esc(formatCharCount(doc.characters || 0));
      const preview = esc(String(doc.snippet || '').replace(/\s+/g, ' ').trim()).slice(0, 140);
      const active = selectedName === doc.name ? ' active' : '';
      return (
        '<article class="note-item' + active + '" data-name="' + name + '" role="listitem" tabindex="0">' +
        '<div class="note-date">Cập nhật: ' + updated + ' • ' + chars + '</div>' +
        '<div class="note-title">' + name + '</div>' +
        '<div class="note-preview">' + (preview || 'Không có đoạn xem trước.') + '</div>' +
        '</article>'
      );
    })
    .join('');

  managerDocBody.querySelectorAll('.note-item[data-name]').forEach((el) => {
    const open = async () => {
      const name = el.getAttribute('data-name');
      if (!name) return;
      await loadDocument(name);
    };

    el.addEventListener('click', open);
    el.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        open();
      }
    });
  });
}

async function refreshDocuments(silentStatus) {
  renderListState('Đang tải danh sách tài liệu...');
  if (!silentStatus) {
    setStatus('Đang tải danh sách tài liệu...', 'loading');
  }
  const data = await req('/api/documents', { retryCount: 1 });
  docsCache = Array.isArray(data.documents) ? data.documents : [];
  renderDocuments(docsCache);
  if (!silentStatus) {
    setStatus('Đã cập nhật danh sách tài liệu.', 'ok');
  }
}

async function loadManagerImages(docName) {
  const name = String(docName || '').trim();
  if (!name) {
    resetManagerImageGallery('Chưa chọn tài liệu.');
    return;
  }
  try {
    const payload = await req('/api/documents/images?name=' + encodeURIComponent(name), {
      retryCount: 1,
    });
    selectedImages = Array.isArray(payload.images) ? payload.images : [];
    renderManagerImageGallery();
  } catch (_) {
    resetManagerImageGallery('Không tải được thư viện ảnh.');
  }
}

async function loadDocument(name) {
  setStatus('Đang tải nội dung tài liệu...', 'loading');
  const payload = await req('/api/documents/content?name=' + encodeURIComponent(name), { retryCount: 1 });
  const doc = payload.document || {};
  selectedName = String(doc.name || name || '');
  const content = String(doc.content || '');
  updateSelectedDocMeta(selectedName, content.length);
  updateLastModified(doc.updated_at || '-');
  renderKdocView(content);
  await loadManagerImages(selectedName);
  renderDocuments(docsCache);
  setStatus('Đã tải nội dung tài liệu.', 'ok');
}

async function refreshHostInfo() {
  try {
    const payload = await req('/info');
    const status = String(payload.status || 'unknown');
    if (status === 'running') {
      setHostStatus('Host: Đang chạy', 'ok');
    } else {
      setHostStatus('Host: ' + status, 'warn');
    }
  } catch (_) {
    setHostStatus('Host: Lỗi kết nối', 'warn');
  }
}

function bindShortcuts() {
  document.addEventListener('keydown', (event) => {
    if (!(event.ctrlKey || event.metaKey)) return;
    const key = String(event.key || '').toLowerCase();
    if (key === 'f') {
      event.preventDefault();
      managerFilterInput?.focus();
      managerFilterInput?.select();
    }
  });
}

function renderSearchResults(results) {
  if (!managerSearchResults) return;
  const rows = Array.isArray(results) ? results : [];
  if (rows.length === 0) {
    managerSearchResults.innerHTML = 'Không có kết quả phù hợp.';
    return;
  }

  const numericScores = rows
    .map((row) => Number(row.score))
    .filter((score) => Number.isFinite(score));
  const minScore = numericScores.length > 0 ? Math.min(...numericScores) : 0;
  const maxScore = numericScores.length > 0 ? Math.max(...numericScores) : 0;

  const scoreClassFor = (rawScore) => {
    const score = Number(rawScore);
    if (!Number.isFinite(score)) return 'search-score-neutral';
    if (maxScore <= minScore) return 'search-score-high';
    const ratio = (score - minScore) / (maxScore - minScore);
    if (ratio >= 0.66) return 'search-score-high';
    if (ratio >= 0.33) return 'search-score-mid';
    return 'search-score-low';
  };

  managerSearchResults.innerHTML = rows
    .map((row) => {
      const title = esc(row.title || '');
      const docType = esc(row.doc_type || '');
      const fieldHits = Array.isArray(row.field_hits) ? row.field_hits.join(', ') : '';
      const scoreClass = scoreClassFor(row.score);
      return (
        '<div class="search-row">' +
        '<div class="search-row-meta"><strong>' + esc(row.name) + '</strong> <span class="search-score ' + scoreClass + '">score: ' + esc(row.score) + '</span></div>' +
        (title ? '<div class="search-row-meta">Tiêu đề: <span>' + title + '</span></div>' : '') +
        (docType ? '<div class="search-row-meta">Loại: <span>' + docType + '</span></div>' : '') +
        (fieldHits ? '<div class="search-row-meta">Khớp theo: <span>' + esc(fieldHits) + '</span></div>' : '') +
        '<div class="search-row-snippet">' + esc(String(row.snippet || '').replace(/\s+/g, ' ').trim()) + '</div>' +
        '</div>'
      );
    })
    .join('');
}

async function runSearch() {
  const query = (managerQueryInput?.value || '').trim();
  if (!query) {
    if (managerSearchResults) {
      managerSearchResults.textContent = 'Vui lòng nhập truy vấn.';
    }
    return;
  }

  const topKRaw = Number(managerTopKInput?.value || 5);
  const topK = Math.min(10, Math.max(1, Number.isFinite(topKRaw) ? topKRaw : 5));
  if (managerTopKInput) {
    managerTopKInput.value = String(topK);
  }

  if (managerSearchResults) {
    managerSearchResults.textContent = 'Đang tìm kiếm...';
  }
  try {
    const payload = await req('/api/search', {
      method: 'POST',
      retryCount: 1,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: query, top_k: topK }),
    });
    renderSearchResults(payload.results);
  } catch (error) {
    if (managerSearchResults) {
      managerSearchResults.textContent = 'Lỗi tìm kiếm: ' + error.message;
    }
  }
}

function bindEvents() {
  managerRefreshBtn?.addEventListener('click', async () => {
    try {
      await refreshDocuments(false);
    } catch (error) {
      renderListState('Không tải được danh sách tài liệu: ' + error.message, true);
      setStatus('Không tải được danh sách: ' + error.message, 'warn');
    }
  });

  managerFilterInput?.addEventListener('input', () => {
    renderDocuments(docsCache);
  });

  managerSortSelect?.addEventListener('change', () => {
    renderDocuments(docsCache);
  });

  managerSearchBtn?.addEventListener('click', runSearch);

  managerQueryInput?.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      runSearch();
    }
  });
}

(async function boot() {
  bindEvents();
  bindShortcuts();
  updateSelectedDocMeta('', 0);
  updateLastModified('-');
  setKdocBadge(false);
  resetManagerImageGallery('Chưa chọn tài liệu.');
  updateKpis();
  await refreshHostInfo();
  try {
    await refreshDocuments(true);
    setStatus('Sẵn sàng.', 'info');
  } catch (error) {
    renderListState('Không tải được danh sách tài liệu: ' + error.message, true);
    setStatus('Không tải được danh sách: ' + error.message, 'warn');
  }
})();
