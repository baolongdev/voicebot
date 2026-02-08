const hostStatus = document.getElementById('hostStatus');
const docCountHero = document.getElementById('docCountHero');
const docName = document.getElementById('docName');
const docFileMirror = document.getElementById('docFileMirror');
const openDocFileBtn = document.getElementById('openDocFileBtn');
const imageFileInput = document.getElementById('imageFileInput');
const imageGrid = document.getElementById('imageGrid');
const imageDropZone = document.getElementById('imageDropZone');
const pickImageBtn = document.getElementById('pickImageBtn');
const imageUploadStatus = document.getElementById('imageUploadStatus');
const insertImageBtn = document.getElementById('insertImageBtn');
const docText = document.getElementById('docText');
const uploadBtn = document.getElementById('uploadBtn');
const refreshBtn = document.getElementById('refreshBtn');
const clearBtn = document.getElementById('clearBtn');
const exportAllBtn = document.getElementById('exportAllBtn');
const importAllBtn = document.getElementById('importAllBtn');
const importAllInput = document.getElementById('importAllInput');
const exportIncludeImages = document.getElementById('exportIncludeImages');
const importIncludeImages = document.getElementById('importIncludeImages');
const dataTabButtons = document.querySelectorAll('[data-data-tab]');
const dataTabPanels = document.querySelectorAll('[data-data-panel]');
const uploadStatus = document.getElementById('uploadStatus');
const docCount = document.getElementById('docCount');
const docBody = document.getElementById('docBody');
const docFilterInput = document.getElementById('docFilterInput');
const sidebarSearch = document.getElementById('sidebarSearch');
const docSortSelect = document.getElementById('docSortSelect');
const docPreviewTitle = document.getElementById('docPreviewTitle');
const docPreviewContent = document.getElementById('docPreviewContent');
const kdocOutlineBody = document.getElementById('kdocOutlineBody');
const textEditorBlock = document.getElementById('textEditorBlock');
const kdocOutlineBlock = document.getElementById('kdocOutlineBlock');
const viewTextBtn = document.getElementById('viewTextBtn');
const viewKdocBtn = document.getElementById('viewKdocBtn');
const templateButtons = document.querySelectorAll('.template-insert');
const newNoteBtn = document.getElementById('newNoteBtn');
const lastModifiedLabel = document.getElementById('lastModifiedLabel');
const addFolderBtn = document.getElementById('addFolderBtn');
const folderList = document.getElementById('folderList');
const docFolderSelect = document.getElementById('docFolderSelect');
const docTagsList = document.getElementById('docTagsList');
const docTagInput = document.getElementById('docTagInput');
const addDocTagBtn = document.getElementById('addDocTagBtn');
const MAX_IMAGE_UPLOAD_MB = Number(window.__WEB_HOST_MAX_IMAGE_UPLOAD_MB__) > 0
  ? Number(window.__WEB_HOST_MAX_IMAGE_UPLOAD_MB__)
  : 15;
const MAX_IMAGE_UPLOAD_BYTES = MAX_IMAGE_UPLOAD_MB * 1024 * 1024;
const appModal = document.getElementById('appModal');
const appModalTitle = document.getElementById('appModalTitle');
const appModalMessage = document.getElementById('appModalMessage');
const appModalInputWrap = document.getElementById('appModalInputWrap');
const appModalInput = document.getElementById('appModalInput');
const appModalCancel = document.getElementById('appModalCancel');
const appModalConfirm = document.getElementById('appModalConfirm');

let documentsCache = [];
let selectedDocName = '';
let listScrollTop = 0;
let documentImages = [];
let isUploadingImage = false;
let imageFetchTimer = null;
let draftTimer = null;
let isDirty = false;
let isSaving = false;
let lastSavedSnapshot = '';
let activeFolder = '__ALL__';
let draggedDocName = '';
let pendingFolderSelection = 'Mặc định';
let folderState = {
  folders: ['Mặc định'],
  assignments: {},
};
let noteTagState = {};
let activeModalResolve = null;
let activeModalInput = false;
let modalPreviousFocus = null;
let imagePreviewModal = null;
let imagePreviewImage = null;
let imagePreviewTitle = null;
let imagePreviewMeta = null;
const saveButtonDefaultLabel = uploadBtn ? uploadBtn.textContent : 'Lưu tài liệu';

const DRAFT_KEY = 'voicebot.webhost.editor.draft.v1';
const VIEW_MODE_KEY = 'voicebot.webhost.editor.view_mode.v1';
const FOLDER_STATE_KEY = 'voicebot.webhost.folder_state.v1';
const TAG_STATE_KEY = 'voicebot.webhost.tag_state.v1';
const EXPORT_SCHEMA = 'voicebot_webhost_export_v2';
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
  FAQ: 'FAQ',
  SAFETY_NOTE: 'Lưu ý',
  LAST_UPDATED: 'Cập nhật',
};

const KDOC_SECTION_HINTS = {
  DOC_ID: 'Định danh duy nhất, ví dụ: tinh_dau_chanh_chavi',
  DOC_TYPE: 'Giá trị hợp lệ: product | faq | policy | guide | info | company_profile',
  TITLE: 'Tên hiển thị chính thức của tài liệu',
  ALIASES: 'Tên gọi khác, phân tách bằng dấu | hoặc xuống dòng',
  KEYWORDS: 'Từ khóa hỗ trợ tìm kiếm, phân tách bằng dấu phẩy',
  SUMMARY: 'Tóm tắt ngắn gọn 1-3 câu',
  CONTENT: 'Thông tin chi tiết, có thể dùng dạng gạch đầu dòng',
  SERVICES: 'Liệt kê dịch vụ/hoạt động nổi bật (gạch đầu dòng).',
  DAY_VISIT: 'Thông tin gói trải nghiệm trong ngày.',
  STAY_PACKAGE: 'Thông tin gói lưu trú (phòng/lều, dịch vụ kèm theo).',
  REGULATIONS: 'Quy định khi tham gia dịch vụ.',
  USAGE: 'Hướng dẫn sử dụng hoặc thao tác',
  FAQ: 'Cặp câu hỏi / trả lời thường gặp',
  SAFETY_NOTE: 'Lưu ý quan trọng và giới hạn nội dung',
  LAST_UPDATED: 'Ngày cập nhật theo ISO-8601, ví dụ: 2026-02-08',
};

const KDOC_SECTION_PLACEHOLDERS = {
  DOC_ID: 'vd: bot_chanh_chavi_400g',
  DOC_TYPE: 'product',
  TITLE: 'Tên tài liệu',
  ALIASES: 'Tên gọi khác 1 | Tên gọi khác 2',
  KEYWORDS: 'từ khóa 1, từ khóa 2',
  SUMMARY: 'Nhập tóm tắt ngắn...',
  CONTENT: 'Nhập nội dung chi tiết...',
  SERVICES: 'Ví dụ: - Tham quan, chụp hình ...',
  DAY_VISIT: 'Ví dụ: - Vé combo ...',
  STAY_PACKAGE: 'Ví dụ: - Hình thức lưu trú ...',
  REGULATIONS: 'Ví dụ: - Mặc áo phao ...',
  USAGE: 'Nhập cách dùng...',
  FAQ: 'Q: ...\nA: ...',
  SAFETY_NOTE: 'Lưu ý an toàn / phạm vi thông tin',
  LAST_UPDATED: new Date().toISOString().split('T')[0],
};

const KDOC_SINGLE_LINE_KEYS = new Set(['DOC_ID', 'DOC_TYPE', 'TITLE', 'LAST_UPDATED']);

const templateMap = {
  product: `=== KDOC:v1 ===
[DOC_ID]
product_new

[DOC_TYPE]
product

[TITLE]
Tên sản phẩm

[ALIASES]
tên gọi khác 1 | tên gọi khác 2

[KEYWORDS]
từ khóa 1, từ khóa 2

[SUMMARY]
Mô tả ngắn 1-2 câu.

[CONTENT]
- Ưu điểm:
- Thành phần:
- Xuất xứ:
- Hạn sử dụng:

[USAGE]
- Cách dùng:

[FAQ]
Q: ...
A: ...

[SAFETY_NOTE]
Không khẳng định tác dụng y tế.

[LAST_UPDATED]
${new Date().toISOString().split('T')[0]}
=== END_KDOC ===`,
  faq: `=== KDOC:v1 ===
[DOC_ID]
faq_new

[DOC_TYPE]
faq

[TITLE]
Bộ câu hỏi thường gặp

[ALIASES]
faq | hoi dap

[KEYWORDS]
hỏi đáp, khách hàng

[SUMMARY]
Danh sách câu hỏi thường gặp và câu trả lời ngắn gọn.

[CONTENT]
Q: ...
A: ...

[FAQ]
Q: ...
A: ...

[LAST_UPDATED]
${new Date().toISOString().split('T')[0]}
=== END_KDOC ===`,
  policy: `=== KDOC:v1 ===
[DOC_ID]
policy_new

[DOC_TYPE]
policy

[TITLE]
Chính sách

[ALIASES]
chinh sach | policy

[KEYWORDS]
vận chuyển, đổi trả, thanh toán

[SUMMARY]
Thông tin chính sách áp dụng cho khách hàng.

[CONTENT]
- Vận chuyển:
- Thanh toán:
- Đổi trả:

[LAST_UPDATED]
${new Date().toISOString().split('T')[0]}
=== END_KDOC ===`,
  info: `=== KDOC:v1 ===
[DOC_ID]
info_new

[DOC_TYPE]
info

[TITLE]
Thông tin

[ALIASES]
thong tin | info

[KEYWORDS]
thông tin, hướng dẫn

[SUMMARY]
Thông tin tổng quan ngắn gọn.

[CONTENT]
- Điểm chính 1
- Điểm chính 2

[USAGE]
- Hướng dẫn liên quan (nếu có)

[FAQ]
Q: ...
A: ...

[SAFETY_NOTE]
Không khẳng định tác dụng y tế.

[LAST_UPDATED]
${new Date().toISOString().split('T')[0]}
=== END_KDOC ===`,
  company_profile: `=== KDOC:v1 ===
[DOC_ID]
company_profile_new

[DOC_TYPE]
company_profile

[TITLE]
Hồ sơ doanh nghiệp

[ALIASES]
tên gọi khác 1 | tên gọi khác 2

[KEYWORDS]
doanh nghiệp, giới thiệu, hồ sơ

[SUMMARY]
Tóm tắt ngắn gọn về đơn vị.

[CONTENT]
- Thông tin tổng quan
- Lịch sử hình thành

[SERVICES]
- Dịch vụ nổi bật

[DAY_VISIT]
- Gói trải nghiệm trong ngày (nếu có)

[STAY_PACKAGE]
- Gói lưu trú (nếu có)

[REGULATIONS]
- Quy định/ lưu ý khi tham gia

[USAGE]
- Hướng dẫn liên hệ/đăng ký

[FAQ]
Q: ...
A: ...

[SAFETY_NOTE]
Không khẳng định tác dụng y tế.

[LAST_UPDATED]
${new Date().toISOString().split('T')[0]}
=== END_KDOC ===`,
  synonyms: `[ALIASES]
Cha vi | Chavi | Chanh Việt | Tranh Việt | Chai vi | Trà vi`,
};

