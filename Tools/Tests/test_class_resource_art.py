"""Negative controls for the neutral resource-field conversion and replay."""
from pathlib import Path
import copy,json,runpy,tempfile,unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
BUILDER=runpy.run_path(str(ROOT/'Tools/Build-ClassResourceArt.py'))

class FieldReplayTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(dir=ROOT/'.research/tmp',prefix='resource-art-test-')
        self.directory=Path(self.temp.name).resolve()
        assert self.directory.is_relative_to(ROOT.resolve())
    def tearDown(self): self.temp.cleanup()
    def source(self,im):
        path=self.directory/'source.png';im.save(path);return path
    def test_installed_whole_source_replay(self):
        m=json.loads((BUILDER['DRAFT']/'resource-field-manifest.json').read_text())
        self.assertEqual({item['family'] for item in m['atlases']},set(BUILDER['FAMILIES']))
        self.assertEqual(BUILDER['verify'](m,installed=True),9)
    def test_transparent_field_rejected(self):
        im=Image.new('RGBA',(128,128),(50,50,50,255));im.putpixel((64,64),(50,50,50,0))
        with self.assertRaisesRegex(AssertionError,'opaque'):BUILDER['expected'](self.source(im))
    def test_coloured_field_rejected(self):
        with self.assertRaisesRegex(AssertionError,'neutral'):
            BUILDER['expected'](self.source(Image.new('RGBA',(128,128),(255,0,0,255))))
    def test_nonuniform_source_rejected(self):
        with self.assertRaisesRegex(AssertionError,'square'):
            BUILDER['expected'](self.source(Image.new('RGBA',(128,64),(30,30,30,255))))
    def test_changed_pixels_rejected_even_with_updated_export_hash(self):
        m=copy.deepcopy(json.loads((BUILDER['DRAFT']/'resource-field-manifest.json').read_text()))
        item=m['atlases'][0]
        im=Image.open(ROOT/item['export']).convert('RGBA')
        im.putpixel((200,300),(255,0,0,255))
        changed=self.directory/'changed.tga';im.save(changed)
        item['export']=str(changed.relative_to(ROOT));item['exportSha256']=BUILDER['digest'](changed)
        with self.assertRaisesRegex(AssertionError,'replay mismatch'):BUILDER['verify'](m)
    def test_source_hash_change_rejected(self):
        m=json.loads((BUILDER['DRAFT']/'resource-field-manifest.json').read_text())
        m['atlases'][0]['sourceSha256']='0'*64
        with self.assertRaisesRegex(AssertionError,'source changed'):BUILDER['verify'](m)

    def test_missing_family_rejected(self):
        m=json.loads((BUILDER['DRAFT']/'resource-field-manifest.json').read_text())
        m['atlases'].pop()
        with self.assertRaisesRegex(AssertionError,'inventory'):BUILDER['verify'](m)

if __name__=='__main__':unittest.main()
