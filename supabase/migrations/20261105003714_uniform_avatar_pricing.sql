-- Founder direction 2026-11-04: every band avatar costs the same.
update market_items
   set price = 25
 where stand = 'jamjot'
   and asset_key in ('strawberry','jalapeno','grape','lemon','raspberry','blueberry');