function esc(text) {
  return String(text || '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function sanitizeTag(tag) {
  return String(tag || '')
    .trim()
    .replace(/\s+/g, ' ')
    .slice(0, 32);
}

function normalizeTagList(tags) {
  const list = Array.isArray(tags) ? tags : [];
  const unique = [];
  list.forEach((tag) => {
    const normalized = sanitizeTag(tag);
    if (!normalized) return;
    const exists = unique.some((item) => item.toLowerCase() === normalized.toLowerCase());
    if (!exists) {
      unique.push(normalized);
    }
  });
  return unique.slice(0, 8);
}

function formatTimestamp(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
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
  const amount = Number(value) || 0;
  return amount.toLocaleString('vi-VN') + ' ký tự';
}

function hasModalUI() {
  return !!(appModal && appModalTitle && appModalMessage && appModalCancel && appModalConfirm);
}

function closeModal(payload) {
  if (!hasModalUI()) return;
  const resolver = activeModalResolve;
  activeModalResolve = null;
  appModal.classList.add('is-hidden');
  document.body.classList.remove('modal-open');
  if (appModalInput) {
    appModalInput.value = '';
  }
  if (modalPreviousFocus && typeof modalPreviousFocus.focus === 'function') {
    modalPreviousFocus.focus();
  }
  modalPreviousFocus = null;
  if (resolver) {
    resolver(payload || { confirmed: false, value: '' });
  }
}

function showModal(options) {
  const config = options || {};
  if (!hasModalUI()) {
    return Promise.resolve({ confirmed: false, value: '' });
  }

  if (activeModalResolve) {
    closeModal({ confirmed: false, value: '' });
  }

  modalPreviousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null;
  activeModalInput = config.mode === 'prompt';
  appModalTitle.textContent = String(config.title || 'Xác nhận thao tác');
  appModalMessage.textContent = String(config.message || '');
  appModalCancel.textContent = String(config.cancelText || 'Hủy');
  appModalConfirm.textContent = String(config.confirmText || 'Xác nhận');
  appModalConfirm.className = config.confirmTone === 'danger'
    ? 'btn btn-modal-danger'
    : 'btn btn-primary';

  if (activeModalInput && appModalInputWrap && appModalInput) {
    appModalInputWrap.classList.remove('is-hidden');
    appModalInput.value = String(config.defaultValue || '');
    appModalInput.placeholder = String(config.placeholder || '');
    appModalInput.setAttribute('aria-label', String(config.inputLabel || 'Nội dung nhập vào'));
  } else if (appModalInputWrap && appModalInput) {
    appModalInputWrap.classList.add('is-hidden');
    appModalInput.value = '';
  }

  appModal.classList.remove('is-hidden');
  document.body.classList.add('modal-open');

  return new Promise((resolve) => {
    activeModalResolve = resolve;
    setTimeout(() => {
      if (activeModalInput && appModalInput) {
        appModalInput.focus();
        appModalInput.select();
      } else {
        appModalConfirm.focus();
      }
    }, 0);
  });
}

async function showConfirm(message, options) {
  if (!hasModalUI()) {
    return window.confirm(String(message || 'Xác nhận thao tác?'));
  }
  const result = await showModal({
    mode: 'confirm',
    title: options?.title || 'Xác nhận thao tác',
    message: message,
    confirmText: options?.confirmText || 'Đồng ý',
    cancelText: options?.cancelText || 'Hủy',
    confirmTone: options?.confirmTone || 'primary',
  });
  return !!result.confirmed;
}

async function showPrompt(message, options) {
  if (!hasModalUI()) {
    return window.prompt(String(message || 'Nhập thông tin'), String(options?.defaultValue || '')) || '';
  }
  const result = await showModal({
    mode: 'prompt',
    title: options?.title || 'Nhập thông tin',
    message: message,
    confirmText: options?.confirmText || 'Lưu',
    cancelText: options?.cancelText || 'Hủy',
    defaultValue: options?.defaultValue || '',
    placeholder: options?.placeholder || '',
    inputLabel: options?.inputLabel || 'Nội dung nhập',
  });
  if (!result.confirmed) {
    return '';
  }
  return String(result.value || '');
}

function bindModalEvents() {
  if (!hasModalUI()) return;

  appModalCancel.addEventListener('click', function () {
    closeModal({ confirmed: false, value: '' });
  });

  appModalConfirm.addEventListener('click', function () {
    const value = activeModalInput && appModalInput ? appModalInput.value : '';
    closeModal({ confirmed: true, value: value });
  });

  appModal.addEventListener('click', function (event) {
    if (event.target === appModal) {
      closeModal({ confirmed: false, value: '' });
    }
  });

  appModal.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') {
      event.preventDefault();
      closeModal({ confirmed: false, value: '' });
      return;
    }
    if (event.key === 'Enter' && activeModalInput && appModalInput && event.target === appModalInput) {
      event.preventDefault();
      closeModal({ confirmed: true, value: appModalInput.value });
    }
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
    '<p class="image-preview-title" id="imagePreviewTitle">Xem ảnh</p>' +
    '<button class="image-preview-close" type="button" data-image-preview-close aria-label="Đóng ảnh">×</button>' +
    '</header>' +
    '<div class="image-preview-body">' +
    '<img id="imagePreviewImage" alt="" loading="eager" />' +
    '</div>' +
    '<p class="image-preview-meta" id="imagePreviewMeta"></p>' +
    '</div>';
  document.body.appendChild(wrapper);
  imagePreviewModal = wrapper;
  imagePreviewImage = wrapper.querySelector('#imagePreviewImage');
  imagePreviewTitle = wrapper.querySelector('#imagePreviewTitle');
  imagePreviewMeta = wrapper.querySelector('#imagePreviewMeta');

  wrapper.addEventListener('click', function (event) {
    const target = event.target;
    if (target === wrapper) {
      closeImagePreview();
      return;
    }
    if (target instanceof HTMLElement && target.hasAttribute('data-image-preview-close')) {
      closeImagePreview();
    }
  });

  document.addEventListener('keydown', function (event) {
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

function saveTagState() {
  localStorage.setItem(TAG_STATE_KEY, JSON.stringify(noteTagState));
}

function loadTagState() {
  try {
    const raw = localStorage.getItem(TAG_STATE_KEY);
    const parsed = raw ? JSON.parse(raw) : {};
    noteTagState = normalizeTagStateMap(parsed);
  } catch (_) {
    noteTagState = {};
  }
}

function normalizeTagStateMap(raw) {
  const normalized = {};
  if (!raw || typeof raw !== 'object') {
    return normalized;
  }
  Object.keys(raw).forEach((docName) => {
    const safeName = String(docName || '').trim();
    if (!safeName) return;
    normalized[safeName] = normalizeTagList(raw[docName]);
  });
  return normalized;
}

function getDocTags(docName, fallbackDoc, ensurePersist) {
  const safeName = String(docName || '').trim();
  if (!safeName) return [];
  if (Array.isArray(noteTagState[safeName]) && noteTagState[safeName].length > 0) {
    return noteTagState[safeName];
  }
  const inferred = deriveTags(fallbackDoc || { name: safeName });
  const normalized = normalizeTagList(inferred);
  if (ensurePersist) {
    noteTagState[safeName] = normalized;
    saveTagState();
  }
  return normalized;
}

function setDocTags(docName, tags) {
  const safeName = String(docName || '').trim();
  if (!safeName) return;
  noteTagState[safeName] = normalizeTagList(tags);
  saveTagState();
}

function moveDocTagsAssignment(oldName, newName) {
  const oldSafe = String(oldName || '').trim();
  const newSafe = String(newName || '').trim();
  if (!newSafe) return;
  if (oldSafe && noteTagState[oldSafe] && oldSafe !== newSafe) {
    noteTagState[newSafe] = normalizeTagList(noteTagState[oldSafe]);
    delete noteTagState[oldSafe];
    saveTagState();
    return;
  }
  if (!noteTagState[newSafe]) {
    setDocTags(newSafe, deriveTags({ name: newSafe }));
  }
}

function getCurrentTagDocName() {
  const selected = String(selectedDocName || '').trim();
  if (selected) return selected;
  const draft = String(docName?.value || '').trim();
  return draft;
}

function renderDocTagEditor() {
  if (!docTagsList) return;
  const docForTags = getCurrentTagDocName();
  if (!docForTags) {
    docTagsList.innerHTML = '<span class="tag-pill tag-empty">Chưa có tài liệu để gán nhãn</span>';
    return;
  }

  const tags = getDocTags(docForTags, { name: docForTags }, false);
  if (tags.length === 0) {
    docTagsList.innerHTML = '<span class="tag-pill tag-empty">Chưa có nhãn</span>';
    return;
  }

  docTagsList.innerHTML = tags
    .map((tag) => {
      const safeTag = esc(tag);
      return (
        '<span class="tag-pill tag-editable">' +
        '<button class="tag-text-btn" type="button" data-tag-edit="' + safeTag + '" aria-label="Sửa nhãn ' + safeTag + '">' + safeTag + '</button>' +
        '<button class="tag-remove-btn" type="button" data-tag-remove="' + safeTag + '" aria-label="Xóa nhãn ' + safeTag + '">×</button>' +
        '</span>'
      );
    })
    .join('');

  docTagsList.querySelectorAll('[data-tag-edit]').forEach((btn) => {
    btn.addEventListener('click', async function () {
      const oldTag = btn.getAttribute('data-tag-edit');
      if (!oldTag) return;
      const rawValue = await showPrompt('Nhập nhãn mới cho tài liệu:', {
        title: 'Sửa nhãn',
        defaultValue: oldTag,
        placeholder: 'Ví dụ: product, faq, policy',
        inputLabel: 'Giá trị nhãn',
      });
      const nextValue = sanitizeTag(rawValue);
      if (!nextValue) return;
      const updated = tags.map((item) => (item === oldTag ? nextValue : item));
      setDocTags(docForTags, updated);
      renderDocTagEditor();
      renderDocuments(documentsCache);
      setStatus('Đã cập nhật nhãn.', 'ok');
    });
  });

  docTagsList.querySelectorAll('[data-tag-remove]').forEach((btn) => {
    btn.addEventListener('click', function () {
      const targetTag = btn.getAttribute('data-tag-remove');
      if (!targetTag) return;
      const updated = tags.filter((item) => item !== targetTag);
      setDocTags(docForTags, updated);
      renderDocTagEditor();
      renderDocuments(documentsCache);
      setStatus('Đã xóa nhãn.', 'info');
    });
  });
}

function sanitizeFolderName(name) {
  return String(name || '')
    .trim()
    .replace(/\s+/g, ' ')
    .slice(0, 48);
}

function normalizeFolderState(raw) {
  const normalized = {
    folders: ['Mặc định'],
    assignments: {},
  };

  if (!raw || typeof raw !== 'object') {
    return normalized;
  }

  const rawFolders = Array.isArray(raw.folders) ? raw.folders : [];
  rawFolders
    .map((folder) => sanitizeFolderName(folder))
    .filter((folder) => folder.length > 0 && folder !== 'Tất cả')
    .forEach((folder) => {
      if (!normalized.folders.includes(folder)) {
        normalized.folders.push(folder);
      }
    });

  const rawAssignments = raw.assignments && typeof raw.assignments === 'object' ? raw.assignments : {};
  Object.keys(rawAssignments).forEach((docName) => {
    const folder = sanitizeFolderName(rawAssignments[docName]);
    if (!folder) return;
    if (!normalized.folders.includes(folder)) {
      normalized.folders.push(folder);
    }
    normalized.assignments[docName] = folder;
  });

  return normalized;
}

function saveFolderState() {
  localStorage.setItem(FOLDER_STATE_KEY, JSON.stringify(folderState));
}

function loadFolderState() {
  try {
    const raw = localStorage.getItem(FOLDER_STATE_KEY);
    folderState = normalizeFolderState(raw ? JSON.parse(raw) : null);
  } catch (_) {
    folderState = normalizeFolderState(null);
  }
}

function ensureFolder(folderName) {
  const folder = sanitizeFolderName(folderName);
  if (!folder) return 'Mặc định';
  if (!folderState.folders.includes(folder)) {
    folderState.folders.push(folder);
  }
  return folder;
}

function getDocFolder(docName) {
  const folder = sanitizeFolderName(folderState.assignments[docName] || '');
  return folder || 'Mặc định';
}

function setDocFolder(docName, folderName) {
  const safeName = String(docName || '').trim();
  if (!safeName) return;
  const folder = ensureFolder(folderName);
  folderState.assignments[safeName] = folder;
  saveFolderState();
}

function moveDocFolderAssignment(oldName, newName) {
  const oldSafe = String(oldName || '').trim();
  const newSafe = String(newName || '').trim();
  if (!newSafe) return;

  const fallbackFolder = sanitizeFolderName(pendingFolderSelection) || (activeFolder !== '__ALL__' ? activeFolder : 'Mặc định');
  const previousFolder = oldSafe ? getDocFolder(oldSafe) : fallbackFolder;
  const targetFolder = sanitizeFolderName(docFolderSelect?.value || '') || fallbackFolder || previousFolder;
  setDocFolder(newSafe, targetFolder);
  pendingFolderSelection = targetFolder;

  if (oldSafe && oldSafe !== newSafe && folderState.assignments[oldSafe]) {
    delete folderState.assignments[oldSafe];
    saveFolderState();
  }
}

function removeFolder(folderName) {
  const safeFolder = sanitizeFolderName(folderName);
  if (!safeFolder || safeFolder === 'Mặc định') {
    return;
  }
  folderState.folders = folderState.folders.filter((folder) => folder !== safeFolder);
  Object.keys(folderState.assignments).forEach((docName) => {
    if (folderState.assignments[docName] === safeFolder) {
      folderState.assignments[docName] = 'Mặc định';
    }
  });
  if (activeFolder === safeFolder) {
    activeFolder = '__ALL__';
  }
  if (pendingFolderSelection === safeFolder) {
    pendingFolderSelection = 'Mặc định';
  }
  saveFolderState();
}

function folderDocCount(folderName) {
  if (folderName === '__ALL__') {
    return documentsCache.length;
  }
  return documentsCache.filter((doc) => getDocFolder(doc.name) === folderName).length;
}

function renderFolderSelect() {
  if (!docFolderSelect) return;
  const folders = folderState.folders.slice();
  docFolderSelect.innerHTML = folders
    .map((folder) => '<option value="' + esc(folder) + '">' + esc(folder) + '</option>')
    .join('');

  if (pendingFolderSelection && !folders.includes(pendingFolderSelection)) {
    pendingFolderSelection = 'Mặc định';
  }
  const preferred = selectedDocName
    ? getDocFolder(selectedDocName)
    : (sanitizeFolderName(pendingFolderSelection) || (activeFolder !== '__ALL__' ? activeFolder : 'Mặc định'));
  docFolderSelect.value = folders.includes(preferred) ? preferred : 'Mặc định';
  pendingFolderSelection = docFolderSelect.value || 'Mặc định';
}

function bindFolderDropTarget(element, folderName) {
  element.addEventListener('dragover', function (event) {
    event.preventDefault();
    element.classList.add('folder-item-drop');
  });
  element.addEventListener('dragleave', function () {
    element.classList.remove('folder-item-drop');
  });
  element.addEventListener('drop', function (event) {
    event.preventDefault();
    element.classList.remove('folder-item-drop');
    if (!draggedDocName) return;
    setDocFolder(draggedDocName, folderName);
    if (selectedDocName === draggedDocName) {
      renderFolderSelect();
    }
    renderFolderList();
    renderDocuments(documentsCache);
    setStatus('Đã chuyển tài liệu vào thư mục "' + folderName + '".', 'ok');
    draggedDocName = '';
    document.body.classList.remove('is-dragging-doc');
  });
}

function renderFolderList() {
  if (!folderList) return;
  if (activeFolder !== '__ALL__' && !folderState.folders.includes(activeFolder)) {
    activeFolder = '__ALL__';
  }
  const folderItems = [
    {
      key: '__ALL__',
      label: 'Tất cả',
      removable: false,
    },
    ...folderState.folders.map((folder) => ({
      key: folder,
      label: folder,
      removable: folder !== 'Mặc định',
    })),
  ];

  folderList.innerHTML = folderItems
    .map((item) => {
      const activeClass = activeFolder === item.key ? ' active' : '';
      const count = folderDocCount(item.key);
      const deleteButton = item.removable
        ? '<button class="folder-remove-btn" type="button" data-remove-folder="' + esc(item.key) + '" aria-label="Xóa thư mục ' + esc(item.label) + '" title="Xóa thư mục">×</button>'
        : '';
      return (
        '<div class="folder-item' + activeClass + '" data-folder="' + esc(item.key) + '">' +
        '<button class="folder-main-btn" type="button" data-folder-select="' + esc(item.key) + '">' +
        '<span class="folder-name">' + esc(item.label) + '</span>' +
        '<span class="folder-count">' + esc(count) + '</span>' +
        '</button>' +
        deleteButton +
        '</div>'
      );
    })
    .join('');

  folderList.querySelectorAll('[data-folder-select]').forEach((button) => {
    button.addEventListener('click', function () {
      activeFolder = button.getAttribute('data-folder-select') || '__ALL__';
      if (selectedDocName) {
        pendingFolderSelection = getDocFolder(selectedDocName);
      } else if (activeFolder !== '__ALL__') {
        pendingFolderSelection = activeFolder;
      } else {
        pendingFolderSelection = 'Mặc định';
      }
      renderFolderSelect();
      renderFolderList();
      renderDocuments(documentsCache);
    });
  });

  folderList.querySelectorAll('[data-remove-folder]').forEach((button) => {
    button.addEventListener('click', async function (event) {
      event.stopPropagation();
      const targetFolder = button.getAttribute('data-remove-folder');
      if (!targetFolder) return;
      const confirmed = await showConfirm(
        'Xóa thư mục "' + targetFolder + '"? Tài liệu sẽ được chuyển về "Mặc định".',
        {
          title: 'Xóa thư mục',
          confirmText: 'Xóa',
          cancelText: 'Giữ lại',
          confirmTone: 'danger',
        }
      );
      if (!confirmed) {
        return;
      }
      removeFolder(targetFolder);
      renderFolderSelect();
      renderFolderList();
      renderDocuments(documentsCache);
    });
  });

  folderList.querySelectorAll('.folder-item[data-folder]').forEach((item) => {
    const folderKey = item.getAttribute('data-folder');
    if (folderKey && folderKey !== '__ALL__') {
      bindFolderDropTarget(item, folderKey);
    }
  });
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
      errors: ['Thiếu định dạng KDOC v1 hoặc marker đầu/cuối không hợp lệ.'],
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
  return { ok: errors.length === 0, errors };
}

function setViewMode(mode) {
  const normalized = mode === 'kdoc' ? 'kdoc' : 'text';
  const isKdoc = normalized === 'kdoc';
  if (textEditorBlock) {
    textEditorBlock.classList.toggle('is-hidden', isKdoc);
  }
  if (kdocOutlineBlock) {
    kdocOutlineBlock.classList.toggle('is-hidden', !isKdoc);
  }
  if (viewTextBtn) {
    viewTextBtn.classList.toggle('active', !isKdoc);
  }
  if (viewKdocBtn) {
    viewKdocBtn.classList.toggle('active', isKdoc);
  }
  localStorage.setItem(VIEW_MODE_KEY, normalized);
}

function sectionLines(key, value) {
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

function buildFallbackKdocSections(rawText) {
  const cleanText = String(rawText || '').trim();
  return {
    DOC_ID: '',
    DOC_TYPE: 'product',
    TITLE: '',
    ALIASES: '',
    KEYWORDS: '',
    SUMMARY: '',
    CONTENT: cleanText,
    USAGE: '',
    FAQ: '',
    SAFETY_NOTE: '',
    LAST_UPDATED: new Date().toISOString().split('T')[0],
  };
}

function fieldRowsForKey(key) {
  if (key === 'CONTENT') return 8;
  if (key === 'SERVICES' || key === 'DAY_VISIT' || key === 'STAY_PACKAGE' || key === 'REGULATIONS') return 5;
  if (key === 'FAQ' || key === 'USAGE' || key === 'SUMMARY') return 4;
  if (key === 'SAFETY_NOTE') return 3;
  if (key === 'ALIASES' || key === 'KEYWORDS') return 2;
  return 3;
}

function buildKdocCard(key, value) {
  const label = KDOC_SECTION_LABELS[key] || key;
  const hint = KDOC_SECTION_HINTS[key] || 'Mục mở rộng do hệ thống nhận diện.';
  const placeholder = KDOC_SECTION_PLACEHOLDERS[key] || '';
  const safeValue = String(value || '').replaceAll('\r\n', '\n');
  const singleLine = KDOC_SINGLE_LINE_KEYS.has(key);
  const control = singleLine
    ? '<input class="kdoc-field kdoc-input" data-kdoc-key="' + esc(key) + '" value="' + esc(safeValue) + '" placeholder="' + esc(placeholder) + '" />'
    : '<textarea class="kdoc-field kdoc-textarea" data-kdoc-key="' + esc(key) + '" rows="' + fieldRowsForKey(key) + '" placeholder="' + esc(placeholder) + '">' + esc(safeValue) + '</textarea>';

  return (
    '<article class="kdoc-card kdoc-card-edit">' +
    '<h5>' + esc(label) + ' [' + esc(key) + ']</h5>' +
    '<p class="kdoc-field-hint">' + esc(hint) + '</p>' +
    control +
    '</article>'
  );
}

function buildKdocTextFromSections(sectionMap, keyOrder) {
  const keys = Array.from(new Set((keyOrder || []).filter((key) => key && key.trim().length > 0)));
  const blocks = keys
    .map((key) => {
      const value = String(sectionMap[key] || '').replaceAll('\r\n', '\n').trim();
      return '[' + key + ']\n' + value;
    })
    .join('\n\n');

  return '=== KDOC:v1 ===\n' + blocks + '\n=== END_KDOC ===';
}

function syncTextFromKdocFields() {
  if (!kdocOutlineBody || !docText) return;
  let keyOrder = KDOC_SECTION_ORDER.slice();
  const rawKeys = kdocOutlineBody.getAttribute('data-kdoc-keys');
  if (rawKeys) {
    try {
      const parsedKeys = JSON.parse(rawKeys);
      if (Array.isArray(parsedKeys) && parsedKeys.length > 0) {
        keyOrder = parsedKeys;
      }
    } catch (_) {
      // ignore invalid cache
    }
  }

  const sections = {};
  kdocOutlineBody.querySelectorAll('.kdoc-field[data-kdoc-key]').forEach((field) => {
    const key = field.getAttribute('data-kdoc-key');
    if (!key) return;
    sections[key] = String(field.value || '').replaceAll('\r\n', '\n').trim();
  });
  keyOrder.forEach((key) => {
    if (!(key in sections)) sections[key] = '';
  });

  docText.value = buildKdocTextFromSections(sections, keyOrder);
  scheduleDraftSave();
  refreshDirtyState();
}

function renderKdocOutline(text) {
  if (!kdocOutlineBody) return;
  const rawText = String(text || '');
  const parsedSections = parseKdocSections(rawText);
  const isFallbackMode = !parsedSections;
  const sections = isFallbackMode ? buildFallbackKdocSections(rawText) : { ...parsedSections };

  const renderedKeySet = new Set();
  const orderedKeys = KDOC_SECTION_ORDER.slice();
  Object.keys(sections).forEach((key) => {
    if (!orderedKeys.includes(key)) orderedKeys.push(key);
  });
  kdocOutlineBody.setAttribute('data-kdoc-keys', JSON.stringify(orderedKeys));

  const intro = isFallbackMode
    ? '<div class="kdoc-convert-note"><strong>Đang ở chế độ chuyển đổi từ văn bản thường sang KDOC.</strong> Hãy điền các mục bên dưới, nội dung Text sẽ tự đồng bộ theo chuẩn KDOC v1.</div>'
    : '';

  const groupBlocks = KDOC_SECTION_GROUPS
    .map((group) => {
      const cards = group.keys
        .map((key) => {
          renderedKeySet.add(key);
          if (!orderedKeys.includes(key)) {
            return '';
          }
          return buildKdocCard(key, sections[key]);
        })
        .filter((item) => item)
        .join('');

      if (!cards) return '';
      return (
        '<section class="kdoc-group">' +
        '<h5 class="kdoc-group-title">' + esc(group.title) + '</h5>' +
        '<div class="kdoc-grid">' + cards + '</div>' +
        '</section>'
      );
    })
    .filter((item) => item);

  const extraCards = Object.keys(sections)
    .filter((key) => !renderedKeySet.has(key))
    .map((key) => {
      return buildKdocCard(key, sections[key]);
    })
    .filter((item) => item)
    .join('');

  if (extraCards) {
    groupBlocks.push(
      '<section class="kdoc-group">' +
      '<h5 class="kdoc-group-title">Mục mở rộng</h5>' +
      '<div class="kdoc-grid">' + extraCards + '</div>' +
      '</section>'
    );
  }

  if (groupBlocks.length === 0) {
    kdocOutlineBody.innerHTML = 'Chưa có mục nào để hiển thị.';
    return;
  }
  kdocOutlineBody.innerHTML = intro + groupBlocks.join('');
}

function setStatus(text, tone) {
  if (!uploadStatus) return;
  const normalizedTone = ['info', 'loading', 'ok', 'warn'].includes(tone) ? tone : 'info';
  uploadStatus.textContent = text;
  uploadStatus.className = 'status-line ' + normalizedTone;
}

function setLastModified(value) {
  if (!lastModifiedLabel) return;
  lastModifiedLabel.textContent = value ? formatTimestamp(value) : '-';
}

function formatHostState(rawState) {
  const state = String(rawState || '').trim().toLowerCase();
  if (!state || state === 'unknown') {
    return { text: 'Host: Không rõ', cls: 'metric-chip metric-chip-host is-idle' };
  }
  if (state === 'running') {
    return { text: 'Host: Đang chạy', cls: 'metric-chip metric-chip-host is-running' };
  }
  if (state === 'starting') {
    return { text: 'Host: Đang khởi tạo', cls: 'metric-chip metric-chip-host is-idle' };
  }
  if (state === 'stopped') {
    return { text: 'Host: Đã dừng', cls: 'metric-chip metric-chip-host is-idle' };
  }
  return { text: 'Host: ' + state, cls: 'metric-chip metric-chip-host is-idle' };
}

function deriveTags(doc) {
  const source = String(doc.name || '').toLowerCase() + ' ' + String(doc.snippet || doc.preview || '').toLowerCase();
  const tags = [];
  if (source.includes('faq')) tags.push('faq');
  if (source.includes('policy') || source.includes('chính sách')) tags.push('policy');
  if (source.includes('chanh') || source.includes('sản phẩm')) tags.push('product');
  if (source.includes('hướng dẫn') || source.includes('guide')) tags.push('guide');
  if (tags.length === 0) tags.push('note');
  return tags.slice(0, 3);
}

async function req(url, options) {
  const retryCount = Number(options?.retryCount || 0);
  let lastError = null;
  for (let attempt = 0; attempt <= retryCount; attempt += 1) {
    try {
      const cleanOptions = { ...(options || {}) };
      delete cleanOptions.retryCount;
      const res = await fetch(url, cleanOptions);
      const json = await res.json().catch(() => ({}));
      if (!res.ok || json.ok === false) {
        const msg = json.error || ('HTTP ' + res.status);
        throw new Error(msg);
      }
      return json;
    } catch (error) {
      lastError = error;
      if (attempt >= retryCount) {
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 250 * (attempt + 1)));
    }
  }
  throw lastError || new Error('Yêu cầu thất bại.');
}

function setBulkActionDisabled(disabled) {
  const flag = !!disabled;
  [
    exportAllBtn,
    importAllBtn,
    importAllInput,
    exportIncludeImages,
    importIncludeImages,
    refreshBtn,
    clearBtn,
    uploadBtn,
    newNoteBtn,
  ].forEach((el) => {
    if (!el) return;
    el.disabled = flag;
  });
  if (dataTabButtons && dataTabButtons.length > 0) {
    dataTabButtons.forEach((btn) => {
      btn.disabled = flag;
    });
  }
}

function setDataTab(tabName) {
  if (!dataTabButtons || !dataTabPanels) return;
  const target = String(tabName || '').trim();
  dataTabButtons.forEach((btn) => {
    const name = btn.getAttribute('data-data-tab');
    const active = name === target;
    btn.classList.toggle('active', active);
    btn.setAttribute('aria-selected', active ? 'true' : 'false');
  });
  dataTabPanels.forEach((panel) => {
    const name = panel.getAttribute('data-data-panel');
    const active = name === target;
    panel.classList.toggle('is-hidden', !active);
    panel.setAttribute('aria-hidden', active ? 'false' : 'true');
  });
}

function makeExportFileName() {
  const now = new Date();
  const two = (v) => String(v).padStart(2, '0');
  return (
    'voicebot-tri-thuc-' +
    now.getFullYear() +
    two(now.getMonth() + 1) +
    two(now.getDate()) +
    '-' +
    two(now.getHours()) +
    two(now.getMinutes()) +
    two(now.getSeconds()) +
    '.json'
  );
}

async function collectDocumentsForExport() {
  const sourceDocs = documentsCache.length > 0
    ? documentsCache.slice()
    : (await req('/api/documents', { retryCount: 1 })).documents || [];
  const normalized = Array.isArray(sourceDocs) ? sourceDocs : [];
  const result = [];
  for (let i = 0; i < normalized.length; i += 1) {
    const item = normalized[i];
    const name = String(item.name || '').trim();
    if (!name) continue;
    const detail = await req('/api/documents/content?name=' + encodeURIComponent(name), { retryCount: 1 });
    const doc = detail.document || {};
    result.push({
      name: name,
      content: String(doc.content || ''),
      updated_at: String(doc.updated_at || item.updated_at || ''),
      characters: Number(doc.characters || item.characters || 0),
    });
  }
  return result;
}

function blobToBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = function () {
      const result = String(reader.result || '');
      const marker = 'base64,';
      const idx = result.indexOf(marker);
      if (idx < 0) {
        reject(new Error('Không đọc được dữ liệu base64.'));
        return;
      }
      resolve(result.substring(idx + marker.length));
    };
    reader.onerror = function () {
      reject(new Error('Đọc dữ liệu ảnh thất bại.'));
    };
    reader.readAsDataURL(blob);
  });
}

