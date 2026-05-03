import { describe, expect, test } from 'vitest';
import {
  acceptAttributeFor,
  addUploadFiles,
  formatFileSize,
  removeUploadFile,
  validateUploadFile,
} from './file-upload-rules';

const file = (name, type, size = 10) => ({ name, type, size });

describe('file upload rules', () => {
  test('builds a deduplicated accept attribute from MIME types and explicit extensions', () => {
    expect(
      acceptAttributeFor({
        allowedTypes: ['image/png', 'application/pdf', 'unknown/type'],
        allowedExtensions: ['.png', '.heic'],
      })
    ).toBe('.png,.pdf,.heic');
  });

  test('accepts files by MIME type or filename extension', () => {
    const options = { maxSize: 100, allowedTypes: ['image/png'], allowedExtensions: ['.md'] };

    expect(validateUploadFile(file('photo.bin', 'image/png'), options)).toBeNull();
    expect(validateUploadFile(file('notes.MD', 'text/plain'), options)).toBeNull();
    expect(validateUploadFile(file('script.exe', 'application/x-msdownload'), options)).toMatch(/not supported/);
  });

  test('returns the original file list when a batch exceeds limits or contains invalid files', () => {
    const existing = [file('one.png', 'image/png')];
    const options = { maxFiles: 2, maxSize: 100, allowedTypes: ['image/png'], allowedExtensions: [] };

    expect(addUploadFiles(existing, [file('two.png', 'image/png'), file('three.png', 'image/png')], options)).toEqual({
      files: existing,
      error: 'Maximum 2 files allowed.',
    });
    expect(addUploadFiles(existing, [file('two.exe', 'application/x-msdownload')], options).files).toBe(existing);
  });

  test('adds and removes valid files without mutating the original list', () => {
    const existing = [file('one.png', 'image/png')];
    const nextFile = file('two.png', 'image/png');
    const result = addUploadFiles(existing, [nextFile], {
      maxFiles: 2,
      maxSize: 100,
      allowedTypes: ['image/png'],
      allowedExtensions: [],
    });

    expect(result.files).toEqual([existing[0], nextFile]);
    expect(existing).toHaveLength(1);
    expect(removeUploadFile(result.files, 0)).toEqual([nextFile]);
  });

  test('formats sizes for user-facing attachment labels', () => {
    expect(formatFileSize(512)).toBe('512 B');
    expect(formatFileSize(1536)).toBe('1.5 KB');
    expect(formatFileSize(2 * 1024 * 1024)).toBe('2.0 MB');
  });
});
