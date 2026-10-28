"""Extract book text using the standard library and optional local converters."""
import argparse
import codecs
import posixpath
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


def decode(data):
    if data.startswith((codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE)):
        return data.decode('utf-16')
    for encoding in ('utf-8-sig', 'gb18030'):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            pass
    raise ValueError('无法识别文本编码，请先转换成 UTF-8')


def clean(text):
    text = text.replace('\r\n', '\n').replace('\r', '\n').replace('\x0c', '\n')
    text = ''.join(c for c in text if c in '\n\t' or ord(c) >= 32)
    return re.sub(r'\n[ \t]*\n(?:[ \t]*\n)+', '\n\n', text).strip()


class TextHTML(HTMLParser):
    blocks = {'p', 'div', 'br', 'hr', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
              'tr', 'section', 'article', 'blockquote', 'pre'}
    hidden = {'script', 'style', 'head', 'nav'}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.skip = []

    def handle_starttag(self, tag, attrs):
        if tag in self.hidden:
            self.skip.append(tag)
        if not self.skip and tag in self.blocks:
            self.parts.append('\n')

    def handle_endtag(self, tag):
        if self.skip:
            if tag == self.skip[-1]:
                self.skip.pop()
            return
        if tag in self.blocks:
            self.parts.append('\n')

    def handle_data(self, data):
        if not self.skip:
            self.parts.append(re.sub(r'\s+', ' ', data))


def html_text(data):
    parser = TextHTML()
    parser.feed(decode(data))
    return clean(''.join(parser.parts))


def xml(data):
    # XML entities/DTDs are unnecessary in these document containers.
    if b'<!DOCTYPE' in data.upper() or b'<!ENTITY' in data.upper():
        raise ValueError('不支持包含 DTD/实体声明的 XML')
    return ET.fromstring(data)


def member(archive, name):
    name = posixpath.normpath(name)
    if name.startswith(('../', '/')) or name == '..':
        raise ValueError('书籍内部路径无效')
    info = archive.getinfo(name)
    if info.file_size > 32 * 1024 * 1024:
        raise ValueError('书籍内部单个文件超过 32 MiB 限制')
    return archive.read(info)


def epub(path):
    with zipfile.ZipFile(path) as archive:
        container = xml(member(archive, 'META-INF/container.xml'))
        rootfile = container.find('.//{*}rootfile')
        if rootfile is None:
            raise ValueError('EPUB 缺少 package 路径')
        package_path = rootfile.attrib['full-path']
        package = xml(member(archive, package_path))
        manifest = {item.attrib['id']: item for item in package.findall('./{*}manifest/{*}item')}
        chapters = []
        # Spine order is authoritative; ZIP entry order is not reading order.
        for reference in package.findall('./{*}spine/{*}itemref'):
            if reference.get('linear') == 'no':
                continue
            item = manifest[reference.attrib['idref']]
            if item.get('media-type') not in ('application/xhtml+xml', 'text/html'):
                continue
            href = urlsplit(item.attrib['href'])
            if href.scheme or href.netloc:
                raise ValueError('不支持 EPUB 的远程章节资源')
            target = posixpath.join(posixpath.dirname(package_path), unquote(href.path))
            chapters.append(html_text(member(archive, target)))
        return '\n\n'.join(chapters)


def docx(path):
    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    with zipfile.ZipFile(path) as archive:
        root = xml(member(archive, 'word/document.xml'))
    paragraphs = []
    for paragraph in root.findall('.//w:p', ns):
        parts = []
        for node in paragraph.iter():
            if node.tag == '{' + ns['w'] + '}t':
                parts.append(node.text or '')
            elif node.tag in ('{' + ns['w'] + '}br', '{' + ns['w'] + '}cr'):
                parts.append('\n')
            elif node.tag == '{' + ns['w'] + '}tab':
                parts.append('\t')
        paragraphs.append(''.join(parts))
    return '\n'.join(paragraphs)


def fb2(path):
    root = xml(path.read_bytes())
    paragraphs = []
    for body in root.findall('./{*}body'):
        for node in body.iter():
            if node.tag.rsplit('}', 1)[-1] in ('p', 'v', 'subtitle'):
                paragraphs.append(''.join(node.itertext()))
    return '\n'.join(paragraphs)


def odt(path):
    ns = {'text': 'urn:oasis:names:tc:opendocument:xmlns:text:1.0'}
    with zipfile.ZipFile(path) as archive:
        root = xml(member(archive, 'content.xml'))
    paragraphs = []
    for node in root.iter():
        if node.tag in ('{' + ns['text'] + '}p', '{' + ns['text'] + '}h'):
            paragraphs.append(''.join(node.itertext()))
    return '\n'.join(paragraphs)


def convert(path, extension):
    if extension == '.pdf':
        if not shutil.which('pdftotext'):
            raise ValueError('PDF 需要 pdftotext（Poppler）；请安装 poppler-utils')
        result = subprocess.run(['pdftotext', '-enc', 'UTF-8', '-nopgbrk', str(path), '-'],
                                capture_output=True, timeout=60)
        if result.returncode:
            raise ValueError('PDF 转换失败，文件可能损坏或已加密：' + result.stderr.decode('utf-8', 'replace')[-500:])
        text = result.stdout.decode('utf-8')
        if not text.strip():
            raise ValueError('PDF 没有可提取文字，可能是扫描版；请先 OCR')
        return text
    if extension == '.rtf' and shutil.which('pandoc'):
        result = subprocess.run(['pandoc', str(path), '-t', 'plain', '--wrap=none'],
                                capture_output=True, timeout=60)
        if result.returncode:
            raise ValueError('Pandoc 转换失败：' + result.stderr.decode('utf-8', 'replace')[-500:])
        return result.stdout.decode('utf-8')
    if not shutil.which('ebook-convert'):
        raise ValueError(extension + ' 需要 Calibre 的 ebook-convert；RTF 也可使用 pandoc')
    with tempfile.TemporaryDirectory(prefix='moyu-') as directory:
        output = Path(directory) / 'book.txt'
        result = subprocess.run(['ebook-convert', str(path), str(output)], capture_output=True, timeout=60)
        if result.returncode or not output.exists():
            raise ValueError('Calibre 转换失败，文件可能损坏、加密或格式不受支持：'
                             + (result.stderr or result.stdout).decode('utf-8', 'replace')[-500:])
        return decode(output.read_bytes())


def extract(path):
    extension = path.suffix.lower()
    if extension in {'.txt', '.text', '.md', '.markdown'}:
        return decode(path.read_bytes())
    if extension in {'.html', '.htm', '.xhtml'}:
        return html_text(path.read_bytes())
    if extension == '.epub':
        return epub(path)
    if extension == '.docx':
        return docx(path)
    if extension == '.fb2':
        return fb2(path)
    if extension == '.odt':
        return odt(path)
    if extension in {'.pdf', '.mobi', '.azw', '.azw3', '.rtf'}:
        return convert(path, extension)
    raise ValueError('暂不支持的书籍格式：' + extension)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('path', type=Path)
    args = parser.parse_args()
    try:
        text = clean(extract(args.path.resolve()))
        if not text:
            raise ValueError('没有可提取的正文；图片书、扫描件需要先 OCR，加密书籍不受支持')
        sys.stdout.buffer.write(text.encode('utf-8'))
    except (OSError, ValueError, KeyError, RuntimeError, ET.ParseError, zipfile.BadZipFile, subprocess.TimeoutExpired) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
