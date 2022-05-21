from brownie import accounts, config, BettingGame, network
from scripts.scripts import *

GAME_TYPES = ["UNICONDITIONAL", "MULTICONDITIONAL", "HIGH_SCORE"]
BET_TYPES = ["FIXED", "FREE"]


def deploy_betting_game(entry_fee, bet_type, game_type):
    print("Deploying ...")

    account = get_account()
    price_feed = get_pricefeed()

    game = BettingGame.deploy(
        price_feed, entry_fee, bet_type, game_type, {"from": account}
    )

    return game