async function fetchImageBase64(imageId) {
  const res = await fetch('/api/documents/image/content?id=' + encodeURIComponent(imageId));
  if (!res.ok) {
    throw new Error('Không tải được ảnh (HTTP ' + res.status + ').');
  }
  const blob = await res.blob();
  return blobToBase64(blob);
}

async function collectImagesForExport(docs) {
  const result = [];
  const rows = Array.isArray(docs) ? docs : [];
  for (let i = 0; i < rows.length; i += 1) {
    const docName = String(rows[i]?.name || '').trim();
    if (!docName) continue;
    setStatus('Đang kiểm tra ảnh (' + (i + 1) + '/' + rows.length + ')...', 'loading');
    const list = await req('/api/documents/images?name=' + encodeURIComponent(docName), { retryCount: 1 });
    const images = Array.isArray(list.images) ? list.images : [];
    for (let j = 0; j < images.length; j += 1) {
      const item = images[j] || {};
      const imageId = String(item.id || '').trim();
      if (!imageId) continue;
      setStatus(
        'Đang xuất ảnh ' + (j + 1) + '/' + images.length + ' (' + docName + ')...',
        'loading',
      );
      const base64 = await fetchImageBase64(imageId);
      result.push({
        doc_name: docName,
        file_name: String(item.file_name || 'image').trim() || 'image',
        mime_type: String(item.mime_type || '').trim(),
        bytes: Number(item.bytes || 0),
        created_at: String(item.created_at || ''),
        caption: item.caption || null,
        data_base64: base64,
      });
    }
  }
  return result;
}

