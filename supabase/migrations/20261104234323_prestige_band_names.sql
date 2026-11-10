-- Founder direction 2026-11-04: raspberry and blueberry take formal
-- music-term names matching the rest of the band.
update market_items
   set title = 'Raspberry Rhapsody',
       description = 'One berry, a thousand notes.'
 where asset_key = 'raspberry';

update market_items
   set title = 'Blueberry Bravura',
       description = 'Bold. Brilliant. Blue.'
 where asset_key = 'blueberry';
