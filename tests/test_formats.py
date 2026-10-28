import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from extract_book import extract, clean
from make_books import make


class FormatsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = make(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def text(self, name):
        return clean(extract(self.root / name))

    def test_encodings(self):
        self.assertEqual(self.text('编码.txt'), '第一段中文\n第二段中文')
        self.assertEqual(self.text('UTF16.txt'), 'UTF16 中文')

    def test_html(self):
        self.assertEqual(self.text('网页.html'), '正文标题\n\n甲乙&丙')

    def test_epub_spine(self):
        self.assertEqual(self.text('书 籍$epub.EPUB'), '第一章\n\n前面的正文\n\n第二章\n\n后面的正文')

    def test_docx_fb2_markdown(self):
        self.assertEqual(self.text('文档.docx'), '第一段中文\n第二段')
        self.assertEqual(self.text('小说.fb2'), '章节\n中文正文')
        self.assertIn('# 标题', self.text('笔记.md'))
        self.assertEqual(self.text('文档.odt'), '标题\n开放文档正文')

    def test_pdf_and_scan(self):
        self.assertEqual(self.text('测试.pdf'), 'Readable PDF text')
        with self.assertRaisesRegex(ValueError, 'OCR'):
            self.text('扫描.pdf')

    def test_missing_dependencies(self):
        with patch('extract_book.shutil.which', return_value=None):
            with self.assertRaisesRegex(ValueError, 'Calibre'):
                self.text('Kindle.mobi')
            with self.assertRaisesRegex(ValueError, 'pdftotext'):
                self.text('测试.pdf')

    def test_unknown(self):
        with self.assertRaisesRegex(ValueError, '暂不支持'):
            self.text('未知.bin')


if __name__ == '__main__':
    unittest.main()