function downloadJsonFile(filename, payload) {
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement('a');
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

async function exportAllData() {
  try {
    setBulkActionDisabled(true);
    setStatus('Đang chuẩn bị gói xuất dữ liệu...', 'loading');
    const docs = await collectDocumentsForExport();
    const includeImages = exportIncludeImages ? exportIncludeImages.checked : false;
    const images = includeImages ? await collectImagesForExport(docs) : [];
    const payload = {
      schema: EXPORT_SCHEMA,
      exported_at: new Date().toISOString(),
      source: 'voicebot_web_host',
      documents: docs,
      images: images,
      image_count: images.length,
      include_images: includeImages,
      folderState: folderState,
      noteTagState: noteTagState,
      uiState: {
        viewMode: localStorage.getItem(VIEW_MODE_KEY) || 'text',
      },
    };
    downloadJsonFile(makeExportFileName(), payload);
    setStatus(
      'Xuất dữ liệu thành công: ' +
        docs.length +
        ' tài liệu' +
        (images.length > 0 ? ', ' + images.length + ' ảnh.' : '.'),
      'ok',
    );
  } catch (error) {
    setStatus('Xuất dữ liệu lỗi: ' + error.message, 'warn');
  } finally {
    setBulkActionDisabled(false);
  }
}

function parseImportPayload(rawText) {
  const parsed = JSON.parse(rawText);
  if (!parsed || typeof parsed !== 'object') {
    throw new Error('File import không đúng định dạng JSON object.');
  }
  const docs = Array.isArray(parsed.documents) ? parsed.documents : [];
  const normalizedDocs = docs
    .map((doc) => ({
      name: String(doc?.name || '').trim(),
      text: String(doc?.content ?? doc?.text ?? ''),
    }))
    .filter((doc) => doc.name.length > 0 && doc.text.length > 0);
  if (normalizedDocs.length === 0) {
    throw new Error('File import không có tài liệu hợp lệ.');
  }
  const rawImages = Array.isArray(parsed.images) ? parsed.images : [];
  const normalizedImages = rawImages
    .map((img) => ({
      doc_name: String(img?.doc_name || img?.name || '').trim(),
      file_name: String(img?.file_name || 'image').trim() || 'image',
      mime_type: String(img?.mime_type || '').trim(),
      caption: img?.caption || null,
      data_base64: String(img?.data_base64 || img?.data || '').trim(),
    }))
    .filter((img) => img.doc_name.length > 0 && img.data_base64.length > 0);

  return {
    documents: normalizedDocs,
    images: normalizedImages,
    folderState: normalizeFolderState(parsed.folderState || {}),
    noteTagState: normalizeTagStateMap(parsed.noteTagState || {}),
    viewMode: String(parsed?.uiState?.viewMode || localStorage.getItem(VIEW_MODE_KEY) || 'text'),
  };
}

async function importAllDataFromFile(file) {
  if (!file) return;
  try {
    const confirmed = await showConfirm(
      'Nhập dữ liệu sẽ ghi đè toàn bộ tài liệu hiện có trên máy này. Bạn có chắc chắn muốn tiếp tục?',
      {
        title: 'Xác nhận ghi đè dữ liệu',
        confirmText: 'Tiếp tục nhập',
        cancelText: 'Hủy',
        confirmTone: 'danger',
      }
    );
    if (!confirmed) {
      return;
    }
    setBulkActionDisabled(true);
    setStatus('Đang đọc file import...', 'loading');
    const rawText = await file.text();
    const data = parseImportPayload(rawText);

    setStatus('Đang xóa dữ liệu cũ...', 'loading');
    await req('/api/documents', { method: 'DELETE' });

    setStatus('Đang nhập ' + data.documents.length + ' tài liệu...', 'loading');
    for (let i = 0; i < data.documents.length; i += 1) {
      const item = data.documents[i];
      await req('/api/documents/text', {
        method: 'POST',
        retryCount: 1,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: item.name, text: item.text }),
      });
    }

    const includeImages = importIncludeImages ? importIncludeImages.checked : true;
    if (includeImages && data.images.length > 0) {
      setStatus('Đang nhập ' + data.images.length + ' ảnh...', 'loading');
      for (let i = 0; i < data.images.length; i += 1) {
        const image = data.images[i];
        setStatus('Đang nhập ảnh ' + (i + 1) + '/' + data.images.length + '...', 'loading');
        await req('/api/documents/image', {
          method: 'POST',
          retryCount: 1,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name: image.doc_name,
            file_name: image.file_name,
            mime_type: image.mime_type,
            data_base64: image.data_base64,
            caption: image.caption,
          }),
        });
      }
    }

    folderState = data.folderState;
    noteTagState = data.noteTagState;
    activeFolder = '__ALL__';
    selectedDocName = '';
    pendingFolderSelection = 'Mặc định';
    if (docName) docName.value = '';
    if (docText) docText.value = '';
    if (docPreviewTitle) docPreviewTitle.textContent = 'Chưa đặt tên';
    if (docPreviewContent) {
      docPreviewContent.textContent =
        'Nội dung tài liệu sẽ xuất hiện tại đây khi bạn chọn một tài liệu ở cột giữa.';
    }
    setLastModified('-');
    markEditorSaved();
    saveFolderState();
    saveTagState();

    if (data.viewMode === 'kdoc') {
      setViewMode('kdoc');
    } else {
      setViewMode('text');
    }

    await refreshDocuments({ silentStatus: true });
    if (documentsCache.length > 0) {
      await loadDocumentContent(documentsCache[0].name);
    }
    setStatus(
      'Nhập dữ liệu thành công: ' +
        data.documents.length +
        ' tài liệu' +
        (includeImages && data.images.length > 0 ? ', ' + data.images.length + ' ảnh.' : '.'),
      'ok',
    );
  } catch (error) {
    setStatus('Nhập dữ liệu lỗi: ' + error.message, 'warn');
  } finally {
    if (importAllInput) {
      importAllInput.value = '';
    }
    setBulkActionDisabled(false);
  }
}

