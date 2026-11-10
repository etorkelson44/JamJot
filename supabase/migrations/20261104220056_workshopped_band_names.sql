-- Founder-directed 2026-11-04: the Market carries exactly six avatars with
-- the founder's workshopped music-pun names (Sonatina Sprout is free and
-- never sold). Existing IDs/ownership preserved; other avatars retired from
-- sale (purchases and worn avatars untouched).
update public.market_items set title='Strawberry Staccato', description='Short and sweet!'
  where stand='jamjot' and kind='avatar' and asset_key='strawberry';
update public.market_items set title='Jalapresto', description='As fast as it gets. As hot as it gets.'
  where stand='jamjot' and kind='avatar' and asset_key='jalapeno';
update public.market_items set title='Grape Arpeggio', description='A bunch of notes, climbing.'
  where stand='jamjot' and kind='avatar' and asset_key='grape';
update public.market_items set title='Lemon Sharp', description='Not sour — sharp. L♯.'
  where stand='jamjot' and kind='avatar' and asset_key='lemon';
update public.market_items set title='Blueberry Bebop', description='Cool berry, hot licks.'
  where stand='jamjot' and kind='avatar' and asset_key='blueberry';
update public.market_items set title='Reggae Raspberry', description='One love, one beat.'
  where stand='jamjot' and kind='avatar' and asset_key='raspberry';

insert into public.market_items (id, stand, kind, asset_key, title, description, emoji, price, active)
select 'f3b2a1c0-55d4-4f6e-9a21-8e7c6d5b4a39', 'jamjot', 'avatar', 'raspberry',
       'Reggae Raspberry', 'One love, one beat.', '🫐', 25, true
where not exists (select 1 from public.market_items where stand='jamjot' and kind='avatar' and asset_key='raspberry');

-- Retire everything else from the JamJot avatar stand.
update public.market_items set active=false
  where stand='jamjot' and kind='avatar'
    and asset_key not in ('strawberry','jalapeno','grape','lemon','raspberry','blueberry');
