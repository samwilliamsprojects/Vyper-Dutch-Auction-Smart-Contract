import pytest
from brownie import accounts, DutchAuction

TOTAL_TOKENS = 6e17
STARTING_PRICE = 100
RESERVE_PRICE = 1
START_TIME = 1643562611
AUCTION_TIME = 100000

@pytest.fixture
def dutch_auction():
    return DutchAuction.deploy(accounts[0], TOTAL_TOKENS, STARTING_PRICE, START_TIME, AUCTION_TIME, RESERVE_PRICE, {'from': accounts[0]})


# ensures the price is between starting and reserve price
# def test_dynamic_price(dutch_auction):
#     price = dutch_auction.currentPrice()
#     firstPrice = dutch_auction.startingPrice()
#     finalPrice = dutch_auction.reservePrice()
#     assert firstPrice > price 
#     assert finalPrice < price


# tries to buy tokens after all are bought
# def test_buy_after_tokens_gone(dutch_auction):
#     buy_all = dutch_auction.buyToken({'from': accounts[1], 'value':'35 ether'})
#     account2holdings = accounts[2].balance()
#     assert dutch_auction.tokensAvailable() == 0
#     buy_after_tokens_gone = dutch_auction.buyToken({'from':accounts[2], 'value':'1 ether'})
#     # error message should occur here


# tests the buy function without buying all the tokens
# def test_buy_few_tokens(dutch_auction):
#     pre_contract_balance = accounts[2].balance()
#     dutch_auction.buyToken({'from':accounts[2], 'value':'1 ether'})
#     post_contract_balance = accounts[2].balance()
#     assert pre_contract_balance > post_contract_balance


# tests the buy function by buying excess tokens, ensures it refunded proper amount
# must use "value" that is large than token supply*price here for it to work
# def test_buy_all_tokens(dutch_auction):
#     pre_contract_balance = accounts[3].balance()
#     dutch_auction.buyToken({'from':accounts[3], 'value':'10 ether'})
#     post_contract_balance = accounts[3].balance()

#     error message shows how much wei was refunded if you un-comment out next line
#     assert pre_contract_balance == post_contract_balance
#     assert pre_contract_balance > post_contract_balance


# tests to see that company starts with all tokens
# def test_correct_token_assignment(dutch_auction):
#     startingTokens = TOTAL_TOKENS
#     startingCompanyTokens = dutch_auction.tokensAvailable()
#     assert startingTokens == startingCompanyTokens


# makes sure company loses tokens when tokens are purchased
# def test_company_holdings_decrease(dutch_auction):
#     pre_contract_balance = dutch_auction.tokensAvailable()
#     purchase_by_6 = dutch_auction.buyToken({'from':accounts[6], 'value':'1 ether'})
#     post_contract_balance = dutch_auction.tokensAvailable()
#     assert pre_contract_balance >= post_contract_balance


# testing refunds and account balances when the final token is bought, before refunds are issued
# def test_balances_after_final_purchase(dutch_auction):
#     purchase_by_5 = dutch_auction.buyToken({'from':accounts[5], 'value':'10 ether'})
#     purchase_by_9 = dutch_auction.buyToken({'from':accounts[9], 'value':'10 ether'})
#     purchase_by_3 = dutch_auction.buyToken({'from':accounts[3], 'value':'25 ether'})
#     purchase_by_4 = dutch_auction.buyToken({'from':accounts[4], 'value':'25 ether'})
#     assert dutch_auction.tokensAvailable() == 0
#     assert accounts[5].balance() == accounts[9].balance()
#     assert accounts[5].balance() > accounts[3].balance()
#     assert accounts[4].balance() > accounts[3].balance()


# testing refunds. uses a fake function in DutchAuction called "call_to_test_refund" that 
# artificially doubles the price account[2] paid for its tokens. uncomment it out to use it
def test_refund(dutch_auction):
    purchase_by_1 = dutch_auction.buyToken({'from':accounts[1], 'value':'35 ether'})
    purchase_by_2 = dutch_auction.call_to_test_refund({'from':accounts[2], 'value':'35 ether'})
    purchase_to_end_auction = dutch_auction.buyToken({'from':accounts[5], 'value':'30 ether'})
    assert dutch_auction.tokensAvailable() == 0
    dutch_auction.refund()
    assert accounts[2].balance() > accounts[1].balance()