function normalizeSnippet(text) {
  return String(text || '').replace(/\s+/g, ' ').trim();
}

function rememberListScroll() {
  if (!docBody) return;
  listScrollTop = docBody.scrollTop;
}

function restoreListScroll() {
  if (!docBody) return;
  docBody.scrollTop = listScrollTop;
}

function renderListState(message, tone) {
  if (!docBody) return;
  const stateTone = tone === 'error' ? ' error' : '';
  docBody.innerHTML = '<div class="state-card' + stateTone + '">' + esc(message) + '</div>';
}

function getEditorSnapshot() {
  return JSON.stringify({
    name: docName?.value || '',
    text: docText?.value || '',
  });
}

function markEditorSaved() {
  lastSavedSnapshot = getEditorSnapshot();
  isDirty = false;
}

function refreshDirtyState() {
  const dirtyNow = getEditorSnapshot() !== lastSavedSnapshot;
  if (dirtyNow && !isDirty && !isSaving) {
    setStatus('Đang chỉnh sửa, chưa lưu lên hệ thống.', 'info');
  }
  if (!dirtyNow && isDirty) {
    setStatus('Nội dung đã đồng bộ với bản đã lưu.', 'ok');
  }
  isDirty = dirtyNow;
}

function onEditorInput() {
  scheduleDraftSave();
  refreshDirtyState();
  renderKdocOutline(docText?.value || '');
}

