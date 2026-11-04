-- Local release preparation only. Supplied PNGs are temporary artwork.
-- Keep existing strawberry IDs, purchases, availability, and price intact.
update public.market_items
set title = 'Berry Bebop', description = 'Sweet moves and jazzy grooves.', emoji = '🍓'
where stand = 'jamjot' and kind = 'avatar' and asset_key = 'strawberry';

update public.market_items
set title = 'Pepper Presto', description = 'A little spice. A whole lot of tempo.', emoji = '🌶️'
where stand = 'jamjot' and kind = 'avatar' and asset_key = 'jalapeno';

insert into public.market_items (id, stand, kind, asset_key, title, description, emoji, price, active)
select '92569d3c-345c-41ce-a27e-e89734e504b9', 'jamjot', 'avatar', 'strawberry',
       'Berry Bebop', 'Sweet moves and jazzy grooves.', '🍓', 25, true
where not exists (select 1 from public.market_items where stand = 'jamjot' and kind = 'avatar' and asset_key = 'strawberry');

insert into public.market_items (id, stand, kind, asset_key, title, description, emoji, price, active)
select '163b9c5c-7f83-441d-8d0d-6a4b7de1e343', 'jamjot', 'avatar', 'jalapeno',
       'Pepper Presto', 'A little spice. A whole lot of tempo.', '🌶️', 25, true
where not exists (select 1 from public.market_items where stand = 'jamjot' and kind = 'avatar' and asset_key = 'jalapeno');

-- Gracie uses the existing grape key: owned grape avatars keep their identity.
update public.market_items
set title = 'Gracie Grace Note', description = 'A whole bunch of harmony.', emoji = '🍇'
where stand = 'jamjot' and kind = 'avatar' and asset_key = 'grape';

insert into public.market_items (id, stand, kind, asset_key, title, description, emoji, price, active)
select '3c2e22f9-4fad-4694-9ca5-7a76dc27b88d', 'jamjot', 'avatar', 'grape',
       'Gracie Grace Note', 'A whole bunch of harmony.', '🍇', 25, true
where not exists (select 1 from public.market_items where stand = 'jamjot' and kind = 'avatar' and asset_key = 'grape');

-- Lenny retains the existing lemon identity, price, availability and ownership.
update public.market_items
set title = 'Lenny Legato', description = 'A little zest. A smooth melody.', emoji = '🍋'
where stand = 'jamjot' and kind = 'avatar' and asset_key = 'lemon';

insert into public.market_items (id, stand, kind, asset_key, title, description, emoji, price, active)
select '820d75aa-ff72-4b21-81e5-aa44d5795d4c', 'jamjot', 'avatar', 'lemon',
       'Lenny Legato', 'A little zest. A smooth melody.', '🍋', 25, true
where not exists (select 1 from public.market_items where stand = 'jamjot' and kind = 'avatar' and asset_key = 'lemon');
