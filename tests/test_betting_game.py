from audioop import mul
from difflib import unified_diff
from scripts.scripts import *
from scripts.deploy import BET_TYPES, GAME_TYPES, deploy_betting_game
from brownie import network, accounts, exceptions
import pytest


def test_can_add_condition():
    account = get_account()
    uni_fixed_game = deploy_betting_game(4000, BET_TYPES[0], GAME_TYPES[0])
    condition = "Condition 1"
    uni_fixed_game.addCondition(condition, {"from": account})
    assert uni_fixed_game.conditionExists(condition) == True


def test_can_join_game():
    account = get_account()
    uni_fixed_game = deploy_betting_game(4000, BET_TYPES[0], GAME_TYPES[0])
    entry_fee = uni_fixed_game.getEntranceFee()
    # Contract[-1] gets the latest deployed version of a contract
    rate = MockV3Aggregator[-1].latestRoundData()[1]
    condition = "Condition 1"
    fee_wei = 10 ** 18 / (rate / 10 ** 18) * entry_fee
    uni_fixed_game.addCondition(condition, {"from": account})
    uni_fixed_game.enter(condition, 1, {"from": account, "value": fee_wei})
    in_game = uni_fixed_game.playerInGame(account, {"from": account})
    print("successfuly deployed")
    assert in_game == True


def test_all_types():
    account = get_account()
    multi_free_game = deploy_betting_game(4000, BET_TYPES[1], GAME_TYPES[1])
    high_score_game = deploy_betting_game(4000, BET_TYPES[0], GAME_TYPES[2])
    uni_fixed_game = deploy_betting_game(4000, BET_TYPES[0], GAME_TYPES[0])
    uni_entry_fee = uni_fixed_game.getEntranceFee()
    multi_entry_fee = multi_free_game.getEntranceFee()
    high_score_fee = high_score_game.getEntranceFee()
    print(uni_entry_fee)

    condition = "Condition 1"
    uni_fixed_game.addCondition(condition, {"from": account})
    # Contract[-1] gets the latest deployed version of a contract
    rate = MockV3Aggregator[-1].latestRoundData()[1]
    uni_fee_wei = 10 ** 18 / (rate / 10 ** 18) * uni_entry_fee
    multi_fee_wei = 10 ** 18 / (rate / 10 ** 18) * multi_entry_fee
    high_fee_wei = 10 ** 18 / (rate / 10 ** 18) * high_score_fee
    uni_fixed_game.enter(condition, 1, {"from": account, "value": uni_fee_wei})
    for i in range(1, 4):
        multi_free_game.addCondition(condition + str(i), {"from": account})
        multi_free_game.enter(
            condition + str(i),
            1 + (i / 4),
            {"from": account, "value": multi_fee_wei},
        )
    high_score_game.enter({"from": account, "value": high_fee_wei})
    assert uni_fixed_game.playerInGame(account, {"from": account})
    assert high_score_game.playerInGame(account, {"from": account})
    assert multi_free_game.playerInGame(account, {"from": account})


# def test_change_state():