async function canDiscardUnsaved(actionLabel) {
  if (!isDirty) return true;
  return showConfirm('Bạn có thay đổi chưa lưu. Bạn có muốn ' + actionLabel + ' không?', {
    title: 'Dữ liệu chưa lưu',
    confirmText: 'Tiếp tục',
    cancelText: 'Quay lại',
    confirmTone: 'danger',
  });
}

function setSaveButtonLoading(loading) {
  if (!uploadBtn) return;
  uploadBtn.disabled = loading;
  uploadBtn.textContent = loading ? 'Đang lưu...' : saveButtonDefaultLabel;
}

function renderDocuments(items) {
  if (!docBody) return;
  const rows = Array.isArray(items) ? items.slice() : [];
  const keyword = String(docFilterInput?.value || '').trim().toLowerCase();
  const sideKeyword = String(sidebarSearch?.value || '').trim().toLowerCase();
  const sort = String(docSortSelect?.value || 'updated_desc');

  const filtered = rows.filter(function (doc) {
    const name = String(doc.name || '').toLowerCase();
    const preview = String(doc.snippet || doc.preview || '').toLowerCase();
    const tags = getDocTags(doc.name, doc).join(' ').toLowerCase();
    const folder = getDocFolder(doc.name);

    const matchMain = !keyword || name.includes(keyword);
    const matchSide = !sideKeyword || name.includes(sideKeyword) || tags.includes(sideKeyword) || preview.includes(sideKeyword);
    const matchFolder = activeFolder === '__ALL__' || folder === activeFolder;
    return matchMain && matchSide && matchFolder;
  });

  filtered.sort(function (a, b) {
    const nameA = String(a.name || '');
    const nameB = String(b.name || '');
    const updatedA = String(a.updated_at || '');
    const updatedB = String(b.updated_at || '');
    if (sort === 'name_asc') return nameA.localeCompare(nameB);
    if (sort === 'name_desc') return nameB.localeCompare(nameA);
    if (sort === 'updated_asc') return updatedA.localeCompare(updatedB);
    return updatedB.localeCompare(updatedA);
  });

  if (docCount) docCount.textContent = 'Tổng: ' + filtered.length;
  if (docCountHero) docCountHero.textContent = filtered.length + ' tài liệu';

  if (filtered.length === 0) {
    renderListState('Chưa có tài liệu phù hợp.', 'info');
    return;
  }

  docBody.innerHTML = filtered
    .map(function (doc) {
      const name = esc(doc.name);
      const updated = esc(formatTimestamp(doc.updated_at));
      const chars = esc(formatCharCount(doc.characters));
      const preview = esc(normalizeSnippet(doc.snippet || doc.preview || '')).slice(0, 150);
      const tags = getDocTags(doc.name, doc).map((tag) => '<span class="note-tag">' + esc(tag) + '</span>').join('');
      const activeClass = selectedDocName && selectedDocName === doc.name ? ' active' : '';
      const folder = esc(getDocFolder(doc.name));
      return (
        '<article class="note-item' + activeClass + '" data-name="' + name + '" data-folder="' + folder + '" role="listitem" tabindex="0" draggable="true">' +
        '<div class="note-date">Cập nhật: ' + updated + ' • Độ dài: ' + chars + '</div>' +
        '<div class="note-title">' + name + '</div>' +
        '<div class="note-folder">📁 ' + folder + '</div>' +
        '<div class="note-preview">' + (preview || 'Không có đoạn xem trước.') + '</div>' +
        '<div class="note-tags">' + tags + '</div>' +
        '</article>'
      );
    })
    .join('');

  docBody.querySelectorAll('.note-item[data-name]').forEach(function (el) {
    const noteName = el.getAttribute('data-name') || '';
    const open = async function () {
      const name = noteName;
      if (name) {
        if (selectedDocName !== name && !(await canDiscardUnsaved('mở tài liệu khác'))) {
          return;
        }
        rememberListScroll();
        await loadDocumentContent(name);
      }
    };

    el.addEventListener('click', open);
    el.addEventListener('keydown', function (ev) {
      if (ev.key === 'Enter' || ev.key === ' ') {
        ev.preventDefault();
        open();
      }
    });
    el.addEventListener('dragstart', function () {
      draggedDocName = noteName;
      el.classList.add('note-item-dragging');
      document.body.classList.add('is-dragging-doc');
    });
    el.addEventListener('dragend', function () {
      el.classList.remove('note-item-dragging');
      draggedDocName = '';
      document.body.classList.remove('is-dragging-doc');
    });
  });

  restoreListScroll();
}

async function refreshHostInfo() {
  if (!hostStatus) return;
  try {
    const info = await req('/info');
    const view = formatHostState(info.status);
    hostStatus.textContent = view.text;
    hostStatus.className = view.cls;
  } catch (e) {
    hostStatus.textContent = 'Host: Mất kết nối';
    hostStatus.className = 'metric-chip metric-chip-host is-error';
  }
}

async function refreshDocuments(options) {
  const opts = options || {};
  renderListState('Đang tải danh sách tài liệu...');
  if (!opts.silentStatus) {
    setStatus('Đang tải danh sách tài liệu...', 'loading');
  }
  const data = await req('/api/documents', { retryCount: 1 });
  documentsCache = Array.isArray(data.documents) ? data.documents : [];
  renderFolderList();
  renderFolderSelect();
  renderDocTagEditor();
  renderDocuments(documentsCache);
  if (!opts.silentStatus) {
    setStatus('Đã cập nhật danh sách tài liệu.', 'ok');
  }
  return data;
}

function saveDraft() {
  if (!docName || !docText) return;
  const payload = {
    name: docName.value,
    text: docText.value,
    updatedAt: new Date().toISOString(),
  };
  localStorage.setItem(DRAFT_KEY, JSON.stringify(payload));
}

function loadDraft() {
  if (!docName || !docText) return;
  try {
    const raw = localStorage.getItem(DRAFT_KEY);
    if (!raw) return;
    const draft = JSON.parse(raw);
    if (draft && !selectedDocName && !docText.value.trim()) {
      docName.value = String(draft.name || '');
      docText.value = String(draft.text || '');
      renderKdocOutline(docText.value || '');
      fetchDocumentImages(docName.value, { silentStatus: true });
      isDirty = true;
      setStatus('Đã khôi phục bản nháp cục bộ. Vui lòng lưu để cập nhật hệ thống.', 'info');
    }
  } catch (_) {
    // ignore broken local draft
  }
}

function scheduleDraftSave() {
  if (draftTimer) {
    clearTimeout(draftTimer);
  }
  draftTimer = setTimeout(saveDraft, 250);
}

function currentImageDocumentName() {
  const draftName = String(docName?.value || '').trim();
  if (draftName) {
    return draftName;
  }
  const activeName = String(selectedDocName || '').trim();
  return activeName;
}

function setImageUploadStatus(message, tone) {
  if (!imageUploadStatus) return;
  const normalizedTone = ['info', 'loading', 'ok', 'warn'].includes(tone)
    ? tone
    : 'info';
  imageUploadStatus.textContent = message;
  imageUploadStatus.className = 'status-line ' + normalizedTone;
}

function setImageUploadBusy(busy) {
  isUploadingImage = !!busy;
  if (pickImageBtn) {
    pickImageBtn.disabled = isUploadingImage;
  }
  if (imageFileInput) {
    imageFileInput.disabled = isUploadingImage;
  }
  if (insertImageBtn) {
    insertImageBtn.disabled = isUploadingImage;
  }
  if (imageDropZone) {
    imageDropZone.setAttribute('aria-busy', isUploadingImage ? 'true' : 'false');
  }
}

function resetImageGallery(message) {
  documentImages = [];
  if (!imageGrid) return;
  imageGrid.innerHTML =
    '<div class="image-card image-card-empty">' + esc(message || 'Chưa có ảnh cho tài liệu này.') + '</div>';
}

