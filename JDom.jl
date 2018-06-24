module JDom
importall DomComb

immutable Money amt::Int end
immutable Victory points::Int end
immutable Action act::Function end
# act : State-> (Actions,Money,Buys)

immutable Card
  name::String
  ty::Union{Action,Victory,Money}
  cost::Int
end

type Hand
  cards::Array{Card}
  drawn::Int
  last::Int
end

type Market
  cards::Array{Card}
  remaining::ObjectIdDict  
end

immutable State
  hands::Array{Hand}
  market::Market
  me::Hand
end

const ESTATE = Card("estate", Victory(1), 2)
const DUCHY = Card("duchy", Victory(3), 5)
const PROVINCE = Card("province", Victory(6), 8)
const CURSE = Card("curse", Victory(-1), 0)

const COPPER = Card("copper", Money(1), 0)
const SILVER = Card("silver", Money(2), 3)
const GOLD = Card("gold", Money(2), 6)

const WOODCUT = Card("woodcutter", Action(_->(0,2,1)), 3)
const FESTIVAL = Card("festival", Action(_->(2,2,1)), 5)
const VILLAGE = Card("village", Action(s->(draw(s.me); (2,0,0))), 3)
const COUNCIL = Card("council room", Action(s->(draw(s.me,4); (0,0,1))), 5)
const LAB = Card("laboratory", Action(s->(draw(s.me,2); (1,0,0))), 5)
const MARKET = Card("market", Action(s->(draw(s.me); (1,1,1))), 5)
const SMITHY = Card("smithy", Action(s->(draw(s.me,3); (0,0,0))), 4)
const MOAT = Card("smithy", Action(s->(draw(s.me,2); (0,0,0))), 2)

cellar(s) = (draw(s.me, repeat(h->choose(discard, h), s.me)); (1,0,0))
const CELLAR = Card("cellar", Action(cellar), 2)

chapel(s) = (repeat_to(h->choose(trash,h), s.me, 4); (0,0,0))
const CHAPEL = Card("chapel", Action(chapel), 2)

moneylender(s)= findcard(s.me, COPPER, trash) ? (0,3,0) : (0,0,0)
const MONEYLENDER = Card("moneylender",Action(moneylender), 4)

feast(s) = (trash(s.me, findfirst(FEAST, s.me)); buy(s, 5); (0,0,0))
const FEAST = Card("feast",Action(feast), 4)

chancellor(s) = (s.me.cards.last = s.me.drawn; (0,2,0))
const CHANCELLOR = Card("chancellor",Action(chancellor), 3)

witch(s) = (draw(s.me, 2); others(h->addhand(h, s.market, CURSE), s); (0,0,0))
const WITCH = Card("witch", Action(witch), 5)

function militia(s)
  for (i,h) in enumerate(s.hands)
    h == s.me && continue
    inform("Player $(i) should discard down to 3 cards")
    while h.drawn > 3
      choose(discard, h)
    end
  end
  (0,2,0)
end
const MILITIA = Card("militia", Action(militia), 4)

function mine(s)
  choose(s.me) do h,elt
    c = h.cards[elt]
    isa(c.ty, Money) && buy(s, c.cost + 3)
  end
  (0,0,0)
end
const MINE = Card("mine", Action(mine), 5)

function library(s)
  while (s.me.drawn < 7)
    draw(s.me)
    c = s.me.cards[s.me.drawn]
    in('y', inform("You drew a $(c.name). Discard?")) && discard(s.me, s.me.drawn)
  end
  (0,0,0)
end
const LIBRARY = Card("library", Action(library), 5)

# should be some general combinator to choose items of a certain type
# mine, throne, etc need this
function throne(s)
end
const THRONE = Card("throne room", Action(throne), 4)

# If card c is in hand h, call f(h, c_idx)
function findcard(h, c, f)::Bool
  elt = findfirst(c, view(h.cards, 1:h.drawn))
  elt == 0 && return false
  f(h, elt); true
end

# Trash the current player's card at elt
function trash(h, elt)
  h.cards[elt] = h.cards[h.drawn]
  h.cards[h.drawn] = h.cards[h.last]
  h.cards[h.last] = h.cards[end]
  pop!(h.cards)
end

# Discard the current player's card at elt
function discard(h, elt)
  c = h.cards[elt]
  h.cards[elt] = h.cards[h.drawn]
  h.cards[h.drawn] = h.cards[h.last]
  h.cards[h.last] = c
  h.drawn -= 1
  h.last -= 1
end

value(x) = isa(x.ty, Money) ? x.ty.amt : 0

# Play the current players card at elt
function play(s::State, elt::Int)::(Int,Int,Int)
  a = s.me.cards[elt].ty
  if !isa(a, Action) 
    inform("Not an action")
    return
  end
  discard(s.me, elt)
  a.act(s)
end

# Draw n cards for the current player
function draw(h::Hand, n=1)
  for _=1:n
    h.drawn += 1
    if h.drawn > h.last
      l = length(h.cards)
      shuffle!(view(h.cards, h.drawn:l))
      h.last = l
    end
  end
end

function others(f::Function, s::State)
  # f : Hand -> ()
  for h in s.hands
    h == s.me || f(h)
  end
end

# Add a card to a player's hand if it's available
function addhand(h::Hand, m::Market, c::Card)::Bool
  if get(m.remaining, c, 0) > 0
    m.remaining[c] -= 1
    push!(h.cards, c)
    return true
  end
  false
end

# Allow the current player to pick items to buy
function buy(s::State, budget::Int)
  elt = fzf(s.market.cards, x->"$(x.name) ($(x.cost))")
  elt == 0 && return tospend, 0
  c = s.market.cards[elt]
  c.cost <= budget && addhand(s.me, s.market, c) && return budget - c.cost, 1
  println("You cannot buy a $(c.name)")
  return tospend, 0
end

# Play out the current player's turn
function turn(s::State)
  hand = inhand(s.me)
  actions = 1
  inform("Play an action")
  money = 0; buys = 1
  while actions > 0
    elt = fzf(inhand(s.me), x->x.name)
    elt == 0 && break
    dactions, dmoney, dbuys = play(s, elt)
    actions += dactions - 1
    money += dmoney; buys += dbuys
  end
  tospend = sum(value(x) for x in inhand(s.me))
  while buys > 0
    inform("You have $tospend units to spend remaining")
    tospend, bought = buy(s, tospend)
    buys -= bought
  end
  for i=1:s.me.drawn
    discard(s.me, i)
  end
  draw(s.me, 5)
end

# Shuffle 7 coopers and 3 estates
function deal_hand()
  hand = [COPPER for i=1:7]
  append!(hand, [ESTATE for i=1:3])
  shuffle!(hand)
  Hand(hand, 5, length(hand))
end

# Choose a random set of cards for the market
function build_market(p)
  d = ObjectIdDict(
    ESTATE=>24-p,
    COPPER=>60-p,
    SILVER=>40,
    GOLD=>30,
    VILLAGE=>10,
    CHAPEL=>10,
    CELLAR=>10)
  Market(collect(keys(d)), d)
end

# Play a game with p players
function game(p)
  s = [deal_hand() for i=1:p]
  m = build_market(p)
  while true
    for i=1:p
      println("Player $i's turn")
      turn(State(s, m, s[i]))
    end
  end
end

end
