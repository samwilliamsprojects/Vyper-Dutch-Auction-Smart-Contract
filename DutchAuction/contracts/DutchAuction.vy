# @version 0.3.1


struct Buyer :
    holder: address
    tokens: uint256
    pricePaid: uint256


# defines the variables of any Company
company: public(address)
totalTokens: public(uint256)
startingPrice: public(uint256)
price: public(uint256)
reservePrice: public(uint256)

# to determmine how much time has passed, must use Unix epoch time
auctionStart: public(uint256)

# how long the auction will go
auctionTime: public(uint256)
ended: public(bool)

# function variables
_start_price: uint256
_reserve_price: uint256
_total_tokens: uint256

# hashmap of holdings and price holder paid
buyerHash: HashMap[int128, Buyer]

# for hashmap and the ending for loop of refunds, must keep track of buyers and how many there were
# this creates an integer in the hashmap that starts at zero and will add 1 for each buyer:
nextBuyerIndex: int128
buyerIndex: int128

# defining company as the company to sell tokens, the length of the auction and when it starts, 
# the token supply, and the starting/ending price of the token 
@external
def __init__(_company: address, _total_tokens: uint256, _starting_price: uint256, _auction_start: uint256, _auction_time: uint256, _reserve_price: uint256):

    self.company = _company
    self.totalTokens = _total_tokens
    self.startingPrice = _starting_price
    self.auctionTime = _auction_time
    self.reservePrice = _reserve_price

    # auction start should be an integer in epoch time to be compared to block.timestamp
    self.auctionStart = _auction_start

    # This defaults to zero
    nbi: int128 = self.nextBuyerIndex

    # company starts with all tokens, is buyer[0] in the hashmap
    self.buyerHash[nbi] = Buyer({holder:_company, tokens:_total_tokens, pricePaid:_starting_price})
    self.nextBuyerIndex = nbi + 1
    assert block.timestamp >= _auction_start



# determine how many tokens company has
@view
@internal
def _tokensAvailable() -> uint256:
    return self.buyerHash[0].tokens

    
# public function so they can see how many tokens are left
@view
@external
def tokensAvailable() -> uint256:
    return self._tokensAvailable()


# price is dynamic, so must calculate it with each transaction
@view
@internal
def current_price() -> uint256:
    #calculates how much time has passed to be used in linear regression of price
    elapsedTime: uint256 = block.timestamp - self.auctionStart

    # determine price as a linear function of time
    # y = mx + b, m is decreasing with time, b is reserve price
    # at beginning, m = 1, price = startingPrice
    # at end of auction, m = 0, price = reservePrice

    # need division to use this formula, and while Vyper allows decimals, it seems Brownie/Solidity do not

    # need a decimal work around:
    # scale up the numerator by an enormous factor to avoid the decimal/rounding conflict while 
    # allows rounding to be a negligible issue
    # scale it back down by same amount after division calculation is done;
    # we have now avoided decimals and allowed division by multiplying by 1
    
    token_price: uint256 = ((((self.auctionTime - elapsedTime)*1000000)/self.auctionTime) * (self.startingPrice - self.reservePrice)/1000000) + self.reservePrice

    return token_price


# public function that can be called to get the current price
@view
@external
def currentPrice() -> uint256:
    return self.current_price()


# this function is used for the brownie tests to test refunds. It artificially doubles
# the price that account[2] paid for tokens, increasing their refund, ensuring refunds
# work properly
# @payable
# @external
# def call_to_test_refund():
#     self.buyerHash[2].holder = msg.sender
#     priceToken:uint256 = self.current_price()
#     buyings:uint256 = msg.value / priceToken
#     self.buyerHash[2].tokens = buyings
#     self.buyerHash[2].pricePaid = priceToken * 2


# allows purchase of tokens; company gets money, buyer gets tokens
@external
@payable
def buyToken():

    # check that auction isn't over
    assert self.current_price() >= self.reservePrice
    assert self.buyerHash[0].tokens > 0
    assert (block.timestamp - self.auctionStart) < self.auctionTime

    # nbi not a storage variable, must redeclare it and add 1 so it doesnt start at 0
    nbi: int128 = self.nextBuyerIndex + 1
    self.buyerHash[nbi].holder = msg.sender

    # price of tokens at time of buy
    currentTokenCost: uint256 = self.current_price()

    # determines how many tokens their value is worth
    _tokensBought: uint256 = (msg.value / currentTokenCost)

    # proceeds if they did not order more tokens than available
    if self._tokensAvailable() > _tokensBought:

        # remove tokens from company storage, give them to buyer, log the price paid
        self.buyerHash[0].tokens -= _tokensBought
        self.buyerHash[nbi].tokens += _tokensBought
        self.buyerHash[nbi].pricePaid = currentTokenCost

        # increases next buyer index buy one for next buyer
        self.nextBuyerIndex = nbi + 1
       


    else:
        # requires tokens bought to be more than or all of the supply
        assert _tokensBought >= self.buyerHash[0].tokens

        # calculates how many excess tokens were bought
        excessTokensBought: uint256 = _tokensBought - self.buyerHash[0].tokens
        
        # finds how many tokens are left to buy
        finalTokensBought: uint256 = self.buyerHash[0].tokens

        
 
        # company storage is now 0, give all tokens to buyer
        self.buyerHash[0].tokens = 0
        self.buyerHash[nbi].tokens += finalTokensBought

        self.buyerHash[nbi].pricePaid = currentTokenCost

        # how many tokens need to be refunded
        unusedValue: uint256 = excessTokensBought * currentTokenCost

        # refund them the money
        send(self.buyerHash[nbi].holder, unusedValue)

        # dont need to account for this buyer in the next buyer index because they 
        # bought at the lowest price, and excess money used has been sent back



# Must refund all buyers except the final one
@payable
@external
def refund():
    if self.buyerHash[0].tokens == 0 or self.current_price() <= self.reservePrice or (block.timestamp - self.auctionStart) > self.auctionTime:
    
        # determine real price to determine necessary refund
        realPrice: uint256 = self.current_price()

        # ind is used solely to keep track of buyers for the for loop
        ind: int128 = self.buyerIndex

        # for loop is constructed this way to save on gas
        for i in range(ind, ind + 30):

            # i must account for company, the 0th account that doesn't get a refund, so 1 is added to each i to make the loop start at 1
            index:int128 = i + 1

            if i >= self.nextBuyerIndex:
                self.buyerIndex = self.nextBuyerIndex
                return

            # calculates difference of price buyer paid vs price they will be charged
            difference: uint256 = (self.buyerHash[index].tokens * self.buyerHash[index].pricePaid) - (self.buyerHash[index].tokens * realPrice)
            
            # sends the refund to the buyer
            send(self.buyerHash[index].holder, difference)

            # replaces the hashmap with the price they have now paid
            self.buyerHash[index] = empty(Buyer)
        
        self.buyerIndex = ind + 30