function renderDocumentImages() {
  if (!imageGrid) return;
  if (documentImages.length === 0) {
    resetImageGallery('Chưa có ảnh cho tài liệu này.');
    return;
  }

  imageGrid.innerHTML = documentImages
    .map(function (item) {
      const imageId = esc(String(item.id || ''));
      const fileName = esc(String(item.file_name || 'image'));
      const bytes = Number(item.bytes || 0).toLocaleString('vi-VN');
      const created = esc(formatTimestamp(item.created_at));
      const url = '/api/documents/image/content?id=' + encodeURIComponent(String(item.id || ''));
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
        '<div class="image-card-actions">' +
        '<button class="image-delete-btn" type="button" data-image-delete="' + imageId + '" aria-label="Xóa ảnh ' + fileName + '">Xóa</button>' +
        '</div>' +
        '</figcaption>' +
        '</figure>'
      );
    })
    .join('');

  imageGrid.querySelectorAll('[data-image-delete]').forEach(function (btn) {
    btn.addEventListener('click', async function () {
      const imageId = btn.getAttribute('data-image-delete');
      if (!imageId) return;
      const confirmed = await showConfirm('Bạn có muốn xóa ảnh này khỏi tài liệu?', {
        title: 'Xóa ảnh minh họa',
        confirmText: 'Xóa',
        cancelText: 'Hủy',
        confirmTone: 'danger',
      });
      if (!confirmed) {
        return;
      }
      try {
        await req('/api/documents/image?id=' + encodeURIComponent(imageId), {
          method: 'DELETE',
          retryCount: 1,
        });
        setImageUploadStatus('Đã xóa ảnh.', 'ok');
        const doc = currentImageDocumentName();
        if (doc) {
          await fetchDocumentImages(doc, { silentStatus: true });
        } else {
          resetImageGallery('Chưa có ảnh cho tài liệu này.');
        }
      } catch (error) {
        setImageUploadStatus('Xóa ảnh lỗi: ' + error.message, 'warn');
      }
    });
  });

  imageGrid.querySelectorAll('[data-image-preview-url]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      const imageUrl = btn.getAttribute('data-image-preview-url') || '';
      const title = btn.getAttribute('data-image-preview-title') || 'Ảnh minh họa';
      const meta = btn.getAttribute('data-image-preview-meta') || '';
      openImagePreview(imageUrl, title, meta);
    });
  });
}

async function fetchDocumentImages(docNameValue, options) {
  const opts = options || {};
  const doc = String(docNameValue || '').trim();
  if (!doc) {
    resetImageGallery('Nhập tên tài liệu để bắt đầu tải ảnh.');
    if (!opts.silentStatus) {
      setImageUploadStatus('Chưa có tên tài liệu để tải ảnh.', 'info');
    }
    return;
  }

  try {
    const data = await req(
      '/api/documents/images?name=' + encodeURIComponent(doc),
      { retryCount: 1 },
    );
    documentImages = Array.isArray(data.images) ? data.images : [];
    renderDocumentImages();
    if (!opts.silentStatus) {
      setImageUploadStatus(
        documentImages.length > 0
          ? 'Đã tải ' + documentImages.length + ' ảnh.'
          : 'Tài liệu chưa có ảnh.',
        'info',
      );
    }
  } catch (error) {
    documentImages = [];
    resetImageGallery('Không tải được danh sách ảnh.');
    if (!opts.silentStatus) {
      setImageUploadStatus('Không tải được ảnh: ' + error.message, 'warn');
    }
  }
}

function scheduleImageFetch(docNameValue) {
  if (imageFetchTimer) {
    clearTimeout(imageFetchTimer);
  }
  const target = String(docNameValue || '').trim();
  imageFetchTimer = setTimeout(function () {
    fetchDocumentImages(target, { silentStatus: true });
  }, 260);
}

async function uploadSingleImage(file, doc) {
  const mime = String(file?.type || '').toLowerCase();
  if (!['image/jpeg', 'image/png', 'image/webp'].includes(mime)) {
    throw new Error('Ảnh "' + (file.name || '') + '" không đúng định dạng JPEG/PNG/WEBP.');
  }
  if (file.size > MAX_IMAGE_UPLOAD_BYTES) {
    throw new Error('Ảnh "' + (file.name || '') + '" vượt quá giới hạn ' + MAX_IMAGE_UPLOAD_MB + 'MB.');
  }
  const form = new FormData();
  form.append('name', doc);
  form.append('file', file, file.name || 'image');
  try {
    await req('/api/documents/image', {
      method: 'POST',
      retryCount: 1,
      body: form,
    });
  } catch (multipartError) {
    // Fallback JSON upload to avoid multipart parsing differences across browsers/devices.
    const dataBase64 = await fileToBase64(file);
    await req('/api/documents/image', {
      method: 'POST',
      retryCount: 1,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: doc,
        file_name: file.name || 'image',
        mime_type: mime,
        data_base64: dataBase64,
      }),
    });
  }
}

function fileToBase64(file) {
  return new Promise(function (resolve, reject) {
    const reader = new FileReader();
    reader.onload = function () {
      const result = String(reader.result || '');
      const marker = 'base64,';
      const idx = result.indexOf(marker);
      if (idx < 0) {
        reject(new Error('Không đọc được dữ liệu ảnh base64.'));
        return;
      }
      resolve(result.substring(idx + marker.length));
    };
    reader.onerror = function () {
      reject(new Error('Đọc dữ liệu ảnh thất bại.'));
    };
    reader.readAsDataURL(file);
  });
}

async function uploadImageFiles(fileList) {
  if (isUploadingImage) {
    return;
  }
  const files = Array.from(fileList || []);
  if (files.length === 0) {
    return;
  }
  const doc = currentImageDocumentName();
  if (!doc) {
    setImageUploadStatus('Hãy nhập tên tài liệu và lưu trước khi tải ảnh.', 'warn');
    return;
  }

  setImageUploadBusy(true);
  try {
    for (let i = 0; i < files.length; i += 1) {
      setImageUploadStatus('Đang tải ảnh ' + (i + 1) + '/' + files.length + '...', 'loading');
      await uploadSingleImage(files[i], doc);
    }
    await fetchDocumentImages(doc, { silentStatus: true });
    setImageUploadStatus('Tải ảnh thành công (' + files.length + ' tệp).', 'ok');
  } catch (error) {
    setImageUploadStatus('Tải ảnh lỗi: ' + error.message, 'warn');
  } finally {
    if (imageFileInput) {
      imageFileInput.value = '';
    }
    setImageUploadBusy(false);
  }
}

async function loadDocumentContent(name) {
  if (!docPreviewTitle || !docText || !docName) return;
  try {
    setStatus('Đang tải nội dung tài liệu...', 'loading');
    const data = await req('/api/documents/content?name=' + encodeURIComponent(name), { retryCount: 1 });
    const doc = data.document || {};
    selectedDocName = String(doc.name || name || '');
    docPreviewTitle.textContent = selectedDocName || 'Chưa đặt tên';
    docName.value = selectedDocName;
    docText.value = String(doc.content || '');
    pendingFolderSelection = getDocFolder(selectedDocName);
    renderKdocOutline(docText.value || '');
    if (docPreviewContent) {
      docPreviewContent.textContent = String(doc.content || '');
    }
    setLastModified(doc.updated_at || '-');
    markEditorSaved();
    saveDraft();
    renderFolderSelect();
    renderDocTagEditor();
    renderDocuments(documentsCache);
    await fetchDocumentImages(selectedDocName, { silentStatus: true });
    setStatus('Đã tải nội dung tài liệu.', 'ok');
  } catch (e) {
    setStatus('Không đọc được nội dung: ' + e.message, 'warn');
  }
}

async function uploadDocument() {
  if (isSaving) {
    return;
  }
  const previousName = selectedDocName;
  const name = (docName?.value || '').trim();
  const text = (docText?.value || '').trim();
  if (!name || !text) {
    setStatus('Vui lòng nhập tên tài liệu và nội dung.', 'warn');
    return;
  }
  const validation = validateKdoc(text);
  if (!validation.ok) {
    const preview = validation.errors.slice(0, 2).join(' | ');
    setStatus('Nội dung chưa đúng chuẩn KDOC v1: ' + preview, 'warn');
    return;
  }

  isSaving = true;
  setSaveButtonLoading(true);
  setStatus('Đang lưu tài liệu...', 'loading');
  try {
    await req('/api/documents/text', {
      method: 'POST',
      retryCount: 1,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: name, old_name: previousName || '', text: text }),
    });
    moveDocFolderAssignment(previousName, name);
    moveDocTagsAssignment(previousName, name);
    selectedDocName = name;
    markEditorSaved();
    saveDraft();
    renderFolderSelect();
    renderDocTagEditor();
    setStatus('Lưu tài liệu thành công.', 'ok');
    await refreshDocuments({ silentStatus: true });
    await loadDocumentContent(name);
  } catch (e) {
    isDirty = true;
    setStatus('Lưu lỗi: ' + e.message, 'warn');
  } finally {
    isSaving = false;
    setSaveButtonLoading(false);
  }
}

async function clearDocuments() {
  if (!(await canDiscardUnsaved('xóa toàn bộ tài liệu'))) return;
  const confirmed = await showConfirm('Bạn chắc chắn muốn xóa toàn bộ tài liệu?', {
    title: 'Xóa toàn bộ tài liệu',
    confirmText: 'Xóa tất cả',
    cancelText: 'Hủy',
    confirmTone: 'danger',
  });
  if (!confirmed) return;
  if (clearBtn) clearBtn.disabled = true;
  try {
    setStatus('Đang xóa toàn bộ tài liệu...', 'loading');
    await req('/api/documents', { method: 'DELETE' });
    documentsCache = [];
    selectedDocName = '';
    folderState.assignments = {};
    noteTagState = {};
    pendingFolderSelection = 'Mặc định';
    saveTagState();
    saveFolderState();
    if (docName) docName.value = '';
    if (docText) docText.value = '';
    if (docPreviewTitle) docPreviewTitle.textContent = 'Chưa đặt tên';
    if (docPreviewContent) {
      docPreviewContent.textContent =
        'Nội dung tài liệu sẽ xuất hiện tại đây khi bạn chọn một tài liệu ở cột giữa.';
    }
    renderKdocOutline('');
    setLastModified('-');
    markEditorSaved();
    saveDraft();
    renderFolderSelect();
    renderDocTagEditor();
    renderFolderList();
    renderDocuments([]);
    resetImageGallery('Chưa có ảnh cho tài liệu này.');
    setImageUploadStatus('Chưa có ảnh tải lên.', 'info');
    setStatus('Đã xóa toàn bộ tài liệu.', 'ok');
  } catch (e) {
    setStatus('Xóa lỗi: ' + e.message, 'warn');
  } finally {
    if (clearBtn) clearBtn.disabled = false;
  }
}

async function handleFile(file) {
  if (!file || !docText || !docName) return;
  try {
    const text = await file.text();
    docText.value = text;
    if (!docName.value.trim()) {
      docName.value = file.name;
    }
    onEditorInput();
    setStatus('Đã đọc file: ' + file.name, 'info');
  } catch (err) {
    setStatus('Không đọc được file: ' + err.message, 'warn');
  }
}

