import importlib.util
import json
import sys
import unittest
from pathlib import Path


BUILD = Path(__file__).parents[1] / "build"
sys.path.insert(0, str(BUILD))
SPEC = importlib.util.spec_from_file_location("vendor_prices", BUILD / "vendor_prices.py")
vendor_prices = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(vendor_prices)

COARSE_THREAD, SEASONING_HERBS = 2320, 2665


class VendorPricesTest(unittest.TestCase):
    def test_keeps_wanted_items_sold_for_copper(self):
        rows = [
            {"ID": "10", "BuyPrice": "25", "VendorStackCount": "5"},
            {"ID": "20", "BuyPrice": "0", "VendorStackCount": "1"},
            {"ID": "30", "BuyPrice": "40", "VendorStackCount": "1"},
            {"ID": "40", "BuyPrice": "7", "VendorStackCount": "0"},
        ]
        self.assertEqual({"10": [25, 5], "40": [7, 1]}, vendor_prices.read_rows([10, 20, 40], rows))

    def test_prices_one_item_of_a_merchant_stack(self):
        self.assertEqual(5, vendor_prices.each_price(25, 5))
        self.assertEqual(2.5, vendor_prices.each_price(5, 2))

    def test_renders_sorted_reagents_and_skips_unpriced_ones(self):
        text, priced = vendor_prices.render({"20": [10, 1], "10": [25, 5]}, [10, 20, 30])
        self.assertEqual([10, 20], priced)
        self.assertIn("    [10] = 5,\r\n    [20] = 10,\r\n}", text)
        self.assertNotIn("[30]", text)

    def test_checked_in_prices_are_current(self):
        rows = json.loads(vendor_prices.CACHE.read_text(encoding="utf-8"))
        text, priced = vendor_prices.render(rows)
        checked_in = vendor_prices.OUT.read_bytes().decode("utf-8")
        self.assertEqual(text, checked_in)
        self.assertEqual(rows[str(COARSE_THREAD)], [10, 1])
        missing = set(vendor_prices.reagent_ids()) - set(priced)
        self.assertEqual({SEASONING_HERBS}, missing)


if __name__ == "__main__":
    unittest.main()
