# Why we don't need `.save()`

Forward ranges are ranges where iteration consumes the state of the range.
While with most ranges, state can be saved just by copying the range value,
forward ranges implement the `.save()` primitive, which allows taking a
checkpoint of the range position. This may be expensive, such as requiring
`dup` calls.

Our JSON ranges would ordinarily have to implement a costly `save` because
they keep iterator state in an array, which would have to be duplicated.
However, we can skip this: the only place where we revert parse state is in
recursive object parsing, in which case we can be certain that the state we
revert to is on the same JSON level as the state that we end up at.
As such, the only range that needs to be reverted is the range that is
topmost when we revert to the saved state. We implement this implicitly by
breaking the "current top range" out into a separate member variable.

So every range stack member above the current position is trash that is only
kept to avoid reallocating and will be reinitialized on reiteration, and every
range stack member below the current position is unaffected by the iteration.