function bindShortcuts() {
  document.addEventListener('keydown', function (ev) {
    if (!(ev.ctrlKey || ev.metaKey)) {
      return;
    }

    const key = String(ev.key || '').toLowerCase();
    if (key === 's') {
      ev.preventDefault();
      uploadDocument();
      return;
    }

    if (key === 'f') {
      ev.preventDefault();
      if (sidebarSearch) {
        sidebarSearch.focus();
        sidebarSearch.select();
      }
    }
  });
}

function bindEvents() {
  if (viewTextBtn) {
    viewTextBtn.addEventListener('click', function () {
      setViewMode('text');
    });
  }

  if (viewKdocBtn) {
    viewKdocBtn.addEventListener('click', function () {
      setViewMode('kdoc');
    });
  }

  if (docFileMirror) {
    docFileMirror.addEventListener('change', function (e) {
      const file = e.target.files && e.target.files[0];
      if (file) handleFile(file);
    });
  }

  if (openDocFileBtn && docFileMirror) {
    openDocFileBtn.addEventListener('click', function () {
      docFileMirror.click();
    });
  }

  if (imageFileInput) {
    imageFileInput.addEventListener('change', async function (e) {
      const files = e.target.files || [];
      await uploadImageFiles(files);
    });
  }

  if (pickImageBtn && imageFileInput) {
    pickImageBtn.addEventListener('click', function () {
      imageFileInput.click();
    });
  }

  if (insertImageBtn && imageFileInput) {
    insertImageBtn.addEventListener('click', function () {
      imageFileInput.click();
    });
  }

  if (imageDropZone) {
    imageDropZone.addEventListener('click', function () {
      imageFileInput?.click();
    });
    imageDropZone.addEventListener('keydown', function (event) {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        imageFileInput?.click();
      }
    });
    imageDropZone.addEventListener('dragover', function (event) {
      event.preventDefault();
      imageDropZone.classList.add('is-dragover');
    });
    imageDropZone.addEventListener('dragleave', function () {
      imageDropZone.classList.remove('is-dragover');
    });
    imageDropZone.addEventListener('drop', async function (event) {
      event.preventDefault();
      imageDropZone.classList.remove('is-dragover');
      const files = event.dataTransfer?.files || [];
      await uploadImageFiles(files);
    });
  }

  if (uploadBtn) uploadBtn.addEventListener('click', uploadDocument);
  if (refreshBtn) {
    refreshBtn.addEventListener('click', async function () {
      try {
        if (!(await canDiscardUnsaved('làm mới danh sách'))) return;
        await refreshDocuments();
      } catch (e) {
        renderListState('Không tải được danh sách tài liệu: ' + e.message, 'error');
        setStatus('Lỗi làm mới: ' + e.message, 'warn');
      }
    });
  }

  if (clearBtn) clearBtn.addEventListener('click', clearDocuments);

  if (exportAllBtn) {
    exportAllBtn.addEventListener('click', function () {
      exportAllData();
    });
  }

  if (importAllBtn && importAllInput) {
    importAllBtn.addEventListener('click', function () {
      importAllInput.click();
    });
    importAllInput.addEventListener('change', function (event) {
      const file = event.target?.files && event.target.files[0];
      if (!file) return;
      importAllDataFromFile(file);
    });
  }

  if (dataTabButtons && dataTabButtons.length > 0) {
    dataTabButtons.forEach((btn) => {
      btn.addEventListener('click', function () {
        const tab = btn.getAttribute('data-data-tab');
        if (!tab) return;
        setDataTab(tab);
      });
    });
  }

  if (docFilterInput) {
    docFilterInput.addEventListener('input', function () {
      renderDocuments(documentsCache);
    });
  }

  if (sidebarSearch) {
    sidebarSearch.addEventListener('input', function () {
      renderDocuments(documentsCache);
    });
  }

  if (docSortSelect) {
    docSortSelect.addEventListener('change', function () {
      renderDocuments(documentsCache);
    });
  }

  if (addFolderBtn) {
    addFolderBtn.addEventListener('click', async function () {
      const rawName = await showPrompt('Nhập tên thư mục mới:', {
        title: 'Tạo thư mục',
        confirmText: 'Tạo',
        cancelText: 'Hủy',
        placeholder: 'Ví dụ: Sản phẩm mới',
        inputLabel: 'Tên thư mục mới',
      });
      const folderName = sanitizeFolderName(rawName);
      if (!folderName) return;
      if (folderName === 'Tất cả') {
        setStatus('Tên thư mục "Tất cả" đã được hệ thống sử dụng.', 'warn');
        return;
      }
      ensureFolder(folderName);
      saveFolderState();
      renderFolderSelect();
      renderFolderList();
      setStatus('Đã tạo thư mục "' + folderName + '".', 'ok');
    });
  }

  if (docFolderSelect) {
    docFolderSelect.addEventListener('change', function () {
      const selectedFolder = sanitizeFolderName(docFolderSelect.value) || 'Mặc định';
      ensureFolder(selectedFolder);
      pendingFolderSelection = selectedFolder;
      if (selectedDocName) {
        setDocFolder(selectedDocName, selectedFolder);
        setStatus('Đã cập nhật thư mục cho tài liệu hiện tại.', 'info');
      } else {
        setStatus('Đã chọn thư mục cho tài liệu mới. Thư mục sẽ áp dụng khi bạn lưu.', 'info');
      }
      renderFolderList();
      renderDocuments(documentsCache);
    });
  }

  if (addDocTagBtn) {
    addDocTagBtn.addEventListener('click', function () {
      const docForTags = getCurrentTagDocName();
      if (!docForTags) {
        setStatus('Hãy nhập tên tài liệu trước khi thêm nhãn.', 'warn');
        return;
      }
      const candidate = sanitizeTag(docTagInput?.value || '');
      if (!candidate) {
        setStatus('Vui lòng nhập nhãn hợp lệ.', 'warn');
        return;
      }
      const currentTags = getDocTags(docForTags, { name: docForTags }, false);
      setDocTags(docForTags, currentTags.concat([candidate]));
      if (docTagInput) docTagInput.value = '';
      renderDocTagEditor();
      renderDocuments(documentsCache);
      setStatus('Đã thêm nhãn cho tài liệu.', 'ok');
    });
  }

  if (docTagInput) {
    docTagInput.addEventListener('keydown', function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        addDocTagBtn?.click();
      }
    });
  }

  if (newNoteBtn) {
    newNoteBtn.addEventListener('click', async function () {
      if (!(await canDiscardUnsaved('tạo tài liệu tri thức mới'))) {
        return;
      }
      selectedDocName = '';
      pendingFolderSelection = activeFolder !== '__ALL__' ? activeFolder : 'Mặc định';
      if (docName) docName.value = '';
      if (docText) docText.value = '';
      if (docPreviewTitle) docPreviewTitle.textContent = 'Chưa đặt tên';
      if (docPreviewContent) {
        docPreviewContent.textContent =
          'Nội dung tài liệu sẽ xuất hiện tại đây khi bạn chọn một tài liệu ở cột giữa.';
      }
      renderKdocOutline('');
      setLastModified('-');
      markEditorSaved();
      saveDraft();
      renderFolderSelect();
      renderDocTagEditor();
      setStatus('Đang tạo tài liệu tri thức mới.', 'info');
      resetImageGallery('Nhập tên tài liệu để bắt đầu tải ảnh.');
      setImageUploadStatus('Hãy nhập tên tài liệu trước khi tải ảnh.', 'info');
      renderDocuments(documentsCache);
      docName?.focus();
    });
  }

  templateButtons.forEach(function (btn) {
    btn.addEventListener('click', function () {
      const key = btn.getAttribute('data-template');
      const block = templateMap[key] || '';
      if (!block || !docText) return;
      const current = (docText.value || '').trim();
      docText.value = current ? current + '\n\n' + block : block;
      if (docName && !docName.value.trim() && key !== 'synonyms') {
        docName.value = `${key || 'document'}_${Date.now()}.txt`;
      }
      docText.focus();
      onEditorInput();
      setStatus('Đã chèn block mẫu.', 'info');
    });
  });

  if (docName) {
    docName.addEventListener('input', function () {
      onEditorInput();
      renderDocTagEditor();
      if (!selectedDocName) {
        const typedName = String(docName.value || '').trim();
        if (typedName) {
          scheduleImageFetch(typedName);
        } else {
          resetImageGallery('Nhập tên tài liệu để bắt đầu tải ảnh.');
        }
      }
    });
  }
  if (docText) docText.addEventListener('input', onEditorInput);
  if (kdocOutlineBody) {
    kdocOutlineBody.addEventListener('input', function (event) {
      const target = event.target;
      if (!target || !target.classList || !target.classList.contains('kdoc-field')) {
        return;
      }
      syncTextFromKdocFields();
    });
  }

  window.addEventListener('beforeunload', function (event) {
    if (!isDirty) return;
    event.preventDefault();
    event.returnValue = '';
  });
}

(async function boot() {
  loadFolderState();
  loadTagState();
  setLastModified('-');
  markEditorSaved();
  resetImageGallery('Nhập tên tài liệu để bắt đầu tải ảnh.');
  setImageUploadStatus('Chưa có ảnh tải lên.', 'info');
  renderKdocOutline(docText?.value || '');
  renderFolderList();
  renderFolderSelect();
  renderDocTagEditor();
  setViewMode(localStorage.getItem(VIEW_MODE_KEY) || 'text');
  bindModalEvents();
  bindEvents();
  bindShortcuts();
  setDataTab('export');
  loadDraft();
  await refreshHostInfo();
  try {
    await refreshDocuments({ silentStatus: true });
    if (!isDirty) {
      setStatus('Sẵn sàng.', 'info');
    }
  } catch (e) {
    renderListState('Không tải được danh sách tài liệu: ' + e.message, 'error');
    setStatus('Không tải được danh sách: ' + e.message, 'warn');
  }
})();
