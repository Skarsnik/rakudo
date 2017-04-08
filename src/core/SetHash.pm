my class SetHash does Setty {

    role SetHashMappy does Rakudo::Iterator::Mappy {
        method ISINSET(\key) {
            Proxy.new(
              FETCH => {
                  nqp::p6bool(
                    nqp::existskey(
                      nqp::getattr(self,::?CLASS,'$!storage'),
                      key
                    )
                  )
              },
              STORE => -> $, \value {
                  nqp::stmts(
                    nqp::unless(
                      value,
                      nqp::deletekey(
                        nqp::getattr(self,::?CLASS,'$!storage'),
                        key
                      )
                    ),
                    value
                  )
              }
            )
        }
    }

    method iterator(SetHash:D:) {
        class :: does SetHashMappy {
            method pull-one() {
              nqp::if(
                $!iter,
                Pair.new(
                  nqp::iterval(nqp::shift($!iter)),
                  self.ISINSET(nqp::iterkey_s($!iter))
                ),
                IterationEnd
              )
            }
        }.new(%!elems)
    }

    multi method kv(SetHash:D:) {
        Seq.new(class :: does SetHashMappy {
            has int $!on-value;
            method pull-one() {
              nqp::if(
                $!on-value,
                nqp::stmts(
                  ($!on-value = 0),
                  self.ISINSET(nqp::iterkey_s($!iter))
                ),
                nqp::if(
                  $!iter,
                  nqp::stmts(
                    ($!on-value = 1),
                    nqp::iterval(nqp::shift($!iter))
                  ),
                  IterationEnd
                )
              )
            }
            method skip-one() {
                nqp::if(
                  $!on-value,
                  nqp::not_i($!on-value = 0),   # skipped a value
                  nqp::if(
                    $!iter,                     # if false, we didn't skip
                    nqp::stmts(                 # skipped a key
                      nqp::shift($!iter),
                      ($!on-value = 1)
                    )
                  )
                )
            }
            method count-only() {
                nqp::p6box_i(
                  nqp::add_i(nqp::elems($!storage),nqp::elems($!storage))
                )
            }
        }.new(%!elems))
    }
    multi method values(SetHash:D:) {
        Seq.new(class :: does SetHashMappy {
            method pull-one() {
              nqp::if(
                $!iter,
                self.ISINSET(nqp::iterkey_s(nqp::shift($!iter))),
                IterationEnd
              )
            }
        }.new(%!elems))
    }

    method clone() {
        nqp::if(
          (my $raw := nqp::getattr(%!elems,Map,'$!storage'))
            && nqp::elems($raw),
          nqp::p6bindattrinvres(                  # something to clone
            nqp::create(self),
            ::?CLASS,
            '%!elems',
            nqp::p6bindattrinvres(
              nqp::create(Hash),
              Map,
              '$!storage',
              nqp::clone($raw)
            )
          ),
          nqp::create(self)                       # nothing to clone
        )
    }

    method Set(SetHash:D: :$view) is nodal {
        nqp::if(
          nqp::getattr(%!elems,Map,'$!storage'),
          nqp::p6bindattrinvres(
            nqp::create(Set),Set,'%!elems',
            nqp::if($view,%!elems,%!elems.clone)
          ),
          nqp::create(Set)
        )
    }
    method SetHash(SetHash:D:) is nodal { self }

    multi method AT-KEY(SetHash:D: \k --> Bool:D) is raw {
        Proxy.new(
          FETCH => {
              %!elems.EXISTS-KEY(k.WHICH);
          },
          STORE => -> $, $value {
              nqp::stmts(
                nqp::if(
                  $value,
                  nqp::bindkey(
                    nqp::unless(
                      nqp::getattr(%!elems,Map,'$!storage'),
                      nqp::bindattr(%!elems,Map,'$!storage',
                        nqp::create(Rakudo::Internals::IterationSet))
                    ),
                    k.WHICH,
                    k
                  ),
                  nqp::if(
                    (my $elems := nqp::getattr(%!elems,Map,'$!storage')),
                    nqp::deletekey($elems,k.WHICH)
                  )
                ),
                $value.Bool
              )
          }
        )
    }
    multi method DELETE-KEY(SetHash:D: \k --> Bool:D) {
        nqp::if(
          %!elems.EXISTS-KEY(my $key := k.WHICH),
          nqp::stmts(
            %!elems.DELETE-KEY($key),
            True
          )
        )
    }
}

# vim: ft=perl6 expandtab sw=4
