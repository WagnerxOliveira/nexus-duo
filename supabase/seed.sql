-- =============================================================================
-- Seed Data: NEXUS DUO Games Catalog (36 Popular Titles — Official CDN URLs)
-- Zero Storage Footprint: Cover art served directly from official IGDB/Steam CDNs
-- Idempotent: Safe to re-run via ON CONFLICT (slug) DO UPDATE
-- =============================================================================

INSERT INTO public.games_catalog (
  external_source,
  external_id,
  title,
  slug,
  cover_url,
  genres,
  platforms,
  supports_crossplay
)
VALUES
  (
    'igdb', '126459', 'Valorant', 'valorant',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co2mvt.jpg',
    ARRAY['fps', 'tactical', 'shooter', 'competitive'],
    ARRAY['pc', 'ps5', 'xbox'],
    false
  ),
  (
    'igdb', '115', 'League of Legends', 'league-of-legends',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co49wj.jpg',
    ARRAY['moba', 'strategy', 'competitive'],
    ARRAY['pc'],
    false
  ),
  (
    'steam', '730', 'Counter-Strike 2', 'counter-strike-2',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/730/library_600x900.jpg',
    ARRAY['fps', 'tactical', 'shooter', 'competitive'],
    ARRAY['pc', 'steam_deck'],
    false
  ),
  (
    'steam', '413150', 'Stardew Valley', 'stardew-valley',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/413150/library_600x900.jpg',
    ARRAY['cozy', 'simulation', 'rpg', 'coop', 'indie'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch', 'mobile', 'steam_deck'],
    false
  ),
  (
    'igdb', '119277', 'Genshin Impact', 'genshin-impact',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co48z7.jpg',
    ARRAY['rpg', 'action', 'open-world', 'coop', 'anime'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'mobile'],
    true
  ),
  (
    'igdb', '121', 'Minecraft', 'minecraft',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co49x5.jpg',
    ARRAY['sandbox', 'survival', 'cozy', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch', 'mobile', 'steam_deck'],
    true
  ),
  (
    'steam', '1086940', 'Baldur''s Gate 3', 'baldurs-gate-3',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1086940/library_600x900.jpg',
    ARRAY['rpg', 'strategy', 'story-rich', 'coop'],
    ARRAY['pc', 'ps5', 'xbox', 'steam_deck'],
    true
  ),
  (
    'steam', '1245620', 'Elden Ring', 'elden-ring',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1245620/library_600x900.jpg',
    ARRAY['soulslike', 'rpg', 'action', 'open-world', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'steam_deck'],
    false
  ),
  (
    'igdb', '1905', 'Fortnite', 'fortnite',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co2ekt.jpg',
    ARRAY['battle-royale', 'shooter', 'casual', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch', 'mobile'],
    true
  ),
  (
    'steam', '252950', 'Rocket League', 'rocket-league',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/252950/library_600x900.jpg',
    ARRAY['sports', 'arcade', 'competitive', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch'],
    true
  ),
  (
    'steam', '2669320', 'EA SPORTS FC 25', 'ea-sports-fc-25',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/2669320/library_600x900.jpg',
    ARRAY['sports', 'simulation', 'competitive', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch'],
    true
  ),
  (
    'steam', '1426210', 'It Takes Two', 'it-takes-two',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1426210/library_600x900.jpg',
    ARRAY['coop', 'adventure', 'platformer', 'puzzle', 'story-rich'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch', 'steam_deck'],
    false
  ),
  (
    'steam', '553850', 'Helldivers 2', 'helldivers-2',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/553850/library_600x900.jpg',
    ARRAY['shooter', 'coop', 'action', 'sci-fi'],
    ARRAY['pc', 'ps5'],
    true
  ),
  (
    'steam', '1172470', 'Apex Legends', 'apex-legends',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1172470/library_600x900.jpg',
    ARRAY['fps', 'battle-royale', 'shooter', 'competitive'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch'],
    true
  ),
  (
    'steam', '2357570', 'Overwatch 2', 'overwatch-2',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/2357570/library_600x900.jpg',
    ARRAY['fps', 'hero-shooter', 'competitive', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch'],
    true
  ),
  (
    'steam', '570', 'Dota 2', 'dota-2',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/570/library_600x900.jpg',
    ARRAY['moba', 'strategy', 'competitive'],
    ARRAY['pc'],
    false
  ),
  (
    'steam', '2344520', 'Diablo IV', 'diablo-iv',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/2344520/library_600x900.jpg',
    ARRAY['arpg', 'rpg', 'action', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'steam_deck'],
    true
  ),
  (
    'steam', '105600', 'Terraria', 'terraria',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/105600/library_600x900.jpg',
    ARRAY['sandbox', 'adventure', 'indie', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch', 'mobile', 'steam_deck'],
    false
  ),
  (
    'steam', '381210', 'Dead by Daylight', 'dead-by-daylight',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/381210/library_600x900.jpg',
    ARRAY['horror', 'asymmetric', 'survival', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch', 'steam_deck'],
    true
  ),
  (
    'steam', '1966720', 'Lethal Company', 'lethal-company',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1966720/library_600x900.jpg',
    ARRAY['horror', 'coop', 'indie', 'comedy'],
    ARRAY['pc', 'steam_deck'],
    false
  ),
  (
    'steam', '1623730', 'Palworld', 'palworld',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1623730/library_600x900.jpg',
    ARRAY['survival', 'open-world', 'creature-collector', 'coop'],
    ARRAY['pc', 'ps5', 'xbox', 'steam_deck'],
    true
  ),
  (
    'steam', '582010', 'Monster Hunter: World', 'monster-hunter-world',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/582010/library_600x900.jpg',
    ARRAY['action', 'rpg', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'steam_deck'],
    false
  ),
  (
    'igdb', '123', 'World of Warcraft', 'world-of-warcraft',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co2lbd.jpg',
    ARRAY['mmorpg', 'rpg', 'coop', 'fantasy'],
    ARRAY['pc'],
    false
  ),
  (
    'steam', '39210', 'Final Fantasy XIV Online', 'final-fantasy-xiv',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/39210/library_600x900.jpg',
    ARRAY['mmorpg', 'rpg', 'story-rich', 'coop'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox'],
    true
  ),
  (
    'steam', '359550', 'Tom Clancy''s Rainbow Six Siege', 'rainbow-six-siege',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/359550/library_600x900.jpg',
    ARRAY['fps', 'tactical', 'shooter', 'competitive'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox'],
    true
  ),
  (
    'steam', '1962663', 'Call of Duty: Warzone', 'call-of-duty-warzone',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1962663/library_600x900.jpg',
    ARRAY['fps', 'battle-royale', 'shooter', 'competitive'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox'],
    true
  ),
  (
    'steam', '1364780', 'Street Fighter 6', 'street-fighter-6',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1364780/library_600x900.jpg',
    ARRAY['fighting', 'competitive', 'arcade'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'steam_deck'],
    true
  ),
  (
    'steam', '1778820', 'TEKKEN 8', 'tekken-8',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1778820/library_600x900.jpg',
    ARRAY['fighting', 'competitive', 'action'],
    ARRAY['pc', 'ps5', 'xbox', 'steam_deck'],
    true
  ),
  (
    'steam', '367520', 'Hollow Knight', 'hollow-knight',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/367520/library_600x900.jpg',
    ARRAY['metroidvania', 'indie', 'platformer', 'adventure'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch', 'steam_deck'],
    false
  ),
  (
    'steam', '1145360', 'Hades', 'hades',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1145360/library_600x900.jpg',
    ARRAY['roguelike', 'indie', 'action', 'story-rich'],
    ARRAY['pc', 'ps5', 'ps4', 'xbox', 'switch', 'mobile', 'steam_deck'],
    false
  ),
  (
    'igdb', '109462', 'Animal Crossing: New Horizons', 'animal-crossing-new-horizons',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co3wls.jpg',
    ARRAY['cozy', 'simulation', 'casual', 'coop'],
    ARRAY['switch'],
    false
  ),
  (
    'igdb', '26758', 'Mario Kart 8 Deluxe', 'mario-kart-8-deluxe',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co213p.jpg',
    ARRAY['racing', 'party', 'casual', 'competitive'],
    ARRAY['switch'],
    false
  ),
  (
    'igdb', '90101', 'Super Smash Bros. Ultimate', 'super-smash-bros-ultimate',
    'https://images.igdb.com/igdb/image/upload/t_cover_big/co2255.jpg',
    ARRAY['fighting', 'party', 'competitive'],
    ARRAY['switch'],
    false
  ),
  (
    'steam', '739630', 'Phasmophobia', 'phasmophobia',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/739630/library_600x900.jpg',
    ARRAY['horror', 'coop', 'indie', 'investigation'],
    ARRAY['pc', 'ps5', 'xbox', 'steam_deck'],
    true
  ),
  (
    'steam', '1172620', 'Sea of Thieves', 'sea-of-thieves',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1172620/library_600x900.jpg',
    ARRAY['adventure', 'coop', 'open-world', 'sandbox'],
    ARRAY['pc', 'ps5', 'xbox', 'steam_deck'],
    true
  ),
  (
    'steam', '2001120', 'Split Fiction', 'split-fiction',
    'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/2001120/library_600x900.jpg',
    ARRAY['coop', 'adventure', 'action', 'story-rich'],
    ARRAY['pc', 'ps5', 'xbox', 'steam_deck'],
    true
  )
ON CONFLICT (slug) DO UPDATE
SET
  title              = EXCLUDED.title,
  cover_url          = EXCLUDED.cover_url,
  genres             = EXCLUDED.genres,
  platforms          = EXCLUDED.platforms,
  supports_crossplay = EXCLUDED.supports_crossplay,
  updated_at         = now();
