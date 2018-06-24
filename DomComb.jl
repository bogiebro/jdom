module DomComb
export inform, repeat, repeat_to, choose, fzf, inhand

inform(str) = (println(str); readuntil(STDIN,"\n"))

function repeat(f, a)
  for c in countfrom(0)
    f(a) || return c
  end
end

function repeat_to(f, a)
  for c in take(countfrom(0), n)
    f(a) || return c
  end
end

inhand(h) = view(h.cards, 1:h.drawn)

# Let the user pick a card from h; Call f(h,idx)
function choose(f, h)
  inform("Pick a card")
  elt = fzf(inhand(h), x->x.name)
  elt == 0 && return false
  f(h, elt); true
end

# Let the user pick an option described by f from xs
function fzf(xs, f)
  so,si,pr = readandwrite(`fzf`)
  foreach(x->println(si, x), map(f, xs))
  picked = strip(readline(so))
  findfirst(x->f(x) == picked, xs)
end

end

# build_market should do so randomly
# note- a blockus game could also be fun
# should make the lines have an index, then
# parse to the first whitespace, interpret it as an index.
# separate the UI parts from other parts


