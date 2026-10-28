"""Small, original book fixtures; no network or third-party Python packages."""
import sys
import zipfile
from pathlib import Path


def pdf(text):
    stream = f'BT /F1 12 Tf 72 720 Td ({text}) Tj ET'.encode()
    objects = [b'<< /Type /Catalog /Pages 2 0 R >>',
               b'<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
               b'<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
               b'<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
               b'<< /Length ' + str(len(stream)).encode() + b' >>\nstream\n' + stream + b'\nendstream']
    data, offsets = b'%PDF-1.4\n', [0]
    for i, obj in enumerate(objects, 1):
        offsets.append(len(data))
        data += str(i).encode() + b' 0 obj\n' + obj + b'\nendobj\n'
    start = len(data)
    data += f'xref\n0 {len(offsets)}\n0000000000 65535 f \n'.encode()
    data += b''.join(f'{offset:010} 00000 n \n'.encode() for offset in offsets[1:])
    data += f'trailer\n<< /Size {len(offsets)} /Root 1 0 R >>\nstartxref\n{start}\n%%EOF\n'.encode()
    return data


def make(directory):
    root = Path(directory)
    root.mkdir(parents=True, exist_ok=True)
    (root / '编码.txt').write_bytes('第一段中文\n第二段中文'.encode('gb18030'))
    (root / 'UTF16.txt').write_bytes('UTF16 中文'.encode('utf-16'))
    (root / '笔记.md').write_text('# 标题\n\n正文', encoding='utf-8')
    (root / '网页.html').write_text('<html><head><title>隐藏标题</title></head><body><h1>正文标题</h1><p>甲<strong>乙</strong>&amp;丙</p><script>坏代码</script></body></html>', encoding='utf-8')
    (root / '小说.fb2').write_text('<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0"><description><p>元数据</p></description><body><section><title><p>章节</p></title><p>中文<emphasis>正文</emphasis></p></section></body></FictionBook>', encoding='utf-8')
    with zipfile.ZipFile(root / '文档.docx', 'w') as archive:
        archive.writestr('word/document.xml', '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>第一段</w:t></w:r><w:r><w:t>中文</w:t></w:r></w:p><w:p><w:r><w:t>第二段</w:t></w:r></w:p></w:body></w:document>')
    with zipfile.ZipFile(root / '文档.odt', 'w') as archive:
        archive.writestr('content.xml', '<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"><office:body><office:text><text:h>标题</text:h><text:p>开放文档正文</text:p></office:text></office:body></office:document-content>')
    with zipfile.ZipFile(root / '书 籍$epub.EPUB', 'w') as archive:
        archive.writestr('mimetype', 'application/epub+zip')
        archive.writestr('META-INF/container.xml', '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OPS/book.opf"/></rootfiles></container>')
        archive.writestr('OPS/book.opf', '<package xmlns="http://www.idpf.org/2007/opf"><manifest><item id="two" href="second.xhtml" media-type="application/xhtml+xml"/><item id="one" href="%E7%AC%AC%E4%B8%80.xhtml#start" media-type="application/xhtml+xml"/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="one"/><itemref idref="two"/><itemref idref="nav" linear="no"/></spine></package>')
        archive.writestr('OPS/second.xhtml', '<html><body><p>第二章</p><p>后面的正文</p></body></html>')
        archive.writestr('OPS/第一.xhtml', '<html><body><h1>第一章</h1><p>前面的正文</p></body></html>')
        archive.writestr('OPS/nav.xhtml', '<html><body><p>不该读到目录</p></body></html>')
    (root / '测试.pdf').write_bytes(pdf('Readable PDF text'))
    (root / '扫描.pdf').write_bytes(pdf(''))
    (root / '损坏.epub').write_bytes(b'not a ZIP')
    (root / '未知.bin').write_bytes(b'binary')
    (root / 'Kindle.mobi').write_bytes(b'fixture for missing converter error')
    return root


if __name__ == '__main__':
    make(sys.argv[1])
