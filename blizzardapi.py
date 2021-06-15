
from blizzardapi import BlizzardApi

api_client = BlizzardApi("328a05ccfe304690aeff1d789ca2442a", 
                         "c0t1do0AiCJMm54aXx821IJv2CFJhkjw")

# API Endpoint
categories_index = api_client.wow.game_data \
        .get_achievement_categories_index("us", "en_US")

# Wow Classic endpoint
connected_realms_index = api_client.wow.game_data \
        .get_connected_realms_index("us", "en_US", is_classic=True)
