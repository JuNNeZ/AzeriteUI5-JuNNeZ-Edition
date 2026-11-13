"""Native underlays may never hide source erasure or change functional glass."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import PriestWarlockAssetContracts as contracts
import PriestWarlockPack as pack


class Composition(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix="azerite-whole-paint-")
        self.root=Path(self.temp.name).resolve()
        self.patches=[patch.object(pack,"ROOT",self.root),patch.object(contracts,"ROOT",self.root)]
        for p in self.patches:p.start()
        for name in ("Assets","Draft","Contracts"):(self.root/name).mkdir()
        self.name="pw_crystal_case"
        native=Image.new("RGBA",(16,16),(100,110,120,150));native.save(self.root/"Assets"/(self.name+".tga"))
        source=Image.new("RGBA",(16,16));draw=ImageDraw.Draw(source)
        draw.rectangle((2,2,13,13),fill=(90,35,130,255));draw.rectangle((4,4,11,11),fill=(0,0,0,0))
        source.save(self.root/"Draft/source.png");source.save(self.root/"Draft/painting.tga")
        mask=Image.new("L",(16,16));ImageDraw.Draw(mask).rectangle((4,4,11,11),fill=255);mask.save(self.root/"Contracts/pane.png")
        self.field={**contracts.record(self.root/"Contracts/pane.png"),"native":contracts.record(self.root/"Assets"/(self.name+".tga")),"bounds":[4,4,12,12]}
        self.fields={"clearance":{self.name:self.field},"nativePanes":{self.name:self.field}}
        self.painting={**contracts.record(self.root/"Draft/painting.tga"),"role":"whole-painting","canvas":[16,16],"source":contracts.record(self.root/"Draft/source.png"),"transform":{"crop":[0,0,16,16],"scale":1,"offset":[0,0]}}
        tint=contracts.native_tint(self.name)
        result=Image.alpha_composite(contracts.underlay(self.name,mask,tint),source);result.save(self.root/"Draft/composed.tga")
        self.item={**contracts.record(self.root/"Draft/composed.tga"),"painting":self.painting,"construction":"native-under-whole-painting","native":self.field["native"],"field":self.field,"nativeTint":tint}

    def tearDown(self):
        for p in reversed(self.patches):p.stop()
        self.temp.cleanup()

    def test_source_and_native_glass_both_survive_exactly(self):
        painting,composed=pack.replay_composed(self.name,self.item,self.fields)
        self.assertEqual(composed.getpixel((3,3)),painting.getpixel((3,3)))
        self.assertEqual(composed.getpixel((8,8)),(75,83,90,150))

    def test_erased_paint_fails_even_with_updated_export_hash(self):
        path=self.root/"Draft/painting.tga";image=pack.read(path);image.putpixel((3,3),(0,0,0,0));image.save(path)
        item=copy.deepcopy(self.item);item["painting"].update(contracts.record(path))
        with self.assertRaisesRegex(ValueError,"SOURCE RGBA changed"):pack.replay_composed(self.name,item,self.fields)

    def test_unrecognized_stencil_flag_is_rejected(self):
        with self.assertRaisesRegex(AssertionError,"Unsupported composition"):
            pack.replay_composed(self.name,{**self.item,"eraseFill":True},self.fields)

    def test_native_glass_tint_cannot_be_redeclared(self):
        with self.assertRaisesRegex(AssertionError,"brightness changed"):
            pack.replay_composed(self.name,{**self.item,"nativeTint":.5},self.fields)

    def test_changed_native_pixels_cannot_replace_frozen_authority(self):
        path=self.root/"Assets"/(self.name+".tga");image=pack.read(path);image.putpixel((8,8),(255,255,255,255));image.save(path)
        with self.assertRaisesRegex(AssertionError,"frozen field authority"):
            pack.replay_composed(self.name,{**self.item,"native":contracts.record(path)},self.fields)

    def bridge_item(self):
        bridge=self.root/"Contracts/bridge.png"
        Image.new("L",(16,16),0).save(bridge)
        approval=self.root/"Contracts/approval.json"
        import json
        approval.write_text(json.dumps({"maintainerApproved":True,
            "sourceSha256":self.painting["source"]["sha256"],"bridgeSha256":contracts.sha(bridge)}))
        return {**self.painting,"bridge":contracts.record(bridge),"bridgeApproval":contracts.record(approval)}

    def test_exact_approved_bridge_keeps_whole_source_replay(self):
        item=self.bridge_item()
        pack.replay_painting(item)
        self.assertEqual(pack.approved_bridge(item).size,(16,16))

    def test_changed_bridge_source_cannot_reuse_approval(self):
        item=self.bridge_item()
        item["source"]={**item["source"],"sha256":"different"}
        with self.assertRaisesRegex(AssertionError,"source changed"):
            pack.approved_bridge(item)

    def test_changed_bridge_mask_cannot_reuse_approval(self):
        item=self.bridge_item()
        mask=self.root/item["bridge"]["path"]
        image=Image.open(mask);image.putpixel((5,5),255);image.save(mask)
        item["bridge"]=contracts.record(mask)
        with self.assertRaisesRegex(AssertionError,"mask changed"):
            pack.approved_bridge(item)

    def test_native_shadow_selector_rejects_exposed_metal(self):
        mask=self.root/"Contracts/pane.png"
        original=self.root/"Contracts/original.png"
        Image.open(mask).save(original)
        fields={"nativePanes":{self.name:self.field},"nativePaneExtensions":{
            self.name:{"construction":"exact-native-black-shadow-1","original":contracts.record(original)}}}
        with patch.object(pack,"native_pane_mask",return_value=Image.open(original)):
            pack.validate_native_shadows(fields)
        image=Image.open(mask);image.putpixel((3,3),255);image.save(mask)
        fields["nativePanes"][self.name]={**self.field,**contracts.record(mask)}
        with patch.object(pack,"native_pane_mask",return_value=Image.open(original)), self.assertRaisesRegex(AssertionError,"shadow selector changed"):
            pack.validate_native_shadows(fields)


if __name__=="__main__":unittest.main()
