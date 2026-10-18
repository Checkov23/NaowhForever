import importlib.util
import json
import unittest
from pathlib import Path


MODULE = Path(__file__).parents[1] / "build" / "vendor_spots.py"
SPEC = importlib.util.spec_from_file_location("vendor_spots", MODULE)
vendor_spots = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(vendor_spots)


class VendorSpotsTest(unittest.TestCase):
    def test_reads_reagents_and_town_seller_names(self):
        reagents = vendor_spots.reagent_ids("return { [20] = true, [10]=true, [20] = true }")
        towns = vendor_spots.town_names('    { 12.5, 34, "trade", "Seller One", "Supplies", nil, "A" },\n')
        self.assertEqual([10, 20], reagents)
        self.assertEqual({"Seller One"}, towns)

    def test_keeps_only_known_unlimited_sellers_deterministically(self):
        rows = {
            "10": ["Seller Two", "Missing", "Seller One"],
            "20": ["Seller Two"],
        }
        text, by_item, names = vendor_spots.render(rows, [10, 20], {"Seller One", "Seller Two"})
        self.assertEqual({10: ["Seller One", "Seller Two"], 20: ["Seller Two"]}, by_item)
        self.assertEqual(["Seller One", "Seller Two"], names)
        self.assertIn('[10] = { 1, 2 }', text)
        self.assertIn('[20] = { 2 }', text)

    def test_checked_in_catalog_is_complete_and_current(self):
        rows = json.loads(vendor_spots.CACHE.read_text(encoding="utf-8"))
        text, by_item, _ = vendor_spots.render(rows)
        checked_in = vendor_spots.OUT.read_text(encoding="utf-8")
        self.assertTrue(all(by_item.values()))
        self.assertEqual(text.replace("\r\n", "\n"), checked_in.replace("\r\n", "\n"))


if __name__ == "__main__":
    unittest.main()
