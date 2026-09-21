import { showLoader, hideLoader, showAlert } from '../ui.js';
import {
  downloadFile,
  formatBytes,
  readFileAsArrayBuffer,
  getPDFDocument,
  getCleanPdfFilename,
} from '../utils/helpers.js';
import { createIcons, icons } from 'lucide';
import JSZip from 'jszip';
import * as pdfjsLib from 'pdfjs-dist';
import { PDFPageProxy } from 'pdfjs-dist';
import { t } from '../i18n/i18n';
import { loadPdfWithPasswordPrompt } from '../utils/password-prompt.js';

pdfjsLib.GlobalWorkerOptions.workerSrc = new URL(
  'pdfjs-dist/build/pdf.worker.min.mjs',
  import.meta.url
).toString();

let files: File[] = [];

const updateUI = () => {
  const fileDisplayArea = document.getElementById('file-display-area');
  const optionsPanel = document.getElementById('options-panel');
  const dropZone = document.getElementById('drop-zone');

  if (!fileDisplayArea || !optionsPanel || !dropZone) return;

  fileDisplayArea.innerHTML = '';

  if (files.length > 0) {
    optionsPanel.classList.remove('hidden');

    files.forEach((file) => {
      const fileDiv = document.createElement('div');
      fileDiv.className =
        'flex items-center justify-between bg-gray-700 p-3 rounded-lg text-sm';

      const infoContainer = document.createElement('div');
      infoContainer.className = 'flex flex-col overflow-hidden';

      const nameSpan = document.createElement('div');
      nameSpan.className = 'truncate font-medium text-gray-200 text-sm mb-1';
      nameSpan.textContent = file.name;

      const metaSpan = document.createElement('div');
      metaSpan.className = 'text-xs text-gray-400';
      metaSpan.textContent = `${formatBytes(file.size)} • ${t('common.loadingPageCount')}`; // Initial state

      infoContainer.append(nameSpan, metaSpan);

      const removeBtn = document.createElement('button');
      removeBtn.className =
        'ml-4 text-red-400 hover:text-red-300 flex-shrink-0';
      removeBtn.innerHTML = '<i data-lucide="trash-2" class="w-4 h-4"></i>';
      removeBtn.onclick = () => {
        files = [];
        updateUI();
      };

      fileDiv.append(infoContainer, removeBtn);
      fileDisplayArea.appendChild(fileDiv);

      // Fetch page count asynchronously
      readFileAsArrayBuffer(file)
        .then((buffer) => {
          return getPDFDocument(buffer).promise;
        })
        .then((pdf) => {
          metaSpan.textContent = `${formatBytes(file.size)} • ${pdf.numPages} ${pdf.numPages !== 1 ? t('common.pages') : t('common.page')}`;
        })
        .catch((e) => {
          console.warn('Error loading PDF page count:', e);
          metaSpan.textContent = formatBytes(file.size);
        });
    });

    // Initialize icons immediately after synchronous render
    createIcons({ icons });
  } else {
    optionsPanel.classList.add('hidden');
  }
};

const resetState = () => {
  files = [];
  const fileInput = document.getElementById('file-input') as HTMLInputElement;
  if (fileInput) fileInput.value = '';
  const dpiSelect = document.getElementById('png-dpi') as HTMLSelectElement;
  if (dpiSelect) dpiSelect.value = '150';
  updateUI();
};

async function convert() {
  if (files.length === 0) {
    showAlert(
      t('tools:pdfToPng.alert.noFile'),
      t('tools:pdfToPng.alert.noFileExplanation')
    );
    return;
  }
  try {
    const result = await loadPdfWithPasswordPrompt(files[0], files, 0);
    if (!result) return;
    showLoader(t('tools:pdfToPng.loader.converting'));
    const { pdf } = result;

    const dpiInput = document.getElementById('png-dpi') as HTMLSelectElement;
    const dpi = dpiInput ? parseInt(dpiInput.value, 10) : 150;
    const scale = dpi / 72;

    if (pdf.numPages === 1) {
      const page = await pdf.getPage(1);
      const blob = await renderPage(page, scale, dpi);
      downloadFile(blob, getCleanPdfFilename(files[0].name) + '.png');
    } else {
      const zip = new JSZip();
      for (let i = 1; i <= pdf.numPages; i++) {
        const page = await pdf.getPage(i);
        const blob = await renderPage(page, scale, dpi);
        if (blob) {
          zip.file(`page_${i}.png`, blob);
        }
      }

      const zipBlob = await zip.generateAsync({ type: 'blob' });
      downloadFile(zipBlob, getCleanPdfFilename(files[0].name) + '_pngs.zip');
    }

    showAlert(
      t('common.success'),
      t('tools:pdfToPng.alert.conversionSuccess'),
      'success',
      () => {
        resetState();
      }
    );
  } catch (e) {
    console.error(e);
    showAlert(t('common.error'), t('tools:pdfToPng.alert.conversionError'));
  } finally {
    hideLoader();
  }
}

