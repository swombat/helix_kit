export const MIME_TO_EXTENSION = {
  'image/png': '.png',
  'image/jpeg': '.jpg,.jpeg',
  'image/jpg': '.jpg',
  'image/gif': '.gif',
  'image/webp': '.webp',
  'image/bmp': '.bmp',
  'audio/mpeg': '.mp3',
  'audio/wav': '.wav',
  'audio/m4a': '.m4a',
  'audio/ogg': '.ogg',
  'audio/flac': '.flac',
  'video/mp4': '.mp4',
  'video/quicktime': '.mov',
  'video/x-msvideo': '.avi',
  'video/webm': '.webm',
  'application/pdf': '.pdf',
  'application/msword': '.doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
  'text/plain': '.txt',
  'text/markdown': '.md',
  'text/csv': '.csv',
};

export function acceptAttributeFor({ allowedTypes = [], allowedExtensions = [] } = {}) {
  const fromMimeTypes = allowedTypes.map((type) => MIME_TO_EXTENSION[type] || '').filter(Boolean);
  return [...new Set([...fromMimeTypes, ...allowedExtensions])].join(',');
}

export function getFileExtension(filename) {
  const lastDot = filename.lastIndexOf('.');
  return lastDot !== -1 ? filename.slice(lastDot).toLowerCase() : '';
}

export function validateUploadFile(file, { maxSize, allowedTypes = [], allowedExtensions = [] }) {
  const extension = getFileExtension(file.name);
  const typeAllowed = allowedTypes.includes(file.type);
  const extensionAllowed = allowedExtensions.includes(extension);

  if (!typeAllowed && !extensionAllowed) {
    return 'File type not supported. Please upload images, audio, video, or documents.';
  }

  if (file.size > maxSize) {
    return `File too large. Maximum size is ${maxSize / (1024 * 1024)}MB.`;
  }

  return null;
}

export function addUploadFiles(files, selectedFiles, options) {
  const { maxFiles } = options;

  if (files.length + selectedFiles.length > maxFiles) {
    return { files, error: `Maximum ${maxFiles} files allowed.` };
  }

  for (const file of selectedFiles) {
    const validationError = validateUploadFile(file, options);
    if (validationError) return { files, error: validationError };
  }

  return { files: [...files, ...selectedFiles], error: null };
}

export function removeUploadFile(files, index) {
  return files.filter((_, i) => i !== index);
}

export function formatFileSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