function insertPhysChunk(buf: ArrayBuffer, dpi: number): ArrayBuffer {
  const src = new Uint8Array(buf);
  // PNG pHYs chunk: pixels per meter = dpi * 39.3701
  const ppm = Math.round(dpi * 39.3701);
  // pHYs chunk: length(4) + "pHYs"(4) + Xppm(4) + Yppm(4) + unit(1) + CRC(4) = 21 bytes
  const chunk = new Uint8Array(21);
  const view = new DataView(chunk.buffer);
  view.setUint32(0, 9); // data length: 9 bytes
  chunk[4] = 0x70; chunk[5] = 0x48; chunk[6] = 0x59; chunk[7] = 0x73; // "pHYs"
  view.setUint32(8, ppm);  // X pixels per unit
  view.setUint32(12, ppm); // Y pixels per unit
  chunk[16] = 1; // unit = meter
  // CRC over type + data
  const crc = crc32(chunk.subarray(4, 17));
  view.setUint32(17, crc);

  // Insert after IHDR chunk (PNG signature 8 bytes + IHDR chunk)
  // IHDR chunk starts at byte 8, its total length = 4(len) + 4(type) + 13(data) + 4(crc) = 25
  const insertPos = 8 + 25;
  const result = new Uint8Array(src.length + 21);
  result.set(src.subarray(0, insertPos), 0);
  result.set(chunk, insertPos);
  result.set(src.subarray(insertPos), insertPos + 21);
  return result.buffer;
}

function crc32(data: Uint8Array): number {
  let crc = 0xFFFFFFFF;
  for (let i = 0; i < data.length; i++) {
    crc ^= data[i];
    for (let j = 0; j < 8; j++) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xEDB88320 : 0);
    }
  }
  return (crc ^ 0xFFFFFFFF) >>> 0;
}

async function renderPage(
  page: PDFPageProxy,
  scale: number,
  dpi: number
): Promise<Blob | null> {
  const viewport = page.getViewport({ scale });
  const canvas = document.createElement('canvas');
  const context = canvas.getContext('2d');
  canvas.height = viewport.height;
  canvas.width = viewport.width;

  await page.render({
    canvasContext: context!,
    viewport: viewport,
    canvas,
  }).promise;

  const blob = await new Promise<Blob | null>((resolve) =>
    canvas.toBlob(resolve, 'image/png')
  );
  if (!blob) return null;
  const buf = insertPhysChunk(await blob.arrayBuffer(), dpi);
  return new Blob([buf], { type: 'image/png' });
}

document.addEventListener('DOMContentLoaded', () => {
  const fileInput = document.getElementById('file-input') as HTMLInputElement;
  const dropZone = document.getElementById('drop-zone');
  const processBtn = document.getElementById('process-btn');
  const backBtn = document.getElementById('back-to-tools');
  if (backBtn) {
    backBtn.addEventListener('click', () => {
      window.location.href = import.meta.env.BASE_URL;
    });
  }

  const handleFileSelect = (newFiles: FileList | null) => {
    if (!newFiles || newFiles.length === 0) return;
    const validFiles = Array.from(newFiles).filter(
      (file) => file.type === 'application/pdf'
    );

    if (validFiles.length === 0) {
      showAlert(
        t('tools:pdfToPng.alert.invalidFile'),
        t('tools:pdfToPng.alert.invalidFileExplanation')
      );
      return;
    }

    files = [validFiles[0]];
    updateUI();
  };

  if (fileInput && dropZone) {
    fileInput.addEventListener('change', (e) => {
      handleFileSelect((e.target as HTMLInputElement).files);
    });

    dropZone.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropZone.classList.add('bg-gray-700');
    });

    dropZone.addEventListener('dragleave', (e) => {
      e.preventDefault();
      dropZone.classList.remove('bg-gray-700');
    });

    dropZone.addEventListener('drop', (e) => {
      e.preventDefault();
      dropZone.classList.remove('bg-gray-700');
      handleFileSelect(e.dataTransfer?.files ?? null);
    });

    fileInput.addEventListener('click', () => {
      fileInput.value = '';
    });
  }

  if (processBtn) {
    processBtn.addEventListener('click', convert);
  }
});
